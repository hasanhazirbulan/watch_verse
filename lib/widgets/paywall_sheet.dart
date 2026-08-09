import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/services/pro_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

/// WatchVerse Pro upsell sheet — shown at every gate (list limit, advanced
/// stats, Pro profile themes, CSV export, the daily game) and from the Home
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

  // Guests (no Firebase account — see the "Continue as guest" login option)
  // can browse the paywall and see pricing same as everyone else, but can't
  // complete a purchase without an account first. Not a StoreKit limitation
  // — it's that every Pro perk (unlimited lists, CSV export, profile
  // themes, the daily game's saved progress) is itself account-gated
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
    final ok = await ProService.instance.purchase(product);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.proPurchaseFailure)));
    }
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(context),
            const SizedBox(height: 18),
            _header(context, l10n),
            const SizedBox(height: 20),
            _feature(context, Icons.bar_chart_rounded, l10n.proFeatureStats),
            _feature(context, Icons.playlist_add_check_rounded, l10n.proFeatureLists),
            _feature(context, Icons.palette_rounded, l10n.proFeatureProfile),
            _feature(context, Icons.file_download_rounded, l10n.proFeatureExport),
            _feature(context, Icons.theaters_rounded, l10n.proFeatureGame),
            const SizedBox(height: 22),
            FutureBuilder<List<ProductDetails>>(
              future: _packages,
              builder: (context, snap) {
                final products = snap.data ?? const [];
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
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
                final yearly =
                    products.where((p) => p.id == proYearlyProductId);
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
          ],
        ),
      ),
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
    final isAnnual = product.id == proYearlyProductId;
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
