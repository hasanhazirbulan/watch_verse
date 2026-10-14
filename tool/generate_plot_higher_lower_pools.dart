// Generates the offline title pools for the "Higher or Lower" and "Plot"
// games (lib/screens/games/higher_lower_screen.dart,
// lib/screens/games/plot_guess_screen.dart) and writes them to
// assets/games/. Both games run with zero TMDB calls besides images, so the
// pools carry every value the games show.
//
// Run from the repo root (needs network + a TMDB key):
//
//   dart run tool/generate_plot_higher_lower_pools.dart [--secrets=path/to/secrets.json]
//       [--cache=build/game_pool_cache] [--sample=40]
//
// The key is read from $TMDB_API_KEY, else from secrets.json (repo root by
// default) — it is never printed or written anywhere. Raw TMDB responses are
// cached under --cache (gitignored build/), so re-running after tweaking the
// redaction rules is fast and reproduces the same output; delete the cache to
// pull fresh TMDB data. Selection is a fixed-seed shuffle (mulberry32, not
// dart:math's Random, whose sequence isn't guaranteed across SDKs).
//
// --sample=N prints N redacted Plot puzzles per mode for hand-checking.
//
// Plot overviews are redacted *here* with the same PlotRedactor the app's
// tests cover, using vocabulary built from every fetched overview (~3,000)
// plus the system word list (/usr/share/dict/words, if present): title
// words and character names always go; other capitalized words go unless
// they're everyday vocabulary or show up across many unrelated titles.
//
// Franchise giveaways ("Batman" in The Dark Knight Rises, "Gotham", "Jedi",
// "the Avengers" in Civil War) are hidden via the title's TMDB collection
// (other films' titles and top-billed characters) and the curated universes
// in lib/services/games/plot_franchise_vocab.dart, which also pull in every
// other title of the same universe ("Captain America: Civil War" in
// Spider-Man: Homecoming). TMDB keywords only help detect the universe
// ("marvel cinematic universe (mcu)"): they're too generic to redact by.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:watch_verse/services/games/plot_franchise_vocab.dart';
import 'package:watch_verse/services/games/plot_guess_logic.dart';

const _seed = 20261014;

const _movieDiscoverPages = 100; // ~2,000 movies by vote count
const _tvDiscoverPages = 60; // ~1,200 shows by vote count
const _movieDetailCount = 900;
const _tvDetailCount = 650;

const _higherLowerPerCategory = 400;
const _hlMovieRatingMinVotes = 3000;
const _hlTvRatingMinVotes = 800;
const _hlMinRevenue = 1000000;

const _plotMoviePoolSize = 500;
const _plotTvPoolSize = 400;

/// Capitalized words seen in at least this many unrelated titles/franchises
/// are treated as generic ("American", "FBI", "London").
const _genericGroupThreshold = 6;

/// Lower-case words used in at least this many overviews count as everyday
/// vocabulary even when capitalized mid-sentence ("the Resistance").
const _everydayMinDocs = 3;

/// Characters taken from each *other* film in a title's collection.
const _otherPartsBilling = 10;

// TMDB TV genres that aren't scripted shows people would know by plot.
const _excludedTvGenres = '10763|10764|10766|10767'; // news|reality|soap|talk

late final String _apiKey;
late final Directory _cache;

