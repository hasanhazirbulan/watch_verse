import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/models/game_clue_movie.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/daily_game_clues.dart';

GameClueMovie movie({
  int id = 1,
  List<String> directors = const ['Nolan'],
  List<String> studios = const ['Syncopy', 'Warner Bros.'],
  int year = 2010,
  int revenue = 800000000,
  double rating = 8.4,
  String cert = 'PG-13',
  List<String> genres = const ['Action', 'Sci-Fi'],
  List<String> cast = const ['A', 'B', 'C'],
}) =>
    GameClueMovie(
      id: id,
      title: 'M$id',
      posterPath: '',
      directors: directors,
      productionCompanies: studios,
      releaseYear: year,
      revenue: revenue,
      voteAverage: rating,
      certification: cert,
      genres: genres,
      cast: cast,
    );

GameClue clue(List<GameClue> clues, ClueKind kind) =>
    clues.firstWhere((c) => c.kind == kind);

void main() {
  final mystery = movie();

  group('compareGameClues', () {
    test('the mystery itself is all green with no arrows', () {
      final clues = compareGameClues(mystery, mystery);
      expect(clues, hasLength(8));
      for (final c in clues) {
        expect(c.match, ClueMatch.exact, reason: c.kind.name);
        expect(c.direction, ClueDirection.none, reason: c.kind.name);
      }
    });

    test('winning row stays green even where TMDB has no data', () {
      final sparse = movie(cert: '', revenue: 0, directors: const []);
      final clues = compareGameClues(sparse, sparse);
      expect(clues.every((c) => c.match == ClueMatch.exact), isTrue);
    });

    test('year: arrow points toward the mystery, close within 5', () {
      final older = clue(compareGameClues(movie(id: 2, year: 2007), mystery),
          ClueKind.year);
      expect(older.match, ClueMatch.close);
      expect(older.direction, ClueDirection.higher);
      expect(older.value, '2007');

      final newer = clue(compareGameClues(movie(id: 2, year: 2020), mystery),
          ClueKind.year);
      expect(newer.match, ClueMatch.none);
      expect(newer.direction, ClueDirection.lower);
    });

    test('box office 0 is unknown — no arrow, not a miss', () {
      final unknownGuess = clue(
          compareGameClues(movie(id: 2, revenue: 0), mystery),
          ClueKind.revenue);
      expect(unknownGuess.match, ClueMatch.unknown);
      expect(unknownGuess.direction, ClueDirection.none);
      expect(unknownGuess.value, '');

      final unknownMystery = clue(
          compareGameClues(movie(id: 2), movie(revenue: 0)), ClueKind.revenue);
      expect(unknownMystery.match, ClueMatch.unknown);
      expect(unknownMystery.direction, ClueDirection.none);
      expect(unknownMystery.value, r'$800M');
    });

    test('box office: close within 50%, arrows otherwise', () {
      final close = clue(
          compareGameClues(movie(id: 2, revenue: 500000000), mystery),
          ClueKind.revenue);
      expect(close.match, ClueMatch.close);
      expect(close.direction, ClueDirection.higher);

      final far = clue(
          compareGameClues(movie(id: 2, revenue: 2000000000), mystery),
          ClueKind.revenue);
      expect(far.match, ClueMatch.none);
      expect(far.direction, ClueDirection.lower);

      // Reads the same on the tile → green, not a confusing "higher".
      final same = clue(
          compareGameClues(movie(id: 2, revenue: 800400000), mystery),
          ClueKind.revenue);
      expect(same.match, ClueMatch.exact);
    });

    test('rating: green only when the shown values are equal', () {
      ClueMatch at(double r) =>
          clue(compareGameClues(movie(id: 2, rating: r), mystery),
                  ClueKind.rating)
              .match;
      expect(at(8.43), ClueMatch.exact);
      expect(at(8.2), ClueMatch.close);
      expect(at(7.9), ClueMatch.close);
      expect(at(7.8), ClueMatch.none);
    });

    test('cast shows the shared actors on a partial match', () {
      final c = clue(
          compareGameClues(movie(id: 2, cast: const ['X', 'C', 'A']), mystery),
          ClueKind.cast);
      expect(c.match, ClueMatch.close);
      expect(c.value, 'C +1');
    });

    test('cast with nothing shared shows the guess\'s top two', () {
      final c = clue(
          compareGameClues(movie(id: 2, cast: const ['X', 'Y', 'Z']), mystery),
          ClueKind.cast);
      expect(c.match, ClueMatch.none);
      expect(c.value, 'X, Y');
    });

    test('genres: same set is exact, overlap is close', () {
      expect(
          clue(
                  compareGameClues(
                      movie(id: 2, genres: const ['Sci-Fi', 'Action']),
                      mystery),
                  ClueKind.genres)
              .match,
          ClueMatch.exact);
      final partial = clue(
          compareGameClues(
              movie(id: 2, genres: const ['Drama', 'Sci-Fi']), mystery),
          ClueKind.genres);
      expect(partial.match, ClueMatch.close);
      expect(partial.value, 'Sci-Fi');
    });

    test('studio: same lead studio is exact, any shared is close', () {
      final lead = clue(
          compareGameClues(movie(id: 2, studios: const ['Syncopy']), mystery),
          ClueKind.studio);
      expect(lead.match, ClueMatch.exact);
      final shared = clue(
          compareGameClues(
              movie(id: 2, studios: const ['Legendary', 'Warner Bros.']),
              mystery),
          ClueKind.studio);
      expect(shared.match, ClueMatch.close);
      expect(shared.value, 'Warner Bros.');
    });

    test('missing certification is unknown, not a miss', () {
      final c = clue(compareGameClues(movie(id: 2, cert: ''), mystery),
          ClueKind.certification);
      expect(c.match, ClueMatch.unknown);
    });
  });

  test('formatGameRevenue', () {
    expect(formatGameRevenue(0), '');
    expect(formatGameRevenue(950000), r'$950K');
    expect(formatGameRevenue(123456789), r'$123M');
    expect(formatGameRevenue(2799439100), r'$2.8B');
  });

  group('buildDailyGameShareText', () {
    test('win: score, one emoji row per guess, no titles', () {
      final rows = [
        compareGameClues(movie(id: 2, year: 2020, cast: const ['X']), mystery),
        compareGameClues(mystery, mystery),
      ];
      final text = buildDailyGameShareText(
          gameTitle: 'Daily Movie Game',
          dateLabel: '2026-10-14',
          rows: rows,
          won: true);
      final lines = text.split('\n');
      expect(lines.first, 'WatchVerse Daily Movie Game · 2026-10-14 · 2/10');
      expect(lines, hasLength(3));
      expect(lines.last, '🟩' * 8);
      expect(text, isNot(contains('M1')));
    });

    test('loss scores X', () {
      final text = buildDailyGameShareText(
          gameTitle: 'G', dateLabel: 'd', rows: const [], won: false);
      expect(text, 'WatchVerse G · d · X/10');
    });
  });

  group('APIservices.gameClueMovieFromJson', () {
    test('reads the appended credits and release dates', () {
      final m = APIservices.gameClueMovieFromJson(27205, {
        'title': 'Inception',
        'poster_path': '/p.jpg',
        'release_date': '2010-07-15',
        'revenue': 839030630,
        'vote_average': 8.369,
        'genres': [
          {'name': 'Action'},
          {'name': 'Science Fiction'},
        ],
        'production_companies': [
          {'name': 'Legendary Pictures'},
          {'name': 'Syncopy'},
        ],
        'credits': {
          'cast': [
            for (final n in ['L', 'J', 'E', 'T', 'K', 'C']) {'name': n},
          ],
          'crew': [
            {'job': 'Producer', 'name': 'Emma'},
            {'job': 'Director', 'name': 'Christopher Nolan'},
          ],
        },
        'release_dates': {
          'results': [
            {
              'iso_3166_1': 'GB',
              'release_dates': [
                {'certification': '12A'},
              ],
            },
            {
              'iso_3166_1': 'US',
              'release_dates': [
                {'certification': ''},
                {'certification': 'PG-13'},
              ],
            },
          ],
        },
      });
      expect(m.title, 'Inception');
      expect(m.releaseYear, 2010);
      expect(m.directors, ['Christopher Nolan']);
      expect(m.productionCompanies, ['Legendary Pictures', 'Syncopy']);
      expect(m.cast, ['L', 'J', 'E', 'T', 'K']);
      expect(m.certification, 'PG-13');
    });

    test('missing sections yield empty values, not a crash', () {
      final m = APIservices.gameClueMovieFromJson(1, const {});
      expect(m.directors, isEmpty);
      expect(m.releaseYear, 0);
      expect(m.certification, '');
    });
  });

  group('APIservices.rankGameSearchResults', () {
    Map<String, dynamic> r(int id, String title, int votes,
            [String date = '2000-01-01']) =>
        {'id': id, 'title': title, 'vote_count': votes, 'release_date': date};

    test('drops unreleased, undated and barely-voted titles', () {
      final out = APIservices.rankGameSearchResults([
        r(1, 'Alien', 9000, '1979-05-25'),
        r(2, 'Alien 9', 0),
        r(3, 'Alien Sequel', 500, '2030-01-01'),
        r(4, 'Alien Doc', 300, ''),
      ], 'alien', DateTime(2026, 10, 14));
      expect(out.map((m) => m['id']), [1]);
    });

    test('exact title first, then by vote count, ties keep TMDB order', () {
      final out = APIservices.rankGameSearchResults([
        r(1, 'Batman Returns', 5000),
        r(2, 'The Batman', 9000),
        r(3, 'Batman', 4000),
        r(4, 'Batman Forever', 5000),
      ], 'Batman ', DateTime(2026, 10, 14));
      expect(out.map((m) => m['id']), [3, 2, 1, 4]);
    });
  });
}
