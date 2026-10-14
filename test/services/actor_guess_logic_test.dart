import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/actor_guess_logic.dart';
import 'package:watch_verse/services/actor_guess_service.dart';

ActorGuessPuzzle _puzzle({int id = 1, String name = 'Léa Seydoux'}) =>
    ActorGuessPuzzle(
      id: id,
      name: name,
      profilePath: '/p.jpg',
      debutYear: 2006,
      country: 'France',
      characterName: 'Madeleine',
      characterTitle: 'No Time to Die',
      titles: [
        for (var i = 0; i < 9; i++)
          ActorGuessTitle(
            id: i,
            type: 'movie',
            title: 'T$i',
            year: 2000,
            posterPath: '',
          ),
      ],
    );

void main() {
  group('day index', () {
    test('rolls over at midnight EST (05:00 UTC), not UTC midnight', () {
      final before = DateTime.utc(2026, 10, 14, 4, 59);
      final after = DateTime.utc(2026, 10, 14, 5, 0);
      expect(actorGuessDayIndex(after) - actorGuessDayIndex(before), 1);
      expect(actorGuessDateKey(before), '2026-10-13');
      expect(actorGuessDateKey(after), '2026-10-14');
    });

    test('matches the daily movie game anchor (2024-01-01 EST = day 0)', () {
      expect(actorGuessDayIndex(DateTime.utc(2024, 1, 1, 5)), 0);
      expect(actorGuessDayIndex(DateTime.utc(2024, 1, 2, 5)), 1);
    });

    test('play doc id is prefixed and dated', () {
      expect(
        actorGuessPlayDocId(DateTime.utc(2026, 1, 5, 12)),
        'actor-2026-01-05',
      );
    });

    test('puzzle wraps around the pool; empty pool gives null', () {
      final pool = [_puzzle(id: 1), _puzzle(id: 2), _puzzle(id: 3)];
      expect(actorGuessPuzzleForDay(pool, 0)!.id, 1);
      expect(actorGuessPuzzleForDay(pool, 4)!.id, 2);
      expect(actorGuessPuzzleForDay(const [], 4), isNull);
    });
  });

  group('clue schedule', () {
    test('one clue up front, one more per miss, capped at six', () {
      expect(actorGuessCluesVisible(0, finished: false), 1);
      expect(actorGuessCluesVisible(3, finished: false), 4);
      expect(actorGuessCluesVisible(9, finished: false), 6);
    });

    test('everything is revealed once finished', () {
      expect(actorGuessCluesVisible(0, finished: true), 6);
    });

    test('order goes hard to easy and ends on the photo', () {
      expect(ActorGuessClue.values.first, ActorGuessClue.origin);
      expect(ActorGuessClue.values.last, ActorGuessClue.photo);
      expect(ActorGuessClue.values.length, actorGuessMaxAttempts);
    });

    test('title clue slices: deep cuts 7-9, known 4-6, top 1-3', () {
      final p = _puzzle();
      expect(p.topTitles.map((t) => t.title), ['T0', 'T1', 'T2']);
      expect(p.knownTitles.map((t) => t.title), ['T3', 'T4', 'T5']);
      expect(p.deepCutTitles.map((t) => t.title), ['T6', 'T7', 'T8']);
    });
  });

  group('name matching', () {
    test('normalizes case, diacritics and punctuation', () {
      expect(normalizeActorName('Léa Seydoux'), 'lea seydoux');
      expect(normalizeActorName('  LEA   seydoux '), 'lea seydoux');
      expect(normalizeActorName('Daniel Brühl'), 'daniel bruhl');
      expect(normalizeActorName('Ciarán Hinds'), 'ciaran hinds');
      expect(
        normalizeActorName('Joseph Gordon-Levitt'),
        'joseph gordon levitt',
      );
      expect(normalizeActorName('Robert Downey Jr.'), 'robert downey jr');
      expect(normalizeActorName('Şükrü Özyıldız'), 'sukru ozyildiz');
    });

    test('correct by id or by normalized name', () {
      final p = _puzzle(id: 42);
      expect(
        isActorGuessCorrect(guessId: 42, guessName: 'x', puzzle: p),
        isTrue,
      );
      expect(
        isActorGuessCorrect(guessId: 7, guessName: 'LEA SEYDOUX', puzzle: p),
        isTrue,
      );
      expect(
        isActorGuessCorrect(guessId: 7, guessName: 'Lea Michele', puzzle: p),
        isFalse,
      );
      expect(
        isActorGuessCorrect(guessId: 7, guessName: '', puzzle: p),
        isFalse,
      );
    });
  });

  group('share text', () {
    test('win shows misses then a hit, no names', () {
      final text = actorGuessShareText(
        gameTitle: "Who's the Actor?",
        dateKey: '2026-10-14',
        guessCount: 3,
        won: true,
      );
      expect(text, "WatchVerse · Who's the Actor? · 2026-10-14\n🟥🟥🟩 3/6");
    });

    test('loss is X/6', () {
      final text = actorGuessShareText(
        gameTitle: 'G',
        dateKey: 'd',
        guessCount: 6,
        won: false,
      );
      expect(text.endsWith('🟥🟥🟥🟥🟥🟥 X/6'), isTrue);
    });
  });

  group('parsing', () {
    test('pool skips malformed entries', () {
      final pool = parseActorGuessPool({
        'actors': [
          {
            'id': 1,
            'name': 'A',
            'character': {'name': 'C', 'title': 'T'},
            'titles': [
              {'id': 5, 'type': 'tv', 'title': 'Show', 'year': 2001},
              {'id': 'bad'},
            ],
          },
          {'id': 2, 'name': 'No titles', 'character': {}, 'titles': []},
          'junk',
        ],
      });
      expect(pool, hasLength(1));
      expect(pool.single.titles.single.isTv, isTrue);
      expect(() => parseActorGuessPool({}), throwsFormatException);
    });

    test('progress tolerates missing/odd fields', () {
      final p = ActorGuessProgress.fromMap({
        'guesses': [
          {'id': 3, 'name': 'X'},
          {'id': 4.0, 'name': 'Y'},
          'junk',
        ],
        'won': true,
        'finished': true,
      });
      expect(p.guesses.map((g) => g.id), [3, 4]);
      expect(p.wrongGuesses, 1);
      expect(ActorGuessProgress.fromMap(null).guesses, isEmpty);
    });

    test('search keeps actors only, most popular first', () {
      final results = parseActorGuessSearch({
        'results': [
          {
            'id': 1,
            'name': 'Extra Chris',
            'known_for_department': 'Acting',
            'popularity': 1.0,
          },
          {
            'id': 2,
            'name': 'Chris Director',
            'known_for_department': 'Directing',
            'popularity': 50.0,
          },
          {
            'id': 3,
            'name': 'Chris Hemsworth',
            'known_for_department': 'Acting',
            'popularity': 40.0,
            'profile_path': '/c.jpg',
            'known_for': [
              {'title': 'Thor'},
              {'name': 'Some Show'},
            ],
          },
          {
            'id': 4,
            'name': 'Adult',
            'adult': true,
            'known_for_department': 'Acting',
          },
        ],
      });
      expect(results.map((r) => r.id), [3, 1]);
      expect(results.first.knownFor, ['Thor', 'Some Show']);
    });
  });

  group('bundled pool asset', () {
    final file = File('assets/games/actor_guess_pool.json');
    final pool = parseActorGuessPool(json.decode(file.readAsStringSync()));

    test('has at least a year of unique actors with full clue data', () {
      expect(pool.length, greaterThanOrEqualTo(365));
      expect(pool.map((p) => p.id).toSet().length, pool.length);
      for (final p in pool) {
        expect(p.titles.length, greaterThanOrEqualTo(9), reason: p.name);
        expect(p.profilePath, isNotEmpty, reason: p.name);
        expect(p.country, isNotEmpty, reason: p.name);
        expect(p.characterName, isNotEmpty, reason: p.name);
        expect(p.debutYear, greaterThan(1900), reason: p.name);
      }
    });

    test('no clue contains a word of the actor\'s name', () {
      for (final p in pool) {
        final nameWords = normalizeActorName(
          p.name,
        ).split(' ').where((w) => w.length >= 3).toSet();
        final clues = [p.characterName, ...p.titles.map((t) => t.title)];
        for (final clue in clues) {
          final words = normalizeActorName(clue).split(' ').toSet();
          expect(
            words.intersection(nameWords),
            isEmpty,
            reason: '${p.name}: "$clue"',
          );
        }
      }
    });
  });

  group('ActorGuessService progress', () {
    test('records guesses under actor-{date} and streams them back', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1'),
      );
      final service = ActorGuessService.test(firestore: firestore, auth: auth);
      final now = DateTime.utc(2026, 10, 14, 12);

      await service.recordGuess(
        utcNow: now,
        guess: const ActorGuessEntry(1, 'Wrong'),
        won: false,
        finished: false,
      );
      await service.recordGuess(
        utcNow: now,
        guess: const ActorGuessEntry(2, 'Right'),
        won: true,
        finished: true,
      );

      final doc = await firestore
          .doc('users/u1/gamePlays/actor-2026-10-14')
          .get();
      expect(doc.data()!['game'], 'actor');
      final progress = await service.progressStream(now).first;
      expect(progress.guesses.map((g) => g.name), ['Wrong', 'Right']);
      expect(progress.won, isTrue);
      expect(progress.finished, isTrue);
    });

    test('signed out: nothing written, empty progress', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ActorGuessService.test(
        firestore: firestore,
        auth: MockFirebaseAuth(),
      );
      final now = DateTime.utc(2026, 10, 14, 12);
      await service.recordGuess(
        utcNow: now,
        guess: const ActorGuessEntry(1, 'X'),
        won: false,
        finished: false,
      );
      expect((await service.progressStream(now).first).guesses, isEmpty);
      expect((await firestore.collection('users').get()).docs, isEmpty);
    });
  });
}