Future<void> main(List<String> args) async {
  String? arg(String name) {
    for (final a in args) {
      if (a.startsWith('--$name=')) return a.substring(name.length + 3);
    }
    return null;
  }

  _apiKey = _readKey(arg('secrets') ?? 'secrets.json');
  _cache = Directory(arg('cache') ?? 'build/game_pool_cache')
    ..createSync(recursive: true);
  final sample = int.tryParse(arg('sample') ?? '') ?? 0;

  stdout.writeln('Fetching movie/TV candidates…');
  final movieList = await _discover('/discover/movie', _movieDiscoverPages, {
    'sort_by': 'vote_count.desc',
    'include_adult': 'false',
  });
  final tvList = await _discover('/discover/tv', _tvDiscoverPages, {
    'sort_by': 'vote_count.desc',
    'without_genres': _excludedTvGenres,
  });
  stdout.writeln('  ${movieList.length} movies, ${tvList.length} shows');

  stdout.writeln('Fetching details…');
  final movieDetails = await _detailsFor(
      movieList.take(_movieDetailCount).toList(),
      (id) => '/movie/$id',
      {'append_to_response': 'credits'});
  final tvDetails = await _detailsFor(tvList.take(_tvDetailCount).toList(),
      (id) => '/tv/$id', {'append_to_response': 'aggregate_credits'});

  stdout.writeln('Fetching keywords and collections…');
  final movieKeywords = await _keywordsFor(movieDetails, isTv: false);
  final tvKeywords = await _keywordsFor(tvDetails, isTv: true);
  final collections = await _collectionsFor(movieDetails);

  // ------------------------------------------------------- Higher/Lower --
  Map<String, dynamic> hlItem(Map<String, dynamic> m, num value) => {
        'id': m['id'],
        'title': m['title'] ?? m['name'],
        'year': _year(m['release_date'] ?? m['first_air_date']),
        'posterPath': m['poster_path'] ?? '',
        'backdropPath': m['backdrop_path'] ?? '',
        'value': value,
      };
  num rating(Map<String, dynamic> m) =>
      ((m['vote_average'] as num) * 10).round() / 10;

  final hlMovieRating = _pick(
      movieList.where((m) =>
          (m['vote_count'] as num) >= _hlMovieRatingMinVotes &&
          _year(m['release_date']) > 0 &&
          m['adult'] != true),
      _higherLowerPerCategory,
      salt: 1);
  final hlRevenue = _pick(
      movieDetails.where((m) =>
          ((m['revenue'] as num?) ?? 0) >= _hlMinRevenue &&
          _year(m['release_date']) > 0),
      _higherLowerPerCategory,
      salt: 2);
  final hlTvRating = _pick(
      tvList.where((m) =>
          (m['vote_count'] as num) >= _hlTvRatingMinVotes &&
          _year(m['first_air_date']) > 0),
      _higherLowerPerCategory,
      salt: 3);
  _writeJson('assets/games/higher_lower_pool.json', {
    'version': 1,
    'seed': _seed,
    'categories': {
      'movieRating': [for (final m in hlMovieRating) hlItem(m, rating(m))],
      'movieRevenue': [for (final m in hlRevenue) hlItem(m, m['revenue'])],
      'tvRating': [for (final m in hlTvRating) hlItem(m, rating(m))],
    },
  });
  stdout.writeln('Higher/Lower: ${hlMovieRating.length} movie ratings, '
      '${hlRevenue.length} box office, ${hlTvRating.length} TV ratings');

  // --------------------------------------------------------------- Plot ---
  final movieById = {for (final m in movieDetails) m['id']: m};
  final tvById = {for (final m in tvDetails) m['id']: m};
  final franchises = <String, _Franchise>{
    for (final m in movieList)
      'm${m['id']}': _franchiseOf(movieById[m['id']] ?? m,
          isTv: false,
          keywords: movieKeywords[m['id']] ?? const [],
          collections: collections),
    for (final m in tvList)
      't${m['id']}': _franchiseOf(tvById[m['id']] ?? m,
          isTv: true,
          keywords: tvKeywords[m['id']] ?? const [],
          collections: collections),
  };
  // Every title in a universe gives away the others: "Captain America: Civil
  // War" in Spider-Man: Homecoming, "Rebels" in Andor.
  final universeTitles = <String, Set<String>>{};
  for (final f in franchises.values) {
    for (final u in f.universes) {
      universeTitles.putIfAbsent(u.key, () => {}).add(f.title);
    }
  }
  for (final f in franchises.values) {
    for (final u in f.universes) {
      f.related.addAll(universeTitles[u.key]!.where((t) => t != f.title));
    }
  }
  stdout.writeln('Universes: ${[
    for (final e in universeTitles.entries) '${e.key} ${e.value.length}'
  ].join(', ')}');
  // Generic-word stats count each collection as one group (as before) …
  final redactor = _buildRedactor([
    for (final m in movieList) (m, franchises['m${m['id']}']!.collectionGroup),
    for (final m in tvList) (m, franchises['t${m['id']}']!.collectionGroup),
  ]);
  // … while related titles' words are filtered with each universe as one
  // group: "Avengers" (only Marvel) stays a giveaway, "Earth" / "World" /
  // "America" (from "Earth's Mightiest Heroes", "The Dark World", "Captain
  // America") are used by plenty of unrelated films and stay visible.
  final universeGeneric = plotTitleWords(_genericCapitalized([
    for (final m in movieList) (m, franchises['m${m['id']}']!.universeGroup),
    for (final m in tvList) (m, franchises['t${m['id']}']!.universeGroup),
  ]));
  for (final f in franchises.values) {
    f.finish(universeGeneric, redactor.everydayWords);
  }

  final moviePuzzles = <Map<String, dynamic>>[];
  for (final m in movieDetails) {
    final p = _plotPuzzle(redactor, m, franchises['m${m['id']}']!, isTv: false);
    if (p != null) moviePuzzles.add(p);
  }
  final tvPuzzles = <Map<String, dynamic>>[];
  for (final m in tvDetails) {
    final p = _plotPuzzle(redactor, m, franchises['t${m['id']}']!, isTv: true);
    if (p != null) tvPuzzles.add(p);
  }
  final plotMovie = _pick(moviePuzzles, _plotMoviePoolSize, salt: 4);
  final plotTv = _pick(tvPuzzles, _plotTvPoolSize, salt: 5);
  for (final (mode, items) in [('movie', plotMovie), ('tv', plotTv)]) {
    _writeJson('assets/games/plot_pool_$mode.json',
        {'version': 1, 'seed': _seed, 'items': items});
  }
  stdout.writeln('Plot: ${plotMovie.length} movies (of ${moviePuzzles.length} '
      'eligible), ${plotTv.length} shows (of ${tvPuzzles.length} eligible)');

  if (sample > 0) {
    for (final items in [plotMovie, plotTv]) {
      for (final p in items.take(sample)) {
        stdout.writeln('\n## ${p['title']} (${p['year']})\n${p['overview']}');
        if ((p['tagline'] as String).isNotEmpty) {
          stdout.writeln('  tagline: ${p['tagline']}');
        }
      }
    }
  }
  _client.close();
}

