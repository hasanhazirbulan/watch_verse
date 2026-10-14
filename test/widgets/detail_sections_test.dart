import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/api_service.dart';
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

  test('where-to-watch: a US fallback / rent listing is not "streaming here"',
      () {
    Map<String, dynamic> p(int id, String name) =>
        {'provider_id': id, 'provider_name': name, 'logo_path': ''};
    final results = <String, dynamic>{
      'US': {
        'flatrate': [p(8, 'Netflix')],
      },
      'GB': {
        'rent': [p(9, 'Amazon')],
        'flatrate': [p(337, 'Disney Plus')],
      },
    };
    // No DE entry: the logos fall back to the US list, but nothing in it
    // streams in Germany.
    final de = APIservices.whereToWatchFromResults(results, 'DE');
    expect(de.all.map((e) => e.id), [8]);
    expect(de.streamingHere, isEmpty);
    // Rent/buy is shown but isn't part of a subscription.
    final gb = APIservices.whereToWatchFromResults(results, 'GB');
    expect(gb.all.map((e) => e.id), [337, 9]);
    expect(gb.streamingHere, {337});
  });

  testWidgets(
      'WatchProvidersSection does not claim "On your" for a provider that '
      'is not streaming in the region', (tester) async {
    const netflix =
        WatchProvider(id: 8, name: 'Netflix', logoPath: '');
    await tester.pumpWidget(_wrap(const WatchProvidersSection(
      providers: [netflix],
      myProviderIds: {8},
      streamingHere: {},
    )));
    expect(find.text('On your Netflix'), findsNothing);

    await tester.pumpWidget(_wrap(const WatchProvidersSection(
      providers: [netflix],
      myProviderIds: {8},
      streamingHere: {8},
    )));
    expect(find.text('On your Netflix'), findsOneWidget);
  });

  testWidgets('WatchProvidersSection renders nothing without providers',
      (tester) async {
    await tester
        .pumpWidget(_wrap(const WatchProvidersSection(providers: [])));
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Wrap), findsNothing);
  });
}
