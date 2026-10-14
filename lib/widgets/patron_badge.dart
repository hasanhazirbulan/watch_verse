import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/theme/app_theme.dart';

/// Small gold "Patron" pill shown next to a Patron subscriber's name on their
/// own and public profile. Driven by the `patron` flag ProService writes to
/// `users/{uid}`.
class PatronBadge extends StatelessWidget {
  const PatronBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final gold = context.colors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gold, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, size: 13, color: gold),
          const SizedBox(width: 3),
          Text(
            AppLocalizations.of(context)!.patronBadgeLabel,
            style: TextStyle(
                color: gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}
