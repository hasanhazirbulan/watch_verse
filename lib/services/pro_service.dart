import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kDebugMode;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pro_entitlement.dart';
import 'package:watch_verse/services/app_firebase.dart';

export 'pro_entitlement.dart'
    show
        ProTier,
        proMonthlyProductId,
        proYearlyProductId,
        patronMonthlyProductId,
        patronYearlyProductId;

const _proTierPrefsKey = 'watchverse_pro_tier';
// Legacy single-bool key from before the Pro/Patron split — read once as a
// fallback for installs that already granted Pro under the old scheme.
const _legacyProActivePrefsKey = 'watchverse_pro_active';
// Set when Patron was lost while nobody was signed in, so the public
// `patron: true` badge on users/{uid} still needs clearing at next sign-in.
const _patronBadgeClearPendingKey = 'watchverse_patron_badge_clear_pending';

/// WatchVerse's two-tier subscription: **Pro** (unlimited lists, advanced
/// stats, the daily game — the functional tier) and **Patron** (everything
/// in Pro, plus profile themes, a Patron badge, and early access — the
/// status/cosmetic tier), mirroring Letterboxd's Pro/Patron ladder. Both
/// tiers live in one App Store Connect subscription group so StoreKit
/// handles upgrade/downgrade proration natively.
///
/// Backed directly by StoreKit via the official `in_app_purchase` plugin —
/// no third-party service, no API key, no backend of ours. Apple is the
/// only party in the loop.
///
/// Mirrors the app's existing pattern of exposing live state as a broadcast
/// [Stream] (see `SocialService.myStream()`, auth state in `main.dart`) so
/// any screen gates itself with a plain
/// `StreamBuilder<bool>(stream: ProService.instance.isProStream)` — no new
/// state-management dependency.
///
/// **Lapses are revoked via StoreKit 2.** At launch (and whenever StoreKit
/// pushes an expired/refunded transaction update) the tier is re-derived
/// from `Transaction.all` — see [resolveProTier] — so an expired, refunded,
/// or downgraded subscription drops back to Pro / none. If StoreKit can't
/// answer (fetch error, empty history, App Store unreachable) the cached
/// tier is kept: a paying subscriber is never locked out on bad data.
class ProService {
  ProService._();
  static final ProService instance = ProService._();

  /// Always true — StoreKit needs no API key, just product IDs configured in
  /// App Store Connect. Kept as a named check (mirrors the
  /// `GiphyService.isConfigured` / old RevenueCat-key pattern other gates
  /// were written against) so call sites don't need to change if that ever
  /// isn't the case on some platform.
  static const bool isConfigured = true;

  final _controller = StreamController<ProTier>.broadcast();
  ProTier _tier = ProTier.none;
  bool _initialized = false;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  StreamSubscription<User?>? _authSub;
  List<ProductDetails> _products = const [];
  // Whether the last product query reached the App Store — the signal that
  // StoreKit's transaction history is fresh enough to *downgrade* on.
  bool _storeReachable = false;
  bool _patronBadgeClearPending = false;
  // Serializes entitlement checks so two overlapping ones can't interleave.
  Future<void>? _syncInFlight;
  // Bumped whenever a purchase/restore event raises the tier, so an
  // entitlement check whose history snapshot predates that grant doesn't
  // undo it.
  int _grantEpoch = 0;

  static bool get _isStoreKit =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Live tier. Emits immediately with the last known value to new
  /// listeners (via a seeded broadcast), then again whenever it changes.
  Stream<ProTier> get tierStream async* {
    yield _tier;
    yield* _controller.stream;
  }

  /// Pro *or* Patron — the functional perks (lists, stats, the daily game)
  /// are included at both tiers.
  Stream<bool> get isProStream => tierStream.map((t) => t != ProTier.none);

  /// Patron only — the status/cosmetic perks (profile themes, badge, early
  /// access).
  Stream<bool> get isPatronStream => tierStream.map((t) => t == ProTier.patron);

  ProTier get tier => _tier;
  bool get isPro => _tier != ProTier.none;
  bool get isPatron => _tier == ProTier.patron;

  /// Call once at app start (from `main()`), after `Firebase.initializeApp`
  /// (the Patron badge is written to Firestore).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    // Seed from the last known state so the UI doesn't flash "locked" for
    // a subscriber before the StoreKit restore below finishes.
    final storedTier = prefs.getInt(_proTierPrefsKey);
    if (storedTier != null) {
      _tier = ProTier.values[storedTier.clamp(0, ProTier.values.length - 1)];
    } else if (prefs.getBool(_legacyProActivePrefsKey) == true) {
      _tier = ProTier.pro;
    }
    _patronBadgeClearPending =
        prefs.getBool(_patronBadgeClearPendingKey) ?? false;

    // Publish the Patron badge for whoever signs in on a Patron device (the
    // purchase may have happened before sign-in, or on a previous account
    // session).
    _authSub = AppFirebase.auth.authStateChanges().listen((user) {
      if (user == null) return;
      if (isPatron) {
        _publishPatronBadge(user.uid);
      } else if (_patronBadgeClearPending) {
        _clearPatronBadge(user.uid);
      }
    });

