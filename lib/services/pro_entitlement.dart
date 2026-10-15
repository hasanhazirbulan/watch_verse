import 'dart:convert';

/// Pure (no plugin / Firebase imports) subscription-entitlement logic for
/// [ProService], kept separate so it's unit-testable without StoreKit.

/// App Store Connect subscription product IDs (Subscription Group
/// "WatchVerse Pro", two tiers). Must match exactly what's entered in App
/// Store Connect → Monetization → Subscriptions.
const proMonthlyProductId = 'com.example.watchVerse.pro.monthly';
const proYearlyProductId = 'com.example.watchVerse.pro.yearly';
const patronMonthlyProductId = 'com.example.watchVerse.patron.monthly';
const patronYearlyProductId = 'com.example.watchVerse.patron.yearly';
const proProductIds = {
  proMonthlyProductId,
  proYearlyProductId,
  patronMonthlyProductId,
  patronYearlyProductId,
};

/// WatchVerse's two-tier subscription: **Pro** (unlimited lists, advanced
/// stats, the daily game — the functional tier) and **Patron** (everything
/// in Pro, plus profile themes, a Patron badge, and early access — the
/// status/cosmetic tier).
enum ProTier { none, pro, patron }

ProTier tierOfProduct(String productId) {
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

/// The parts of a StoreKit 2 `Transaction` that decide entitlement.
class ProEntitlementTransaction {
  const ProEntitlementTransaction({
    required this.productId,
    this.expirationDate,
    this.revocationDate,
    this.isUpgraded = false,
  });

  /// Builds one from what the `in_app_purchase_storekit` SK2 wrappers expose:
  /// `expirationDate` as a milliseconds-since-epoch string, plus the
  /// transaction's `jsonRepresentation` (Apple's decoded JWS payload), which
  /// is the only place `revocationDate` / `isUpgraded` are surfaced. Missing
  /// or malformed fields are simply treated as absent.
  factory ProEntitlementTransaction.fromStoreKit({
    required String productId,
    String? expirationDateMs,
    String? jsonRepresentation,
  }) {
    DateTime? expiration = _parseMs(expirationDateMs);
    DateTime? revocation;
    var upgraded = false;
    if (jsonRepresentation != null && jsonRepresentation.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonRepresentation);
        if (decoded is Map) {
          revocation = _parseMs(decoded['revocationDate']);
          expiration ??= _parseMs(decoded['expiresDate']);
          upgraded = decoded['isUpgraded'] == true;
        }
      } catch (_) {
        // Not JSON — fall back to the explicit fields only.
      }
    }
    return ProEntitlementTransaction(
      productId: productId,
      expirationDate: expiration,
      revocationDate: revocation,
      isUpgraded: upgraded,
    );
  }

  final String productId;

  /// When this subscription period ends. Null means StoreKit didn't report
  /// one (not expected for our auto-renewing products); treated as not
  /// expired so missing data never revokes a paid tier.
  final DateTime? expirationDate;

  /// Set when Apple refunded / revoked the transaction.
  final DateTime? revocationDate;

  /// True when the customer upgraded to a higher tier mid-period; the
  /// upgraded-from transaction no longer grants access.
  final bool isUpgraded;

  ProTier get tier => tierOfProduct(productId);

  /// Whether this transaction grants its tier at [now].
  bool isActiveAt(DateTime now) {
    if (tier == ProTier.none) return false;
    if (revocationDate != null || isUpgraded) return false;
    final expiration = expirationDate;
    return expiration == null || expiration.isAfter(now);
  }

  static DateTime? _parseMs(Object? value) {
    final ms = switch (value) {
      num n => n.toInt(),
      String s => int.tryParse(s) ?? double.tryParse(s)?.toInt(),
      _ => null,
    };
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}

/// Derives the current tier from the customer's StoreKit 2 transaction
/// history (`Transaction.all`), counting only our product IDs whose period
/// hasn't ended and that weren't revoked/upgraded; the highest active tier
/// wins.
///
/// Returns `null` — "inconclusive, keep the cached tier" — when the history
/// holds no transaction for our products at all. A subscriber's history is
/// never empty (expired and refunded transactions stay in it), so an empty
/// list means StoreKit couldn't tell us anything (offline, not synced, a
/// fetch error mapped to `[]`), and the caller must not downgrade on that.
ProTier? deriveProTier(
  Iterable<ProEntitlementTransaction> transactions, {
  required DateTime now,
}) {
  var sawOurs = false;
  var highest = ProTier.none;
  for (final t in transactions) {
    final tier = t.tier;
    if (tier == ProTier.none) continue;
    sawOurs = true;
    if (t.isActiveAt(now) && tier.index > highest.index) highest = tier;
  }
  return sawOurs ? highest : null;
}

/// The tier [ProService] should hold after a launch-time entitlement check.
///
/// Never downgrades on missing information: an inconclusive history (see
/// [deriveProTier]) keeps [cached], and so does any *downgrade* while the App
/// Store isn't reachable ([storeReachable] false) — StoreKit serves
/// `Transaction.all` from an on-device cache when offline, which may not yet
/// include a renewal that happened since the last sync. Upgrades are always
/// applied (an active transaction is proof enough on its own).
ProTier resolveProTier({
  required ProTier cached,
  required Iterable<ProEntitlementTransaction> transactions,
  required DateTime now,
  required bool storeReachable,
}) {
  final derived = deriveProTier(transactions, now: now);
  if (derived == null) return cached;
  if (derived.index < cached.index && !storeReachable) return cached;
  return derived;
}
