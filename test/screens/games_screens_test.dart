import 'dart:async';
import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/games/frames_game_screen.dart';
import 'package:watch_verse/screens/games/title_wordle_screen.dart';
import 'package:watch_verse/services/games/game_day.dart';
import 'package:watch_verse/services/games/game_play_store.dart';
import 'package:watch_verse/services/games/games_tmdb.dart';
import 'package:watch_verse/services/games/pools/frames_pools.g.dart';
import 'package:watch_verse/services/games/pools/title_wordle_pools.g.dart';
import 'package:watch_verse/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// iPhone SE (1st gen) logical size — the smallest screen we support.
void _useSmallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Like pumpAndSettle, but bounded: TmdbImage's loading spinner animates
/// forever in tests (no network), so pumpAndSettle would time out.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A signed-in store whose writes never get a server ack (offline / a slow
/// connection): Firestore's `set` future only completes once acked.
class _UnackedStore implements GamePlayStore {
  final saves = <Map<String, dynamic>>[];
  @override
  bool get isSignedIn => true;
  @override
  Future<Map<String, dynamic>?> load(String docId) async => null;
  @override
  Future<void> save(String docId, Map<String, dynamic> state) {
    saves.add(state);
    return Completer<void>().future;
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late GamePlayStore store;

  setUp(() {
    db = FakeFirebaseFirestore();
    store = GamePlayStore.test(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
    );
  });

  Future<Map<String, dynamic>?> savedDoc(String game, MediaType mode) async {
    final id = gamePlayDocId(game, mode, gameDateKey(DateTime.now().toUtc()));
    final snap = await db
        .collection('users')
        .doc('u1')
        .collection('gamePlays')
        .doc(id)
        .get();
    return snap.data();
  }

  testWidgets('Title Wordle: solve today\'s movie on an iPhone SE', (
    tester,
  ) async {
    _useSmallPhone(tester);
    final answer = dailyPoolEntry(
      titleWordleMoviePool,
      gamePuzzleNumber(DateTime.now().toUtc()),
    );

    await tester.pumpWidget(_wrap(TitleWordleScreen(store: store)));
    await _settle(tester);
    expect(find.text('Title Wordle'), findsOneWidget);

    // Too short → rejected with a message, nothing saved.
    await tester.tap(find.text('Q').last);
    await tester.tap(find.byIcon(Icons.keyboard_return_rounded));
    await tester.pump();
    expect(find.text('Not enough letters'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();

    for (final ch in answer.letters.split('')) {
      await tester.tap(find.text(ch).last);
      await tester.pump();
    }
    await tester.tap(find.byIcon(Icons.keyboard_return_rounded));
    await _settle(tester);

    expect(find.text('You got it!'), findsOneWidget);
    expect(find.text('Solved in 1/6'), findsOneWidget);
    // Dark theme: the green tiles are a light color, so their letters must
    // be dark — white on them was barely readable.
    final tileLetter = tester.widget<Text>(find.text(answer.letters[0]).first);
    expect(tileLetter.style?.color, Colors.black87);
    final doc = await savedDoc('titleWordle', MediaType.movie);
    expect(doc?['won'], true);
    expect(doc?['guesses'], [answer.letters]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Title Wordle: typing the next guess doesn\'t wait for the save', (
    tester,
  ) async {
    _useSmallPhone(tester);
    final answer = dailyPoolEntry(
      titleWordleMoviePool,
      gamePuzzleNumber(DateTime.now().toUtc()),
    );
    final unacked = _UnackedStore();
    // A wrong guess: a letter that isn't the answer's first one, repeated.
    final filler = answer.letters[0] == 'Q' ? 'Z' : 'Q';
    await tester.pumpWidget(_wrap(TitleWordleScreen(store: unacked)));
    await _settle(tester);

    for (var i = 0; i < answer.letters.length; i++) {
      await tester.tap(find.text(filler).last);
      await tester.pump();
    }
    await tester.tap(find.byIcon(Icons.keyboard_return_rounded));
    await tester.pump();
    expect(unacked.saves, hasLength(1));

    // The save is still pending — the keyboard must keep working.
    await tester.tap(find.text('X').last);
    await tester.pump();
    expect(find.text('X'), findsNWidgets(2)); // key + board tile
    for (var i = 1; i < answer.letters.length; i++) {
      await tester.tap(find.text('X').last);
      await tester.pump();
    }
    await tester.tap(find.byIcon(Icons.keyboard_return_rounded));
    await tester.pump();
    expect(unacked.saves, hasLength(2));
    expect(unacked.saves.last['guesses'], hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Title Wordle: a finished puzzle stays finished on reopen', (
    tester,
  ) async {
    _useSmallPhone(tester);
    final answer = dailyPoolEntry(
      titleWordleTvPool,
      gamePuzzleNumber(DateTime.now().toUtc()),
    );
    final wrong = 'Z' * answer.letters.length;
    await db
        .collection('users')
        .doc('u1')
        .collection('gamePlays')
        .doc(
          gamePlayDocId(
            'titleWordle',
            MediaType.tv,
            gameDateKey(DateTime.now().toUtc()),
          ),
        )
        .set({'guesses': List.filled(6, wrong)});

    await tester.pumpWidget(_wrap(TitleWordleScreen(store: store)));
    await _settle(tester);
    await tester.tap(find.text('TV Shows'));
    await _settle(tester);

    expect(find.text('Not this time'), findsOneWidget);
    expect(find.text('The answer was ${answer.title}'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_return_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Frames: skip, wrong guess, then the right answer', (
    tester,
  ) async {
    _useSmallPhone(tester);
    final answerId = dailyPoolEntry(
      framesMoviePool,
      gamePuzzleNumber(DateTime.now().toUtc()),
    );
    final client = MockClient((req) async {
      if (req.url.path == '/3/movie/$answerId') {
        return http.Response(
          jsonEncode({
            'id': answerId,
            'title': 'Mystery Movie',
            'release_date': '1999-03-31',
            'poster_path': '',
            'images': {
              'backdrops': [
                for (var i = 0; i < 8; i++)
                  {
                    'file_path': '/still$i.jpg',
                    'iso_639_1': null,
                    'width': 1920,
                    'aspect_ratio': 1.778,
                    'vote_count': i,
                    'vote_average': 5.0,
                  },
              ],
            },
          }),
          200,
        );
      }
      if (req.url.path == '/3/search/movie') {
        return http.Response(
          jsonEncode({
            'results': [
              {
                'id': 1,
                'title': 'Decoy',
                'release_date': '2001-01-01',
                'vote_count': 50,
              },
              {
                'id': answerId,
                'title': 'Mystery Movie',
                'release_date': '1999-03-31',
                'vote_count': 9000,
              },
            ],
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      _wrap(
        FramesGameScreen(
          store: store,
          tmdb: GamesTmdb(client: client, key: 'test'),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('6 guesses left'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await _settle(tester);
    expect(find.text('5 guesses left'), findsOneWidget);
    expect(find.text('Skipped'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'my');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    // Best-known result is listed first.
    final tiles = find.byType(ListTile);
    expect(tiles, findsNWidgets(2));
    await tester.tap(find.text('Decoy'));
    await _settle(tester);
    expect(find.text('4 guesses left'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'my');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(find.text('Already guessed'), findsOneWidget);
    await tester.tap(find.text('Mystery Movie'));
    await _settle(tester);

    expect(find.text('You got it!'), findsOneWidget);
    expect(find.text('Solved in 3/6'), findsOneWidget);
    final doc = await savedDoc('frames', MediaType.movie);
    expect(doc?['won'], true);
    expect((doc?['guesses'] as List).length, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Frames: Skip doesn\'t wait for the save', (tester) async {
    _useSmallPhone(tester);
    final answerId = dailyPoolEntry(
      framesMoviePool,
      gamePuzzleNumber(DateTime.now().toUtc()),
    );
    final client = MockClient((req) async {
      if (req.url.path == '/3/movie/$answerId') {
        return http.Response(
          jsonEncode({
            'id': answerId,
            'title': 'Mystery Movie',
            'release_date': '1999-03-31',
            'poster_path': '',
            'images': {
              'backdrops': [
                for (var i = 0; i < 8; i++)
                  {
                    'file_path': '/still$i.jpg',
                    'iso_639_1': null,
                    'width': 1920,
                    'aspect_ratio': 1.778,
                    'vote_count': i,
                    'vote_average': 5.0,
                  },
              ],
            },
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    final unacked = _UnackedStore();
    await tester.pumpWidget(
      _wrap(
        FramesGameScreen(
          store: unacked,
          tmdb: GamesTmdb(client: client, key: 'test'),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    // The first save is still pending — Skip must keep working.
    await tester.tap(find.text('Skip'));
    await _settle(tester);
    expect(find.text('4 guesses left'), findsOneWidget);
    expect(unacked.saves, hasLength(2));
    expect(unacked.saves.last['guesses'], hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Frames: load failure shows retry', (tester) async {
    _useSmallPhone(tester);
    final client = MockClient((_) async => http.Response('oops', 500));
    await tester.pumpWidget(
      _wrap(
        FramesGameScreen(
          store: store,
          tmdb: GamesTmdb(client: client, key: 'test'),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text("Couldn't load today's puzzle."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
