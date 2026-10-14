import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Store Connect subscription product IDs (Subscription Group
/// "WatchVerse Pro", two tiers). Must match exactly what's entered in App
/// Store Connect → Monetization → Subscriptions.
const proMonthlyProductId = 'com.example.watchVerse.pro.monthly';
const proYearlyProductId = 'com.example.watchVerse.pro.yearly';
const patronMonthlyProductId = 'com.example.watchVerse.patron.monthly';
const patronYearlyProductId = 'com.example.watchVerse.patron.yearly';
const _proProductIds = {
  proMonthlyProductId,
  proYearlyProductId,
  patronMonthlyProductId,
  patronYearlyProductId,
};

const _proTierPrefsKey = 'watchverse_pro_tier';
// Legacy single-bool key from before the Pro/Patron split — read once as a
// fallback for installs that already granted Pro under the old scheme.
const _legacyProActivePrefsKey = 'watchverse_pro_active';

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
/// **Known limitation of a no-backend approach:** without server-side
/// receipt validation, an already-granted tier is never automatically
/// revoked client-side when a subscription lapses — see the long comment on
/// [_onPurchaseUpdates] for why iOS's restore flow can't safely be used to
/// infer that either. This is the standard tradeoff a small app accepts to
/// avoid a Cloud Function / server for receipt validation; it only means a
/// churned subscriber quietly keeps gated UI unlocked, not that anything is
/// charged twice or incorrectly.
enum ProTier { none, pro, patron }

ProTier _tierOf(String productId) {
  switch (productId) {
    case patronMonthlyProductId:
    case patronYearlyProductId:
      return ProTier.patron;
    case proMonthlyProductId:
    case proYearlyProductId:
      return ProTier.pro;
    default:
      return ProTier.none;
  }
}

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

    // Publish the Patron badge for whoever signs in on a Patron device (the
    // purchase may have happened before sign-in, or on a previous account
    // session).
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && isPatron) _publishPatronBadge(user.uid);
    });

    final available = await InAppPurchase.instance.isAvailable();
    if (kDebugMode) debugPrint('ProService: isAvailable=$available');
    if (!available) return;

    _sub = InAppPurchase.instance.purchaseStream.listen(_onPurchaseUpdates,
        onError: (_) {});

    await _loadProducts();
    await _restoreQuietly();
  }

  Future<void> _loadProducts() async {
    try {
      final response =
          await InAppPurchase.instance.queryProductDetails(_proProductIds);
      _products = response.productDetails;
      if (kDebugMode) {
        debugPrint('ProService: loaded ${_products.length} product(s), '
            'notFoundIDs=${response.notFoundIDs}, error=${response.error}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ProService: queryProductDetails threw: $e');
      // Offline, etc. — the paywall just shows nothing to buy this time.
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
  /// restored one. Deliberately one-directional: a batch with no purchased/
  /// restored event for our products just leaves [_tier] as-is rather than
  /// trying to infer a lapse from it — on iOS, [InAppPurchase.restorePurchases]
  /// redelivers a subscription's original transaction even after it's
  /// expired (that's a StoreKit1 restore semantics quirk, not a bug here),
  /// so treating "not in this restore batch" as "no longer entitled" would
  /// be actively wrong, not just imprecise. Reliable expiry detection needs
  /// server-side receipt validation (or StoreKit 2 entitlement APIs), which
  /// is out of scope for a no-backend setup — an already-granted tier
  /// simply isn't auto-revoked client-side. Accepted tradeoff for a small
  /// subscription.
  ///
  /// If a batch contains both tiers (e.g. restoring a historical Pro
  /// purchase alongside a current Patron one), the higher tier wins —
  /// Patron already includes everything Pro does, so this can only ever
  /// grant more, never less, than a single-product read would.
  ///
  /// The tier is granted *before* `completePurchase` is called, and a
  /// failing `completePurchase` is contained: this is an `async` stream
  /// callback, so a throw there used to skip the grant for a purchase Apple
  /// had already charged (until the next launch's restore) and surface as an
  /// uncaught error.
  void _onPurchaseUpdates(List<PurchaseDetails> updates) async {
    var highest = ProTier.none;
    for (final purchase in updates) {
      final tier = _tierOf(purchase.productID);
      if (tier != ProTier.none &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        if (tier.index > highest.index) highest = tier;
      }
    }
    if (highest != ProTier.none) await _setTier(highest);

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

  Future<void> _setTier(ProTier value) async {
    if (_tier.index >= value.index) return;
    _tier = value;
    _controller.add(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_proTierPrefsKey, value.index);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (value == ProTier.patron && uid != null) _publishPatronBadge(uid);
  }

  /// Sets `patron: true` on the public profile doc so other users see the
  /// badge. `update` (not `set`) so a sign-in that races profile creation
  /// never leaves a half-built users doc; the next sign-in retries.
  Future<void> _publishPatronBadge(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'patron': true});
    } catch (e) {
      if (kDebugMode) debugPrint('ProService: patron badge write failed: $e');
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
    if (isPro) return true;
    try {
      await tierStream
          .firstWhere((t) => t != ProTier.none)
          .timeout(timeout);
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
