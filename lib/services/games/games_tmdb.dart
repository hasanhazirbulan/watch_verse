import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/api_service.dart' show apiKey;
import 'package:watch_verse/services/games/frames_logic.dart';

/// Today's Frames puzzle, resolved from TMDB at runtime (the bundled pool
/// only stores ids).
class FramesPuzzle {
  final MediaItem item;
  final List<String> stills;
  const FramesPuzzle(this.item, this.stills);
}

/// The few TMDB calls the bundled-pool games need. Kept separate from
/// [APIservices] because they need raw fields it doesn't surface (image
/// metadata, popularity for ranking search results).
class GamesTmdb {
  GamesTmdb({http.Client? client, @visibleForTesting String? key})
    : _client = client ?? http.Client(),
      _key = key ?? apiKey;
  final http.Client _client;
  final String _key;

  static const _timeout = Duration(seconds: 15);

  /// Releases the HTTP client's connections.
  void close() => _client.close();

  Uri _uri(String path, Map<String, String> params) {
    if (_key.isEmpty) {
      throw StateError(
        'TMDB_API_KEY is not set. Run with '
        '--dart-define-from-file=secrets.json (see secrets.example.json).',
      );
    }
    return Uri.parse('https://api.themoviedb.org/3$path').replace(
      queryParameters: {'api_key': _key, 'language': 'en-US', ...params},
    );
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw Exception('TMDB request timed out (${uri.path})');
    }
    if (res.statusCode != 200) {
      throw Exception(
        'TMDB request failed (${res.statusCode}) for ${uri.path}',
      );
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  /// Details + language-neutral backdrops for [id] in one request.
  Future<FramesPuzzle> framesPuzzle(MediaType type, int id) async {
    final data = await _get(
      _uri('/${type.apiPath}/$id', {
        'append_to_response': 'images',
        'include_image_language': 'null',
      }),
    );
    final item = type == MediaType.movie
        ? MediaItem.fromMovieMap(data)
        : MediaItem.fromTvMap(data);
    final images = data['images'];
    final backdrops = images is Map
        ? (images['backdrops'] as List? ?? const [])
        : const [];
    final stills = pickFrameStills(backdrops);
    if (stills.isEmpty) {
      throw StateError('No usable stills for ${type.apiPath}/$id');
    }
    return FramesPuzzle(item, stills);
  }

  /// Title search restricted to [type], best-known first — the guess box
  /// should surface "The Thing (1982)" above a dozen obscure namesakes.
  /// Ranked by TMDB vote count, with an exact title match pulled to the top.
  Future<List<MediaItem>> search(
    MediaType type,
    String query, {
    int limit = 8,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final data = await _get(
      _uri('/search/${type.apiPath}', {'query': q, 'include_adult': 'false'}),
    );
    final raw = (data['results'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final lower = q.toLowerCase();
    int rank(Map<String, dynamic> m) {
      final title =
          ((type == MediaType.movie ? m['title'] : m['name']) as String? ?? '')
              .toLowerCase();
      final votes = (m['vote_count'] as num?)?.toInt() ?? 0;
      // Exact matches first, then by vote count.
      return (title == lower ? 1 << 30 : 0) + votes;
    }

    raw.sort((a, b) => rank(b).compareTo(rank(a)));
    return raw
        .map(
          (m) => type == MediaType.movie
              ? MediaItem.fromMovieMap(m)
              : MediaItem.fromTvMap(m),
        )
        .where((m) => m.id != 0 && m.title.isNotEmpty)
        .take(limit)
        .toList();
  }
}