// ------------------------------------------------------------------ plot ---

/// Per-title franchise context: giveaways beyond the title and the title's
/// own credits.
class _Franchise {
  _Franchise({
    required this.title,
    required this.collectionGroup,
    required this.universeGroup,
    required this.universes,
    required this.related,
    required this.characters,
  });
  final String title;

  /// The group the title counts as for generic-word stats: its collection
  /// (or itself) / its universe (or collection, or itself).
  final String collectionGroup;
  final String universeGroup;

  final List<PlotUniverse> universes;

  /// Titles of the rest of its collection and universe ("Batman Begins").
  final List<String> related;

  /// Top-billed character credits from the rest of its collection.
  final List<String> characters;

  /// What `PlotRedactor.redact` gets as `franchise` / extra `names`.
  late final ({List<String> words, List<String> phrases}) vocabulary;
  late final Set<String> names;

  void finish(Set<String> universeGeneric, Set<String> everydayWords) {
    vocabulary = plotFranchiseVocabulary(
        universes: universes, related: related, genericWords: universeGeneric);
    // Other films' casts include walk-ons ("Secret Service Agent", "Ex-Deputy
    // So & So"): keep only tokens that aren't everyday or generic words.
    names = {
      for (final n in plotNameTokens(characters))
        if (!everydayWords.contains(n.toLowerCase()) &&
            !universeGeneric.contains(n.toLowerCase()))
          n,
    };
  }
}

_Franchise _franchiseOf(Map<String, dynamic> m,
    {required bool isTv,
    required List<String> keywords,
    required Map<Object?, _Collection> collections}) {
  final coll = m['belongs_to_collection'];
  final collection = coll is Map ? collections[coll['id']] : null;
  final others = [
    for (final p in collection?.parts ?? const <_CollectionPart>[])
      if (p.id != m['id']) p,
  ];
  final titles = [
    (isTv ? m['name'] : m['title']) as String? ?? '',
    (isTv ? m['original_name'] : m['original_title']) as String? ?? '',
    if (collection != null) collection.name,
  ];
  final texts = [
    (m['overview'] as String?) ?? '',
    (m['tagline'] as String?) ?? '',
  ];
  final universes = plotUniversesFor(
      [...titles, for (final p in others) p.title, ...keywords],
      texts: texts);
  final collectionGroup =
      coll is Map ? 'c${coll['id']}' : '${isTv ? 't' : 'm'}${m['id']}';
  return _Franchise(
    title: titles.first,
    collectionGroup: collectionGroup,
    universeGroup:
        universes.isNotEmpty ? 'u${universes.first.key}' : collectionGroup,
    universes: universes,
    related: [for (final p in others) p.title],
    // Characters from the rest of the collection ("Bruce Wayne / Batman" in
    // Batman Begins when The Dark Knight Rises only credits "Bruce Wayne").
    characters: [
      for (final p in others) ...p.characters.take(_otherPartsBilling),
    ],
  );
}

final _upper = RegExp(r'^\p{Lu}', unicode: true);

