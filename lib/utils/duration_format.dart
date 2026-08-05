import 'package:flutter/widgets.dart';
import 'package:watch_verse/l10n/app_localizations.dart';

/// Formats [totalMinutes] as "2ay 5gün 3sa" (months/days/hours) once the
/// total is large enough to matter, falling back to "3sa 20dk" for anything
/// under a day so a new watcher doesn't just see "0ay 0gün 0sa".
String formatWatchDuration(BuildContext context, int totalMinutes) {
  final l10n = AppLocalizations.of(context)!;
  final totalHours = totalMinutes ~/ 60;
  final months = totalHours ~/ (24 * 30);
  final days = (totalHours % (24 * 30)) ~/ 24;
  final hours = totalHours % 24;
  if (months > 0) {
    return l10n.profileDurationMonthsDaysHours(
        months.toString(), days.toString(), hours.toString());
  }
  if (days > 0) {
    return l10n.profileDurationDaysHours(days.toString(), hours.toString());
  }
  final minutes = totalMinutes % 60;
  return l10n.profileDurationCompact(hours.toString(), minutes.toString());
}
