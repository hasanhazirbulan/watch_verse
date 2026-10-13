import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// One GIF result: a small preview (for the grid) + the URL we actually store
/// on the comment.
class GiphyGif {
  final String previewUrl;
  final String gifUrl;
  const GiphyGif({required this.previewUrl, required this.gifUrl});
}

/// Thin Giphy client for the in-app GIF picker.
///
/// Giphy requires an API key (the old public beta keys are now banned). Get a
/// free one at developers.giphy.com and supply it at build/run time via
/// `--dart-define-from-file=secrets.json` (see secrets.example.json). While
/// it's empty, GIF *search* is hidden and users attach GIFs via the "GIF by
/// link" option instead — no key needed for that.
class GiphyService {
  static const String _apiKey = String.fromEnvironment('GIPHY_API_KEY');
  static const String _base = 'https://api.giphy.com/v1/gifs';

  /// Whether GIF search is available (a key has been configured).
  static bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<GiphyGif>> trending({int offset = 0}) => _fetch('$_base/trending', {
        'limit': '24',
        'offset': '$offset',
        'rating': 'pg-13',
      });

  Future<List<GiphyGif>> search(String query, {int offset = 0}) {
    if (query.trim().isEmpty) return trending(offset: offset);
    return _fetch('$_base/search', {
      'q': query.trim(),
      'limit': '24',
      'offset': '$offset',
      'rating': 'pg-13',
      'lang': 'en',
    });
  }

  Future<List<GiphyGif>> _fetch(String url, Map<String, String> params) async {
    final uri = Uri.parse(url)
        .replace(queryParameters: {'api_key': _apiKey, ...params});
    // Same reasoning as APIservices._timeout: a request that never returns
    // would leave the GIF picker spinning forever instead of erroring.
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Giphy request failed (${res.statusCode})');
    }
    final data = (json.decode(res.body)['data'] as List<dynamic>? ?? []);
    return data
        .map((g) => _parse(g as Map<String, dynamic>))
        .where((g) => g.gifUrl.isNotEmpty)
        .toList();
  }

  GiphyGif _parse(Map<String, dynamic> g) {
    final images = (g['images'] as Map<String, dynamic>? ?? {});
    String pick(String key) =>
        ((images[key] as Map<String, dynamic>?)?['url'] ?? '') as String;
    final preview = [pick('fixed_width_small'), pick('fixed_width'), pick('downsized')]
        .firstWhere((u) => u.isNotEmpty, orElse: () => '');
    final gif = [pick('downsized'), pick('fixed_width'), pick('original')]
        .firstWhere((u) => u.isNotEmpty, orElse: () => '');
    return GiphyGif(previewUrl: preview.isEmpty ? gif : preview, gifUrl: gif);
  }
}
