import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

/// Picks a different poster for the splash screen on every launch.
///
/// The splash only shows for ~2.5 s, too short to fetch an image over the
/// network, so posters are downloaded ahead of time: each launch shows one
/// that is already in the image disk cache, then [refreshInBackground]
/// refreshes the list (this week's trending movies + shows on TMDB) and
/// downloads a few for next time. First launch, or nothing cached yet, falls
/// back to one of the bundled posters.
class SplashBackdropService {
  SplashBackdropService._();
  static final SplashBackdropService instance = SplashBackdropService._();

  static const bundled = [
    'assets/images/thebear.jpg',
    'assets/images/gladiator2.jpg',
    'assets/images/heretic.jpg',
    'assets/images/thewildrobot.jpg',
  ];

  static const _urlsKey = 'splash_poster_urls';
  static const _lastShownKey = 'splash_last_shown';
  static const _refreshedAtKey = 'splash_refreshed_at';
  static const _refreshEvery = Duration(hours: 12);
  static const _keep = 16;
  static const _prefetchPerLaunch = 4;

  final _random = Random();

  /// Poster for this launch: a cached trending poster when one is on disk,
  /// otherwise a bundled one. Never the same as last launch when there's a
  /// choice. Never throws.
  Future<ImageProvider> pickForLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(_lastShownKey);
      final urls = (prefs.getStringList(_urlsKey) ?? const <String>[])
          .where((u) => u != last)
          .toList()
        ..shuffle(_random);
      for (final url in urls) {
        final cached = await DefaultCacheManager().getFileFromCache(url);
        if (cached != null) {
          await prefs.setString(_lastShownKey, url);
          return FileImage(cached.file);
        }
      }
      final asset = pickBundled(last, _random);
      await prefs.setString(_lastShownKey, asset);
      return AssetImage(asset);
    } catch (e) {
      debugPrint('SplashBackdrop: pick failed: $e');
      return AssetImage(bundled[_random.nextInt(bundled.length)]);
    }
  }

  @visibleForTesting
  static String pickBundled(String? last, Random random) {
    final options = bundled.where((a) => a != last).toList();
    return options[random.nextInt(options.length)];
  }

  /// Refreshes the trending list at most every [_refreshEvery] and makes sure
  /// a few posters are downloaded for upcoming launches. Fire-and-forget;
  /// failures (offline, TMDB down) are logged and ignored.
  Future<void> refreshInBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var urls = prefs.getStringList(_urlsKey) ?? const <String>[];
      final refreshedAt = DateTime.fromMillisecondsSinceEpoch(
          prefs.getInt(_refreshedAtKey) ?? 0);
      if (urls.isEmpty ||
          DateTime.now().difference(refreshedAt) > _refreshEvery) {
        final api = APIservices();
        final results = await Future.wait([
          api.getTrendingMovies(),
          api.getTrendingTv(),
        ]);
        final fresh = results
            .expand((list) => list)
            .map((m) => Tmdb.poster(m.posterPath, size: 'w780'))
            .whereType<String>()
            .toSet()
            .toList()
          ..shuffle(_random);
        if (fresh.isNotEmpty) {
          urls = fresh.take(_keep).toList();
          await prefs.setStringList(_urlsKey, urls);
          await prefs.setInt(
              _refreshedAtKey, DateTime.now().millisecondsSinceEpoch);
        }
      }
      var downloaded = 0;
      for (final url in urls) {
        if (downloaded >= _prefetchPerLaunch) break;
        if (await DefaultCacheManager().getFileFromCache(url) != null) {
          continue;
        }
        await DefaultCacheManager().downloadFile(url);
        downloaded++;
      }
    } catch (e) {
      debugPrint('SplashBackdrop: refresh failed: $e');
    }
  }
}
