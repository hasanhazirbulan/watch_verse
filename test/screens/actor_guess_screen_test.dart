import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/actor_guess_screen.dart';
import 'package:watch_verse/services/actor_guess_logic.dart';
import 'package:watch_verse/services/actor_guess_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  // Parsed directly: rootBundle caches the asset future across tests, and a
  // future created in one test's fake-async zone never resolves in the next.
  // Image paths are blanked so TmdbImage shows its placeholder instead of
  // CachedNetworkImage reaching for path_provider (no plugin in tests); the
  // real names/titles stay, so text lengths are realistic for the layout.
  final pool = [
    for (final p in parseActorGuessPool(
      json.decode(
        File('assets/games/actor_guess_pool.json').readAsStringSync(),
      ),
    ))
      ActorGuessPuzzle(
        id: p.id,
        name: p.name,
        profilePath: '',
        debutYear: p.debutYear,
        country: p.country,
        characterName: p.characterName,
        characterTitle: p.characterTitle,
        titles: [
          for (final t in p.titles)
            ActorGuessTitle(
              id: t.id,
              type: t.type,
              title: t.title,
              year: t.year,
              posterPath: '',
            ),
        ],
      ),
  ];
  late FakeFirebaseFirestore firestore;
  late ActorGuessService service;
  final docPath =
      'users/u1/gamePlays/${actorGuessPlayDocId(DateTime.now().toUtc())}';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ActorGuessService.test(
      firestore: firestore,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
      pool: pool,
    );
  });

  Future<void> pumpSmall(WidgetTester tester, Widget w) async {
    // iPhone SE (1st gen) logical size.
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(w));
    // Asset load + Firestore snapshot both complete outside the fake clock.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  testWidgets('guest sees the sign-in prompt', (tester) async {
    await pumpSmall(
      tester,
      ActorGuessScreen(service: service, signedIn: false),
    );
    expect(find.text("Sign in to play Who's the Actor?"), findsOneWidget);
  });

  testWidgets('fresh game shows one clue and the search field on an SE', (
    tester,
  ) async {
    await pumpSmall(tester, ActorGuessScreen(service: service, signedIn: true));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('Clue 1'), findsOneWidget);
    expect(find.textContaining('Clue 2'), findsNothing);
    expect(find.text('6 guesses left'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('open keyboard on an SE does not overflow', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 253);
    addTearDown(tester.view.resetViewInsets);
    await pumpSmall(tester, ActorGuessScreen(service: service, signedIn: true));
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('five misses reveal all six clues without overflow', (
    tester,
  ) async {
    await firestore.doc(docPath).set({
      'guesses': [
        for (var i = 0; i < 5; i++) {'id': -1 - i, 'name': 'Nobody $i'},
      ],
      'won': false,
      'finished': false,
    });
    await pumpSmall(tester, ActorGuessScreen(service: service, signedIn: true));
    expect(find.text('1 guesses left'), findsOneWidget);
    expect(find.textContaining('Clue 6'), findsOneWidget);
    expect(find.text('Nobody 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finished game shows the result panel instead of search', (
    tester,
  ) async {
    await firestore.doc(docPath).set({
      'guesses': [
        for (var i = 0; i < 6; i++) {'id': -1 - i, 'name': 'Nobody $i'},
      ],
      'won': false,
      'finished': true,
    });
    await pumpSmall(tester, ActorGuessScreen(service: service, signedIn: true));
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Out of guesses'), findsOneWidget);
    expect(find.text('Share result'), findsOneWidget);
    expect(find.text('View filmography'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
