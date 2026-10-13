import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/detail_sections.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets(
      'WatchProvidersSection falls back to a letter tile when a logo fails',
      (tester) async {
    // flutter_test's HttpClient answers every request with HTTP 400, so the
    // logo load fails exactly like a dead CDN URL would.
    await tester.pumpWidget(_wrap(const WatchProvidersSection(providers: [
      WatchProvider(id: 8, name: 'Netflix', logoPath: '/netflix.png'),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('N'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('WatchProvidersSection renders nothing without providers',
      (tester) async {
    await tester
        .pumpWidget(_wrap(const WatchProvidersSection(providers: [])));
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Wrap), findsNothing);
  });
}
