import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/pro_entitlement.dart';

void main() {
  final now = DateTime(2026, 10, 15, 12);
  final future = now.add(const Duration(days: 10));
  final past = now.subtract(const Duration(days: 10));

  ProEntitlementTransaction tx(
    String productId, {
    DateTime? expires,
    DateTime? revoked,
    bool upgraded = false,
  }) => ProEntitlementTransaction(
    productId: productId,
    expirationDate: expires,
    revocationDate: revoked,
    isUpgraded: upgraded,
  );

  group('deriveProTier', () {
    test('active Pro', () {
      expect(
        deriveProTier([tx(proMonthlyProductId, expires: future)], now: now),
        ProTier.pro,
      );
    });

    test('active Patron', () {
      expect(
        deriveProTier([tx(patronYearlyProductId, expires: future)], now: now),
        ProTier.patron,
      );
    });

    test('expired subscription -> none', () {
      expect(
        deriveProTier([
          tx(proMonthlyProductId, expires: past),
          tx(patronMonthlyProductId, expires: past),
        ], now: now),
        ProTier.none,
      );
    });

    test('mixed: expired Patron + active Pro -> Pro', () {
      expect(
        deriveProTier([
          tx(patronMonthlyProductId, expires: past),
          tx(proYearlyProductId, expires: future),
        ], now: now),
        ProTier.pro,
      );
    });

    test('revoked (refunded) Patron -> none', () {
      expect(
        deriveProTier([
          tx(patronMonthlyProductId, expires: future, revoked: past),
        ], now: now),
        ProTier.none,
      );
    });

    test('upgraded-away Pro does not count, the upgrade does', () {
      expect(
        deriveProTier([
          tx(proMonthlyProductId, expires: future, upgraded: true),
        ], now: now),
        ProTier.none,
      );
      expect(
        deriveProTier([
          tx(proMonthlyProductId, expires: future, upgraded: true),
          tx(patronMonthlyProductId, expires: future),
        ], now: now),
        ProTier.patron,
      );
    });

    test('foreign product IDs are ignored', () {
      expect(
        deriveProTier([tx('com.other.app.sub', expires: future)], now: now),
        isNull,
      );
    });

    test('empty history is inconclusive', () {
      expect(deriveProTier(const [], now: now), isNull);
    });
  });

  group('resolveProTier', () {
    test('empty list (offline / fetch error) keeps cached tier', () {
      for (final cached in ProTier.values) {
        for (final reachable in [true, false]) {
          expect(
            resolveProTier(
              cached: cached,
              transactions: const [],
              now: now,
              storeReachable: reachable,
            ),
            cached,
          );
        }
      }
    });

    test('expired Patron downgrades to none when the store is reachable', () {
      expect(
        resolveProTier(
          cached: ProTier.patron,
          transactions: [tx(patronMonthlyProductId, expires: past)],
          now: now,
          storeReachable: true,
        ),
        ProTier.none,
      );
    });

    test('expired Patron + active Pro downgrades Patron -> Pro', () {
      expect(
        resolveProTier(
          cached: ProTier.patron,
          transactions: [
            tx(patronMonthlyProductId, expires: past),
            tx(proMonthlyProductId, expires: future),
          ],
          now: now,
          storeReachable: true,
        ),
        ProTier.pro,
      );
    });

    test('never downgrades while the store is unreachable', () {
      expect(
        resolveProTier(
          cached: ProTier.patron,
          transactions: [tx(patronMonthlyProductId, expires: past)],
          now: now,
          storeReachable: false,
        ),
        ProTier.patron,
      );
    });

    test('upgrades even while the store is unreachable', () {
      expect(
        resolveProTier(
          cached: ProTier.none,
          transactions: [tx(proMonthlyProductId, expires: future)],
          now: now,
          storeReachable: false,
        ),
        ProTier.pro,
      );
    });
  });

  group('ProEntitlementTransaction.fromStoreKit', () {
    test(
      'reads expiration (ms string) and revocation/isUpgraded from JSON',
      () {
        final t = ProEntitlementTransaction.fromStoreKit(
          productId: patronMonthlyProductId,
          expirationDateMs: '${future.millisecondsSinceEpoch}',
          jsonRepresentation:
              '{"productId":"$patronMonthlyProductId","revocationDate":'
              '${past.millisecondsSinceEpoch},"isUpgraded":false}',
        );
        expect(t.expirationDate, future);
        expect(t.revocationDate, past);
        expect(t.isActiveAt(now), isFalse);
      },
    );

    test('falls back to expiresDate in JSON; tolerates bad JSON', () {
      final fromJson = ProEntitlementTransaction.fromStoreKit(
        productId: proMonthlyProductId,
        jsonRepresentation: '{"expiresDate":${past.millisecondsSinceEpoch}.0}',
      );
      expect(fromJson.expirationDate, past);
      expect(fromJson.isActiveAt(now), isFalse);

      final bad = ProEntitlementTransaction.fromStoreKit(
        productId: proMonthlyProductId,
        expirationDateMs: '${future.millisecondsSinceEpoch}',
        jsonRepresentation: 'not json',
      );
      expect(bad.isActiveAt(now), isTrue);
    });
  });
}