    // StoreKit 2 is the plugin's default since in_app_purchase_storekit
    // 0.4.x (`enableStoreKit2()` is now deprecated as a no-op opt-in), so
    // purchases/restores already go through SK2: restore replays only
    // `Transaction.currentEntitlements` (active subscriptions), not expired
    // ones. The lapse check below uses SK2's `Transaction.all` directly.
    if (kDebugMode && _isStoreKit) {
      debugPrint(
        'ProService: StoreKit2='
        '${InAppPurchaseStoreKitPlatform.isStoreKit2Enabled}',
      );
    }

    final available = await InAppPurchase.instance.isAvailable();
    if (kDebugMode) debugPrint('ProService: isAvailable=$available');
    if (!available) return;

    _sub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (_) {},
    );

    await _loadProducts();
    await _syncEntitlements();
    await _restoreQuietly();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await InAppPurchase.instance.queryProductDetails(
        proProductIds,
      );
      _products = response.productDetails;
      _storeReachable = response.error == null && _products.isNotEmpty;
      if (kDebugMode) {
        debugPrint(
          'ProService: loaded ${_products.length} product(s), '
          'notFoundIDs=${response.notFoundIDs}, error=${response.error}',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ProService: queryProductDetails threw: $e');
      _storeReachable = false;
      // Offline, etc. — the paywall just shows nothing to buy this time.
    }
  }

  /// Re-derives the tier from StoreKit 2's transaction history
  /// (`Transaction.all`), which — unlike the restore flow — can *lower* it:
  /// an expired, refunded, or upgraded-away subscription stops counting.
  /// See [resolveProTier] for when the cached tier is kept instead. Any
  /// failure leaves the tier untouched.
  Future<void> _syncEntitlements() {
    if (!_isStoreKit) return Future.value();
    return _syncInFlight ??= _doSyncEntitlements().whenComplete(
      () => _syncInFlight = null,
    );
  }

  Future<void> _doSyncEntitlements() async {
    try {
      final epoch = _grantEpoch;
      final transactions = await SK2Transaction.transactions();
      if (epoch != _grantEpoch) return; // a fresh grant raced this snapshot
      final next = resolveProTier(
        cached: _tier,
        transactions: transactions.map(
          (t) => ProEntitlementTransaction.fromStoreKit(
            productId: t.productId,
            expirationDateMs: t.expirationDate,
            jsonRepresentation: t.jsonRepresentation,
          ),
        ),
        now: DateTime.now(),
        storeReachable: _storeReachable,
      );
      if (kDebugMode) {
        debugPrint(
          'ProService: entitlement check over '
          '${transactions.length} transaction(s): $_tier -> $next '
          '(storeReachable=$_storeReachable)',
        );
      }
      await _applyTier(next);
    } catch (e) {
      // Keep the cached tier — never downgrade on an error.
      if (kDebugMode) debugPrint('ProService: entitlement check failed: $e');
    }
  }

  /// Re-syncs entitlement from the App Store without surfacing UI (no
  /// snackbars/errors) — used at launch, distinct from the user-initiated
  /// [restore] the paywall's "Restore purchases" button calls.
  Future<void> _restoreQuietly() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {
      // Keep whatever the seeded/last-known value was.
    }
  }

  /// Grants a tier the moment StoreKit reports a successful purchase or a
  /// restored one. Only ever *raises* the tier: lowering it is
  /// [_syncEntitlements]'s job, which looks at the whole transaction history
  /// rather than one batch. Under StoreKit 2, `Transaction.updates` also
  /// delivers refunds/revocations and expired renewals with status
  /// `purchased`, so each event is checked against its own expiration /
  /// revocation first — an inactive one never grants, and instead triggers
  /// a full re-check (which may downgrade).
  ///
  /// If a batch contains both tiers, the higher active tier wins.
  ///
  /// The tier is granted *before* `completePurchase` is called, and a
  /// failing `completePurchase` is contained: this is an `async` stream
  /// callback, so a throw there used to skip the grant for a purchase Apple
  /// had already charged (until the next launch's restore) and surface as an
  /// uncaught error.
  void _onPurchaseUpdates(List<PurchaseDetails> updates) async {
    var highest = ProTier.none;
    var sawInactive = false;
    final now = DateTime.now();
    for (final purchase in updates) {
      final entitlement = _entitlementOf(purchase);
      final tier = entitlement.tier;
      if (tier == ProTier.none ||
          (purchase.status != PurchaseStatus.purchased &&
              purchase.status != PurchaseStatus.restored)) {
        continue;
      }
      if (entitlement.isActiveAt(now)) {
        if (tier.index > highest.index) highest = tier;
      } else {
        sawInactive = true;
      }
    }
    if (highest != ProTier.none) await _setTier(highest);
    // A StoreKit update arriving means the App Store was just reachable.
    if (sawInactive) {
      _storeReachable = true;
      unawaited(_syncEntitlements());
    }

    for (final purchase in updates) {
      if (purchase.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(purchase);
        } catch (e) {
          // StoreKit redelivers unfinished transactions on the next launch,
          // so this is retried automatically.
          if (kDebugMode) debugPrint('ProService: completePurchase threw: $e');
        }
      }
    }
  }

  static ProEntitlementTransaction _entitlementOf(PurchaseDetails purchase) {
    if (purchase is SK2PurchaseDetails) {
      return ProEntitlementTransaction.fromStoreKit(
        productId: purchase.productID,
        expirationDateMs: purchase.expirationDate,
        jsonRepresentation: purchase.verificationData.localVerificationData,
      );
    }
    // StoreKit 1 / other platforms: no dates available — trust the status.
    return ProEntitlementTransaction(productId: purchase.productID);
  }

  /// Raises the tier (never lowers it) — for purchase/restore events.
  Future<void> _setTier(ProTier value) async {
    if (_tier.index >= value.index) return;
    _grantEpoch++;
    await _applyTier(value);
  }

  /// Sets the tier in either direction and persists it: prefs (the cached
  /// tier seeded at next launch) plus the public Patron badge on users/{uid}
  /// — set on gaining Patron, cleared on losing it.
  Future<void> _applyTier(ProTier value) async {
    if (_tier == value) return;
    final wasPatron = _tier == ProTier.patron;
    _tier = value;
    _controller.add(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_proTierPrefsKey, value.index);
    final uid = AppFirebase.auth.currentUser?.uid;
    if (value == ProTier.patron) {
      if (_patronBadgeClearPending) {
        _patronBadgeClearPending = false;
        await prefs.remove(_patronBadgeClearPendingKey);
      }
      if (uid != null) _publishPatronBadge(uid);
    } else if (wasPatron) {
      _patronBadgeClearPending = true;
      await prefs.setBool(_patronBadgeClearPendingKey, true);
      if (uid != null) await _clearPatronBadge(uid);
    }
  }

  /// Call once a new account's profile doc exists (registration). The auth
  /// listener's badge write for a fresh sign-up races `createUser` and, being
  /// an `update`, fails with not-found when it lands first — which left a
  /// Patron who registered on this device without a badge until the next
  /// launch.
  Future<void> onProfileCreated(String uid) async {
    if (isPatron) await _publishPatronBadge(uid);
  }

  /// Sets `patron: true` on the public profile doc so other users see the
  /// badge. `update` (not `set`) so a sign-in that races profile creation
  /// never leaves a half-built users doc; [onProfileCreated] retries once
  /// the doc exists, and every later launch's auth event does too.
  Future<void> _publishPatronBadge(String uid) async {
    try {
      await AppFirebase.firestore.collection('users').doc(uid).update({
        'patron': true,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('ProService: patron badge write failed: $e');
    }
  }

  /// Removes the public Patron badge after Patron lapsed. Retried at each
  /// sign-in until it succeeds (see the pending flag in [initialize]).
  Future<void> _clearPatronBadge(String uid) async {
    try {
      await AppFirebase.firestore.collection('users').doc(uid).update({
        'patron': false,
      });
      _patronBadgeClearPending = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_patronBadgeClearPendingKey);
    } catch (e) {
      if (kDebugMode) debugPrint('ProService: patron badge clear failed: $e');
    }
  }

  /// Available subscription products (Pro + Patron, Monthly + Yearly), for
  /// the paywall sheet to render and purchase from. Always re-queries
  /// StoreKit rather than serving `_products` from a prior call:
  /// `initialize()`'s own fetch happens once at app launch and — unlike the
  /// actual Apple purchase sheet, which always re-validates at transaction
  /// time — would otherwise keep showing whatever price was current at that
  /// moment for the rest of the app session, even after a price change in
  /// App Store Connect.
  Future<List<ProductDetails>> fetchPackages() async {
    await _loadProducts();
    return _products;
  }

  /// Restores purchases and reports whether a tier is active afterwards.
  ///
  /// `restorePurchases()` only *starts* the restore — the restored
  /// transactions arrive later on the purchase stream. This used to sleep
  /// 600 ms and then read [isPro], which reported "nothing to restore" to a
  /// real subscriber whenever StoreKit took longer than that. Now waits for
  /// the tier to flip (bounded, since StoreKit sends nothing at all when
  /// there is nothing to restore).
  ///
  /// (A `purchase()` method lived here too; the paywall now drives purchases
  /// from `purchaseStream` itself, so it was removed rather than fixed.)
  Future<bool> restore({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {
      return false;
    }
    // Re-check the full history too, so a stale cached tier from a lapsed
    // subscription isn't reported back as "restored".
    await _syncEntitlements();
    if (isPro) return true;
    try {
      await tierStream.firstWhere((t) => t != ProTier.none).timeout(timeout);
    } on TimeoutException {
      // Nothing restored in time.
    }
    return isPro;
  }

  void dispose() {
    _sub?.cancel();
    _authSub?.cancel();
  }
}
