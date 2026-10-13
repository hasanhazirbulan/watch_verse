import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/services/legal_links.dart';
import 'package:watch_verse/services/pro_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

/// WatchVerse Pro upsell sheet — shown at every gate (list limit, advanced
/// stats; Patron profile themes) and from the Home
/// drawer. Matches the app's existing modal-sheet convention (see
/// `showQuickAddSheet` in `lib/widgets/quick_add_sheet.dart`): rounded top
/// corners, drag handle, `context.colors.surface` background.
Future<void> showPaywallSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _PaywallSheet(),
  );
}

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet();

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  late final Future<List<ProductDetails>> _packages =
      ProService.instance.fetchPackages();
  ProductDetails? _selected;
  bool _busy = false;
  ProTier _tier = ProTier.pro;

  /// Product whose StoreKit purchase this sheet started and is waiting on.
  String? _pendingProductId;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  @override
  void initState() {
    super.initState();
    // The outcome of a purchase arrives here, not from buyNonConsumable():
    // that call returns as soon as Apple's sheet is *shown*. Entitlement
    // itself is still granted by ProService's own listener — this one only
    // drives the sheet's spinner / close / error message.
    _purchaseSub = InAppPurchase.instance.purchaseStream
        .listen(_onPurchaseUpdates, onError: (Object _) {
      if (mounted && _pendingProductId != null) _purchaseFailed();
    });
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  void _onPurchaseUpdates(List<PurchaseDetails> updates) {
    final pending = _pendingProductId;
    if (!mounted || pending == null) return;
    for (final p in updates.where((u) => u.productID == pending)) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _pendingProductId = null;
          Navigator.pop(context);
          return;
        case PurchaseStatus.canceled:
          // User backed out of Apple's sheet — not an error.
          _pendingProductId = null;
          setState(() => _busy = false);
          return;
        case PurchaseStatus.error:
          _purchaseFailed();
          return;
        case PurchaseStatus.pending:
          // Ask to Buy / deferred: Apple shows its own UI; the tier is
          // granted via ProService whenever it's approved. Stop spinning.
          _pendingProductId = null;
          setState(() => _busy = false);
          return;
      }
    }
  }

  void _purchaseFailed() {
    _pendingProductId = null;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.proPurchaseFailure)));
  }

  static const _tierProductIds = {
    ProTier.pro: {proMonthlyProductId, proYearlyProductId},
    ProTier.patron: {patronMonthlyProductId, patronYearlyProductId},
  };

  void _selectTier(ProTier tier) {
    if (tier == _tier) return;
    setState(() {
      _tier = tier;
      _selected = null; // re-pick the yearly default for the new tier below
    });
  }

  // Guests (no Firebase account — see the "Continue as guest" login option)
  // can browse the paywall and see pricing same as everyone else, but can't
  // complete a purchase without an account first. Not a StoreKit limitation
  // — it's that every paid perk (unlimited lists, advanced stats, profile
  // themes) is itself account-gated
  // elsewhere in the app, so a guest's purchase would unlock nothing they
  // could actually use until they signed in anyway.
  bool get _signedIn => FirebaseAuth.instance.currentUser != null;

  void _promptSignIn(AppLocalizations l10n) {
    // Capture these before popping the sheet — `context` becomes unusable
    // for fresh ancestor lookups right after `Navigator.pop`.
    final rootNav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context); // close the sheet first
    messenger.showSnackBar(SnackBar(content: Text(l10n.proSignInRequired)));
    rootNav.pushNamed('/login');
  }

  Future<void> _purchase(AppLocalizations l10n) async {
    if (!_signedIn) {
      _promptSignIn(l10n);
      return;
    }
    final product = _selected;
    if (product == null || _busy) return;
    setState(() => _busy = true);
    // Not ProService.purchase(): it judges success 600ms after Apple's sheet
    // merely *opens*, so a real buyer was shown "purchase failed" while
    // still confirming, and the sheet never closed once they had. The
    // result is now taken from purchaseStream (see _onPurchaseUpdates).
    _pendingProductId = product.id;
    bool started;
    try {
      started = await InAppPurchase.instance.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: product));
    } catch (e) {
      debugPrint('Paywall: buyNonConsumable threw: $e');
      started = false;
    }
    if (!mounted) return;
    if (!started && _pendingProductId == product.id) _purchaseFailed();
  }

  Future<void> _restore(AppLocalizations l10n) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await ProService.instance.restore();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? l10n.proRestoreSuccess : l10n.proRestoreFailure)));
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Scrollable: header + toggle + features + plans + CTA + legal text is
    // taller than an iPhone SE screen (and most phones at large text), and a
    // bare Column overflowed, pushing the buy/restore buttons off-screen.
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(context),
            const SizedBox(height: 18),
            _header(context, l10n),
            const SizedBox(height: 18),
            _tierToggle(context, l10n),
            const SizedBox(height: 18),
            if (_tier == ProTier.pro) ...[
              _feature(context, Icons.bar_chart_rounded, l10n.proFeatureStats),
              _feature(context, Icons.playlist_add_check_rounded, l10n.proFeatureLists),
            ] else ...[
              _feature(context, Icons.check_circle_rounded, l10n.proFeatureEverythingInPro),
              _feature(context, Icons.palette_rounded, l10n.proFeatureProfile),
              _feature(context, Icons.military_tech_rounded, l10n.proFeatureBadge),
            ],
            const SizedBox(height: 22),
            FutureBuilder<List<ProductDetails>>(
              future: _packages,
              builder: (context, snap) {
                final all = snap.data ?? const [];
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final tierIds = _tierProductIds[_tier]!;
                final products =
                    all.where((p) => tierIds.contains(p.id)).toList();
                if (products.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l10n.proNotConfigured,
                        style: TextStyle(color: context.colors.textMuted)),
                  );
                }
                // Avoid `firstWhere(..., orElse: () => products.first)`
                // here: on iOS, `queryProductDetails` hands back a concrete
                // `List<AppStoreProduct2Details>` upcast to
                // `List<ProductDetails>`. `firstWhere`'s generic `orElse`
                // parameter is bound to the list's *actual* runtime type
                // argument, not the static `ProductDetails` type, so a
                // closure statically typed to return `ProductDetails`
                // throws a runtime type error there. `where(...).firstOrNull`
                // doesn't take a typed closure parameter, so it can't hit
                // that mismatch.
                final yearly = products.where((p) =>
                    p.id == proYearlyProductId || p.id == patronYearlyProductId);
                _selected ??= yearly.isNotEmpty ? yearly.first : products.first;
                return Column(
                  children: [
                    ...products.map((p) => _planTile(context, p)),
                    const SizedBox(height: 16),
                    _ctaButton(context, l10n),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: _busy ? null : () => _restore(l10n),
                        child: Text(l10n.proRestore),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            _legalFooter(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _legalFooter(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        // Apple guideline 3.1.2: auto-renewable subscriptions must disclose
        // length/price/renewal/cancellation terms visibly in the purchase
        // flow itself, not just via a linked Terms of Use page.
        Text(
          l10n.proSubscriptionTerms,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textMuted, fontSize: 11.5),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.proLegalFooter,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textMuted, fontSize: 11.5),
        ),
        const SizedBox(height: 2),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              onPressed: () => LegalLinks.open(LegalLinks.termsOfService),
              child: Text(l10n.settingsTermsOfService,
                  style: const TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: () => LegalLinks.open(LegalLinks.privacyPolicy),
              child: Text(l10n.settingsPrivacyPolicy,
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _handle(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: context.colors.textMuted,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );

  Widget _header(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: context.colors.brandGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.proSheetTitle,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              Text(l10n.proSheetSubtitle,
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tierToggle(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _tierSegment(context, ProTier.pro, l10n.proTierPro),
          _tierSegment(context, ProTier.patron, l10n.proTierPatron),
        ],
      ),
    );
  }

  Widget _tierSegment(BuildContext context, ProTier tier, String label) {
    final selected = _tier == tier;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectTier(tier),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? context.colors.brandGradient : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : context.colors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _feature(BuildContext context, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _planTile(BuildContext context, ProductDetails product) {
    final selected = _selected?.id == product.id;
    final isAnnual =
        product.id == proYearlyProductId || product.id == patronYearlyProductId;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selected = product),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? context.colors.primary : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? context.colors.primary : context.colors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isAnnual ? l10n.proYearly : l10n.proMonthly,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              Text(product.price,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ctaButton(BuildContext context, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: context.colors.brandGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _busy ? null : () => _purchase(l10n),
            child: Center(
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(_signedIn ? l10n.proContinue : l10n.proSignInToContinue,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}
