import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Store Connect subscription product IDs (Subscription Group
/// "WatchVerse Pro"). Must match exactly what's entered in App Store Connect
/// → Monetization → Subscriptions.
const proMonthlyProductId = 'com.example.watchVerse.pro.monthly';
const proYearlyProductId = 'com.example.watchVerse.pro.yearly';
const _proProductIds = {proMonthlyProductId, proYearlyProductId};

const _proStatusPrefsKey = 'watchverse_pro_active';

/// WatchVerse Pro subscription status, backed directly by StoreKit via the
/// official `in_app_purchase` plugin — no third-party service, no API key,
/// no backend of ours. Apple is the only party in the loop.
///
/// Mirrors the app's existing pattern of exposing live state as a broadcast
/// [Stream] (see `SocialService.myStream()`, auth state in `main.dart`) so
/// any screen gates itself with a plain
/// `StreamBuilder<bool>(stream: ProService.instance.isProStream)` — no new
/// state-management dependency.
///
/// **Known limitation of a no-backend approach:** without server-side
/// receipt validation, an already-granted Pro flag is never automatically
/// revoked client-side when a subscription lapses — see the long comment on
/// [_onPurchaseUpdates] for why iOS's restore flow can't safely be used to
/// infer that either. This is the standard tradeoff a small app accepts to
/// avoid a Cloud Function / server for receipt validation; it only means a
/// churned subscriber quietly keeps Pro-gated UI unlocked, not that anything
/// is charged twice or incorrectly.
class ProService {
  ProService._();
  static final ProService instance = ProService._();

  /// Always true — StoreKit needs no API key, just product IDs configured in
  /// App Store Connect. Kept as a named check (mirrors the
  /// `GiphyService.isConfigured` / old RevenueCat-key pattern other gates
  /// were written against) so call sites don't need to change if that ever
  /// isn't the case on some platform.
  static const bool isConfigured = true;

  final _controller = StreamController<bool>.broadcast();
  bool _isPro = false;
  bool _initialized = false;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> _products = const [];

  /// Live Pro status. Emits immediately with the last known value to new
  /// listeners (via a seeded broadcast), then again whenever it changes.
  Stream<bool> get isProStream async* {
    yield _isPro;
    yield* _controller.stream;
  }

  bool get isPro => _isPro;

  /// Call once at app start (from `main()`), after `Firebase.initializeApp`
  /// — Firebase isn't actually used here, but this keeps init ordering
  /// obvious alongside the other services `main()` sets up.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    // Seed from the last known state so the UI doesn't flash "locked" for
    // a subscriber before the StoreKit restore below finishes.
    _isPro = prefs.getBool(_proStatusPrefsKey) ?? false;

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

  /// Grants Pro the moment StoreKit reports a successful purchase or a
  /// restored one for either product ID. Deliberately one-directional: a
  /// batch with no purchased/restored event for our products just leaves
  /// [_isPro] as-is rather than trying to infer a lapse from it — on iOS,
  /// [InAppPurchase.restorePurchases] redelivers a subscription's original
  /// transaction even after it's expired (that's a StoreKit1 restore
  /// semantics quirk, not a bug here), so treating "not in this restore
  /// batch" as "no longer entitled" would be actively wrong, not just
  /// imprecise. Reliable expiry detection needs server-side receipt
  /// validation (or StoreKit 2 entitlement APIs), which is out of scope for
  /// a no-backend setup — an already-granted Pro flag simply isn't
  /// auto-revoked client-side. Accepted tradeoff for a small subscription.
  void _onPurchaseUpdates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (_proProductIds.contains(purchase.productID) &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        await _setPro(true);
      }
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<void> _setPro(bool value) async {
    if (_isPro == value) return;
    _isPro = value;
    _controller.add(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proStatusPrefsKey, value);
  }

  /// Available subscription products (Monthly + Yearly), for the paywall
  /// sheet to render and purchase from. Always re-queries StoreKit rather
  /// than serving `_products` from a prior call: `initialize()`'s own fetch
  /// happens once at app launch and — unlike the actual Apple purchase
  /// sheet, which always re-validates at transaction time — would otherwise
  /// keep showing whatever price was current at that moment for the rest of
  /// the app session, even after a price change in App Store Connect.
  Future<List<ProductDetails>> fetchPackages() async {
    await _loadProducts();
    return _products;
  }

  Future<bool> purchase(ProductDetails product) async {
    try {
      final param = PurchaseParam(productDetails: product);
      final started =
          await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      if (!started) return false;
      // The actual entitlement flip happens asynchronously via
      // [_onPurchaseUpdates] once StoreKit reports the transaction — give it
      // a moment so the sheet can reflect the result before closing.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return _isPro;
    } catch (_) {
      return false;
    }
  }

  Future<bool> restore() async {
    try {
      await InAppPurchase.instance.restorePurchases();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return _isPro;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
