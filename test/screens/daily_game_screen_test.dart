import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/game_clue_movie.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/daily_game_screen.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/daily_game_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

const _mysteryId = 999;

GameClueMovie _clue(int id) => GameClueMovie(
  id: id,
  title: 'Movie $id',
  posterPath: '',
  directors: const ['Someone'],
  productionCompanies: const ['Studio'],
  releaseYear: 2000,
  revenue: 0,
  voteAverage: 6,
  certification: 'PG',
  genres: const ['Drama'],
  cast: const ['Actor'],
);

MediaItem _item(int id, String title) => MediaItem(
  id: id,
  title: title,
  overview: '',
  posterPath: '',
  backdropPath: '',
  date: '2000-01-01',
  voteAverage: 6,
  mediaType: MediaType.movie,
);

class _StubApi extends APIservices {
  @override
  Future<GameClueMovie> getGameClueData(int movieId) async => _clue(movieId);

  @override
  Future<List<MediaItem>> searchGameMovies(String query) async => [
    _item(1, 'Decoy One'),
    _item(2, 'Decoy Two'),
  ];
}

/// Like the real Firestore client offline / on a slow network: the guess
/// lands in the (fake) local cache straight away, so the progress stream
/// shows it, but the write's future never completes (no server ack), or
/// fails when [failWrites] is set.
class _UnackedService implements DailyGameService {
  _UnackedService(this._inner);
  final DailyGameService _inner;
  bool failWrites = false;
  final recorded = <({int id, bool won, bool finished})>[];

  @override
  int get todayIndex => _inner.todayIndex;
  @override
  DateTime dateForDay(int day) => _inner.dateForDay(day);
  @override
  String dateKeyForDay(int day) => _inner.dateKeyForDay(day);
  @override
  Future<GameClueMovie?> mysteryMovieForDay(int day) =>
      _inner.mysteryMovieForDay(day);
  @override
  Future<GameClueMovie> clueData(int movieId) => _inner.clueData(movieId);
  @override
  Stream<DailyGamePlay> progressStream(int day) => _inner.progressStream(day);
  @override
  Future<void> useHint(int day, int hintsUsed) =>
      _inner.useHint(day, hintsUsed);

  @override
  Future<void> recordGuess({
    required int day,
    required int guessedMovieId,
    required bool won,
    required bool finished,
  }) {
    recorded.add((id: guessedMovieId, won: won, finished: finished));
    if (failWrites) return Future.error(Exception('permission-denied'));
    _inner.recordGuess(
      day: day,
      guessedMovieId: guessedMovieId,
      won: won,
      finished: finished,
    );
    return Completer<void>().future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  late FakeFirebaseFirestore firestore;
  late _UnackedService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'dailyGameHowToSeen': true});
    firestore = FakeFirebaseFirestore();
    await firestore.doc('gameConfig/dailyMoviePool').set({
      'movieIds': [_mysteryId],
    });
    service = _UnackedService(
      DailyGameService.test(
        firestore: firestore,
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
        api: _StubApi(),
      ),
    );
  });

  String docPath() =>
      'users/u1/gamePlays/${service.dateKeyForDay(service.todayIndex)}';

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(DailyGameScreen(service: service, api: _StubApi(), signedIn: true)),
    );
    await flush(tester);
  }

  Future<void> search(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'de');
    await tester.pump(const Duration(milliseconds: 350));
    await flush(tester);
  }

  bool fieldEnabled(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).enabled ?? true;

  testWidgets('the next guess unlocks from the local snapshot, no ack', (
    tester,
  ) async {
    await pumpGame(tester);
    expect(find.text('10 guesses left'), findsOneWidget);

    await search(tester);
    await tester.tap(find.text('Decoy One'));
    await flush(tester);
    expect(find.text('9 guesses left'), findsOneWidget);
    expect(fieldEnabled(tester), isTrue);

    await search(tester);
    await tester.tap(find.text('Decoy Two'));
    await flush(tester);
    expect(find.text('8 guesses left'), findsOneWidget);

    expect(service.recorded.map((r) => r.id), [1, 2]);
    final doc = await firestore.doc(docPath()).get();
    expect(doc.data()!['guessedIds'], [1, 2]);
    expect(doc.data()!['finished'], false);
    // Let the clue tiles' staggered flip timers run out.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the last allowed guess finishes the day', (tester) async {
    await firestore.doc(docPath()).set({
      'guessedIds': [for (var i = 11; i < 20; i++) i],
      'won': false,
      'finished': false,
    });
    await pumpGame(tester);
    expect(find.text('1 guesses left'), findsOneWidget);

    await search(tester);
    await tester.tap(find.text('Decoy One'));
    await flush(tester);

    expect(service.recorded.single, (id: 1, won: false, finished: true));
    expect(find.text('Out of guesses'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    // Let the clue tiles' staggered flip timers run out.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rejected write shows the error and unlocks', (tester) async {
    service.failWrites = true;
    await pumpGame(tester);

    await search(tester);
    await tester.tap(find.text('Decoy One'));
    await flush(tester);

    expect(find.text('An error occurred.'), findsOneWidget);
    expect(find.text('10 guesses left'), findsOneWidget);
    expect(fieldEnabled(tester), isTrue);
    // Let the clue tiles' staggered flip timers run out.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