/// An overview's words, hyphenated ones split, possessive "'s" dropped.
Iterable<String> _overviewWords(Map<String, dynamic> m) sync* {
  final word = RegExp(r"[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)*", unicode: true);
  for (final match in word.allMatches((m['overview'] as String?) ?? '')) {
    for (final w in match.group(0)!.split('-')) {
      final base = w.replaceAll(RegExp(r"['’]s$"), '');
      if (base.isNotEmpty) yield base;
    }
  }
}

/// Capitalized words used across at least [_genericGroupThreshold] groups.
Set<String> _genericCapitalized(List<(Map<String, dynamic>, String)> corpus) {
  final capGroups = <String, Set<String>>{};
  for (final (m, group) in corpus) {
    for (final w in _overviewWords(m)) {
      if (_upper.hasMatch(w)) capGroups.putIfAbsent(w, () => {}).add(group);
    }
  }
  return {
    for (final e in capGroups.entries)
      if (e.value.length >= _genericGroupThreshold) e.key,
  };
}

PlotRedactor _buildRedactor(List<(Map<String, dynamic>, String)> corpus) {
  final lowerDocs = <String, int>{};
  for (final (m, _) in corpus) {
    final lowerHere = <String>{
      for (final w in _overviewWords(m))
        if (!_upper.hasMatch(w)) w,
    };
    for (final w in lowerHere) {
      lowerDocs[w] = (lowerDocs[w] ?? 0) + 1;
    }
  }
  final dictionary = <String>{...lowerDocs.keys};
  final dictFile = File('/usr/share/dict/words');
  if (dictFile.existsSync()) {
    for (final line in dictFile.readAsLinesSync()) {
      if (line.isNotEmpty && line == line.toLowerCase()) dictionary.add(line);
    }
  } else {
    stderr.writeln('warning: /usr/share/dict/words missing — sentence-initial '
        'proper nouns will only be caught via credits/title words');
  }
  return PlotRedactor(
    genericCapitalized: _genericCapitalized(corpus),
    everydayWords: {
      for (final e in lowerDocs.entries)
        if (e.value >= _everydayMinDocs) e.key,
    },
    dictionaryWords: dictionary,
  );
}

Map<String, dynamic>? _plotPuzzle(
    PlotRedactor redactor, Map<String, dynamic> m, _Franchise franchise,
    {required bool isTv}) {
  final overview = _undotAcronyms(((m['overview'] as String?) ?? '').trim());
  final title = (isTv ? m['name'] : m['title']) as String? ?? '';
  final year = _year(isTv ? m['first_air_date'] : m['release_date']);
  final poster = (m['poster_path'] as String?) ?? '';
  if (m['adult'] == true || title.isEmpty || year == 0 || poster.isEmpty) {
    return null;
  }
  if (overview.length < (isTv ? 110 : 150)) return null;

  final titles = <String>[
    title,
    (isTv ? m['original_name'] : m['original_title']) as String? ?? '',
    if (m['belongs_to_collection'] is Map)
      (m['belongs_to_collection']['name'] as String? ?? ''),
  ];

  final List<Map<String, dynamic>> cast;
  final List<String> characters;
  if (isTv) {
    cast = ((m['aggregate_credits']?['cast'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .toList();
    characters = [
      for (final c in cast.take(25))
        for (final r in (c['roles'] as List? ?? const []))
          (r['character'] as String?) ?? '',
    ];
  } else {
    cast = ((m['credits']?['cast'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) => (a['order'] as num).compareTo(b['order'] as num));
    characters = [
      for (final c in cast.take(25)) (c['character'] as String?) ?? '',
    ];
  }
  if (cast.isEmpty) return null;
  // Documentaries credit people as themselves ("Himself") — then the
  // person's own name is the giveaway.
  final selfRe = RegExp(r'\b(Himself|Herself|Themselves|Self)\b');
  final names = {...franchise.names, ...plotNameTokens([
    ...characters,
    for (final c in cast.take(10))
      if (selfRe.hasMatch(isTv
          ? ((c['roles'] as List?) ?? const [])
              .map((r) => r['character'] ?? '')
              .join(' ')
          : (c['character'] as String? ?? '')))
        c['name'] as String? ?? '',
  ])};

  final redacted = redactor.redact(overview,
      titles: titles,
      names: names,
      franchise: franchise.vocabulary.words,
      franchisePhrases: franchise.vocabulary.phrases);
  final tagline = redactor.redact(
      _undotAcronyms(((m['tagline'] as String?) ?? '').trim()),
      titles: titles,
      names: names,
      franchise: franchise.vocabulary.words,
      franchisePhrases: franchise.vocabulary.phrases);

  // Reject puzzles that redaction gutted: too many blocks to be fair.
  final words = RegExp(r'\S+').allMatches(redacted).length;
  final blocks = plotRedaction.allMatches(redacted).length;
  if (words == 0 || blocks / words > 0.2) return null;

  return {
    'id': m['id'],
    'title': title,
    'year': year,
    'genres': [
      for (final g in (m['genres'] as List? ?? const [])) g['name'] as String,
    ],
    'cast': [for (final c in cast.take(2)) c['name'] as String],
    'tagline': tagline,
    'overview': redacted,
    'posterPath': poster,
  };
}

/// "S.H.I.E.L.D." → "SHIELD", so the redactor sees one word it can hide
/// (it skips single letters). Keeps a sentence-ending dot.
String _undotAcronyms(String text) => text.replaceAllMapped(
    RegExp(r'\b((?:\p{Lu}\.){5,})(?=(\s+\p{Lu}|\s*$)?)', unicode: true),
    (m) =>
        m[1]!.replaceAll('.', '') + (m[2] != null ? '.' : ''));

// ----------------------------------------------------------------- utils ---

int _year(Object? date) {
  if (date is! String || date.length < 4) return 0;
  return int.tryParse(date.substring(0, 4)) ?? 0;
}

/// Deterministic subset: sort by id (independent of TMDB's ranking jitter),
/// fixed-seed shuffle, take [count].
List<Map<String, dynamic>> _pick(
    Iterable<Map<String, dynamic>> items, int count,
    {required int salt}) {
  final seen = <Object?>{};
  final list = [
    for (final m in items)
      if (seen.add(m['id'])) m,
  ]..sort((a, b) => (a['id'] as num).compareTo(b['id'] as num));
  final rand = _Mulberry32(_seed + salt);
  for (var i = list.length - 1; i > 0; i--) {
    final j = rand.nextInt(i + 1);
    final t = list[i];
    list[i] = list[j];
    list[j] = t;
  }
  return list.take(count).toList();
}

class _Mulberry32 {
  _Mulberry32(int seed) : _state = seed & 0xFFFFFFFF;
  int _state;

  int _next() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >> 15), t | 1);
    t ^= (t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

  int nextInt(int max) => _next() % max;
}

void _writeJson(String path, Map<String, dynamic> data) {
  // One item per line: readable diffs when the pool is regenerated.
  final buf = StringBuffer('{\n');
  final entries = data.entries.toList();
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    buf.write('  ${jsonEncode(e.key)}: ');
    final v = e.value;
    if (v is List) {
      buf.write(_listJson(v, '  '));
    } else if (v is Map) {
      buf.write('{\n');
      final inner = v.entries.toList();
      for (var k = 0; k < inner.length; k++) {
        buf.write('    ${jsonEncode(inner[k].key)}: '
            '${_listJson(inner[k].value as List, '    ')}');
        buf.write(k == inner.length - 1 ? '\n' : ',\n');
      }
      buf.write('  }');
    } else {
      buf.write(jsonEncode(v));
    }
    buf.write(i == entries.length - 1 ? '\n' : ',\n');
  }
  buf.write('}\n');
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(buf.toString());
}

String _listJson(List items, String indent) {
  if (items.isEmpty) return '[]';
  return '[\n${items.map((e) => '$indent  ${jsonEncode(e)}').join(',\n')}\n$indent]';
}

String _readKey(String secretsPath) {
  final env = Platform.environment['TMDB_API_KEY'];
  if (env != null && env.isNotEmpty) return env;
  final f = File(secretsPath);
  if (!f.existsSync()) {
    stderr.writeln('No TMDB key: set TMDB_API_KEY or pass --secrets=<file>.');
    exit(1);
  }
  final key = (jsonDecode(f.readAsStringSync()) as Map)['TMDB_API_KEY'];
  if (key is! String || key.isEmpty) {
    stderr.writeln('$secretsPath has no TMDB_API_KEY.');
    exit(1);
  }
  return key;
}

// ------------------------------------------------------------------ TMDB ---

final _client = http.Client();

Future<Map<String, dynamic>> _get(String path, Map<String, String> params) async {
  final cacheName = '$path?${(params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map((e) => '${e.key}=${e.value}').join('&')}'
      .replaceAll(RegExp(r'[^A-Za-z0-9=&._-]'), '_');
  final cached = File('${_cache.path}/$cacheName.json');
  if (cached.existsSync()) {
    return jsonDecode(cached.readAsStringSync()) as Map<String, dynamic>;
  }
  final uri = Uri.https('api.themoviedb.org', '/3$path',
      {...params, 'api_key': _apiKey, 'language': 'en-US'});
  for (var attempt = 0;; attempt++) {
    final res = await _client.get(uri).timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) {
      cached.writeAsStringSync(res.body);
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if ((res.statusCode == 429 || res.statusCode >= 500) && attempt < 5) {
      await Future<void>.delayed(Duration(seconds: 1 << attempt));
      continue;
    }
    // Path only — the URI carries the key.
    throw HttpException('TMDB ${res.statusCode} for $path');
  }
}

Future<List<Map<String, dynamic>>> _discover(
    String path, int pages, Map<String, String> params) async {
  final results = List<List<Map<String, dynamic>>>.filled(pages, const []);
  await _parallel(List.generate(pages, (i) => i), (i) async {
    final data = await _get(path, {...params, 'page': '${i + 1}'});
    results[i] = ((data['results'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  });
  final seen = <Object?>{};
  return [
    for (final page in results)
      for (final m in page)
        if (seen.add(m['id'])) m,
  ];
}

Future<List<Map<String, dynamic>>> _detailsFor(
    List<Map<String, dynamic>> items,
    String Function(Object? id) path,
    Map<String, String> params) async {
  final out = List<Map<String, dynamic>?>.filled(items.length, null);
  await _parallel(List.generate(items.length, (i) => i), (i) async {
    out[i] = await _get(path(items[i]['id']), params);
  });
  return out.whereType<Map<String, dynamic>>().toList();
}

/// TMDB keyword names per title id (lower-case, e.g. "gotham city").
Future<Map<Object?, List<String>>> _keywordsFor(
    List<Map<String, dynamic>> details,
    {required bool isTv}) async {
  final out = <Object?, List<String>>{};
  await _parallel(details, (m) async {
    final id = m['id'];
    final data = await _get('/${isTv ? 'tv' : 'movie'}/$id/keywords', {});
    out[id] = [
      for (final k in ((data[isTv ? 'results' : 'keywords'] as List?) ??
          const []))
        ((k['name'] as String?) ?? '').toLowerCase(),
    ];
  });
  return out;
}

/// Every collection the movies belong to, with its parts' titles and the
/// top-billed character names of each part (credits fetched only for parts
/// that aren't already among [details]).
Future<Map<Object?, _Collection>> _collectionsFor(
    List<Map<String, dynamic>> details) async {
  final byId = {for (final m in details) m['id']: m};
  final ids = {
    for (final m in details)
      if (m['belongs_to_collection'] is Map) m['belongs_to_collection']['id'],
  }.toList();
  final out = <Object?, _Collection>{};
  await _parallel(ids, (cid) async {
    final data = await _get('/collection/$cid', {});
    final parts = <_CollectionPart>[];
    for (final p in ((data['parts'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()) {
      final pid = p['id'];
      final title = (p['title'] as String?) ?? '';
      if (title.isEmpty) continue;
      // Unreleased/announced parts have no credits worth fetching.
      final released = ((p['release_date'] as String?) ?? '').isNotEmpty;
      var cast = byId[pid]?['credits']?['cast'] as List?;
      if (cast == null && released) {
        cast = (await _get('/movie/$pid/credits', {}))['cast'] as List?;
      }
      final sorted = ((cast ?? const []).cast<Map<String, dynamic>>().toList()
        ..sort((a, b) => (a['order'] as num).compareTo(b['order'] as num)));
      parts.add(_CollectionPart(pid, title, [
        for (final c in sorted.take(15)) (c['character'] as String?) ?? '',
      ]));
    }
    out[cid] = _Collection((data['name'] as String?) ?? '', parts);
  });
  return out;
}

class _Collection {
  _Collection(this.name, this.parts);
  final String name;
  final List<_CollectionPart> parts;
}

class _CollectionPart {
  _CollectionPart(this.id, this.title, this.characters);
  final Object? id;
  final String title;
  final List<String> characters;
}

Future<void> _parallel<T>(List<T> jobs, Future<void> Function(T) worker,
    {int concurrency = 8}) async {
  var next = 0;
  await Future.wait(List.generate(concurrency, (_) async {
    while (next < jobs.length) {
      final job = jobs[next++];
      await worker(job);
    }
  }));
}
