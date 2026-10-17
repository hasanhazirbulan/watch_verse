import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/app_firebase.dart';
import 'package:watch_verse/services/pro_entitlement.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/responsive.dart';

/// A window the app can be laid out in, with the safe-area insets iOS
/// reports for it (status bar / home indicator / side status bar).
class LayoutWindow {
  const LayoutWindow(this.name, this.size, this.padding);
  final String name;
  final Size size;
  final EdgeInsets padding;

  bool get isLandscape => size.width > size.height;

  @override
  String toString() =>
      '$name ${size.width.toInt()}x${size.height.toInt()}';
}

const iPhonePortrait =
    LayoutWindow('iPhone', Size(390, 844), EdgeInsets.only(top: 47, bottom: 34));
const duoOuter = LayoutWindow(
    'Duo outer', Size(466, 678), EdgeInsets.only(top: 44, bottom: 21));
const duoInner = LayoutWindow(
    'Duo inner', Size(669, 951), EdgeInsets.only(top: 44, bottom: 21));
// With the iOS 27.1 SDK the status bar can sit on a side edge in landscape.
const duoInnerLandscape = LayoutWindow('Duo inner landscape', Size(951, 669),
    EdgeInsets.only(left: 44, bottom: 21));
const iPhoneLandscape = LayoutWindow('iPhone landscape', Size(852, 393),
    EdgeInsets.only(left: 59, right: 59, bottom: 21));

const allWindows = [
  iPhonePortrait,
  duoOuter,
  duoInner,
  duoInnerLandscape,
  iPhoneLandscape,
];

void useWindow(WidgetTester tester, LayoutWindow window) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = window.size;
  tester.view.padding = FakeViewPadding(
    left: window.padding.left,
    top: window.padding.top,
    right: window.padding.right,
    bottom: window.padding.bottom,
  );
  tester.view.viewPadding = FakeViewPadding(
    left: window.padding.left,
    top: window.padding.top,
    right: window.padding.right,
    bottom: window.padding.bottom,
  );
  addTearDown(tester.view.reset);
}

const myUid = 'me';
const friendUid = 'friend1';

late FakeFirebaseFirestore fakeDb;

/// Points every screen/service at an in-memory Firestore + a signed-in mock
/// user, and TMDB at [fakeTmdbClient]. Call from `setUpAll` — the service
/// singletons bind to whatever [AppFirebase] returns the first time they're
/// touched.
Future<void> installFakeBackend() async {
  SharedPreferences.setMockInitialValues({});
  fakeDb = FakeFirebaseFirestore();
  AppFirebase.firestoreOverride = fakeDb;
  AppFirebase.authOverride = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(
      uid: myUid,
      email: 'alex@example.com',
      displayName: 'Alex Morgan',
    ),
  );
  APIservices.keyOverride = 'test';
  // InAppPurchase registers (and connects) the real store plugin on first
  // use for Android/iOS; create it as a platform with no store plugin, then
  // install the fake.
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  InAppPurchase.instance.toString();
  debugDefaultTargetPlatformOverride = null;
  InAppPurchasePlatform.instance = _FakeStore();
  PackageInfo.setMockInitialValues(
    appName: 'WatchVerse',
    packageName: 'com.watchverse.app',
    version: '1.0.1',
    buildNumber: '26',
    buildSignature: '',
  );
  await _seed(fakeDb);
}

/// StoreKit stand-in: the four subscriptions, nothing purchased.
class _FakeStore extends InAppPurchasePlatform {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
          Set<String> identifiers) async =>
      ProductDetailsResponse(
        productDetails: [
          for (final (id, title, price, raw) in [
            (proMonthlyProductId, 'Pro Monthly', '\$2.99', 2.99),
            (proYearlyProductId, 'Pro Yearly', '\$19.99', 19.99),
            (patronMonthlyProductId, 'Patron Monthly', '\$5.99', 5.99),
            (patronYearlyProductId, 'Patron Yearly', '\$49.99', 49.99),
          ])
            if (identifiers.contains(id))
              ProductDetails(
                id: id,
                title: title,
                description: title,
                price: price,
                rawPrice: raw,
                currencyCode: 'USD',
                currencySymbol: '\$',
              ),
        ],
        notFoundIDs: const [],
      );
}

Future<void> _seed(FakeFirebaseFirestore db) async {
  final now = DateTime(2026, 10, 15, 20);
  final me = db.collection('users').doc(myUid);
  await me.set({
    'name': 'Alex Morgan',
    'characterQuote': 'Here\'s looking at you, kid.',
    'avatarBg': 2,
    'following': [friendUid],
    'followers': [friendUid, 'friend2'],
    'timeStatsBackfilledV2': true,
  });
  await db.collection('users').doc(friendUid).set({
    'name': 'Sam Rivera',
    'following': [myUid],
    'followers': [myUid],
  });
  for (var i = 0; i < 9; i++) {
    final id = 101 + i;
    final watched = i.isEven;
    await me.collection('movies').doc('$id').set({
      'id': id,
      'title': movieTitle(id),
      'posterPath': '',
      'backdropPath': '',
      'releaseDate': i == 1 ? '2026-12-18' : '201${i % 10}-05-0${1 + i % 8}',
      'voteAverage': 7.1 + i / 10,
      'status': watched ? 'watched' : 'watchlist',
      'favorite': i < 3,
      if (i < 3) 'showcaseSlot': i,
      if (watched) 'rating': 3.5 + (i % 3) / 2,
      if (watched) 'watchedAt': Timestamp.fromDate(now.subtract(Duration(days: i))),
      'runtime': 100 + i * 7,
      'genres': ['Drama', 'Science Fiction'],
    });
    if (watched) {
      await me.collection('activity').doc('movie-$id').set({
        'kind': 'movie',
        'ref': 'movie-$id',
        'movieId': id,
        'title': movieTitle(id),
        'posterPath': '',
        'rating': 4,
        'runtime': 110,
        'at': Timestamp.fromDate(now.subtract(Duration(days: i))),
      });
    }
  }
  for (var i = 0; i < 4; i++) {
    final id = 201 + i;
    final show = me.collection('shows').doc('$id');
    await show.set({
      'id': id,
      'name': showTitle(id),
      'posterPath': '',
      'backdropPath': '',
      'firstAirDate': '2022-02-18',
      'voteAverage': 8.2,
      'totalEpisodes': 10,
      'totalSeasons': 1,
      'status': i == 3 ? 'watchlist' : 'watching',
      'favorite': i == 0,
      'watchedCount': i == 3 ? 0 : 3,
      'watchedMinutes': 150,
      'updatedAt': Timestamp.fromDate(now.subtract(Duration(days: i))),
    });
    if (i == 3) continue;
    for (var e = 1; e <= 3; e++) {
      await show.collection('watched').doc('s1e$e').set({
        'watchedAt': Timestamp.fromDate(now.subtract(Duration(days: 30 + e))),
      });
      await me.collection('activity').doc('ep-$id-$e').set({
        'kind': 'episode',
        'ref': 'tv-$id-s1e$e',
        'showId': id,
        'showName': showTitle(id),
        'season': 1,
        'episode': e,
        'posterPath': '',
        'at': Timestamp.fromDate(now.subtract(Duration(days: 10 + e))),
      });
    }
  }
}

String movieTitle(int id) => switch (id % 4) {
      0 => 'Movie $id',
      1 => 'The Remarkably Long Title of Film Number $id',
      2 => 'Film $id: Part Two',
      _ => 'Night $id',
    };

String showTitle(int id) => switch (id % 3) {
      0 => 'Show $id',
      1 => 'An Extremely Long Television Show Name $id',
      _ => 'Series $id',
    };

const _overview =
    'A gifted but restless cartographer is hired to map a city that redraws '
    'itself every night. As the streets shift, she starts to suspect the '
    'changes follow her own memories — and that someone else is using the '
    'map to find her first.';

Map<String, dynamic> _movieJson(int id) => {
      'id': id,
      'title': movieTitle(id),
      'overview': _overview,
      'poster_path': null,
      'backdrop_path': null,
      'release_date': '2024-03-0${1 + id % 8}',
      'vote_average': 6.5 + (id % 30) / 10,
      'media_type': 'movie',
    };

Map<String, dynamic> _tvJson(int id) => {
      'id': id,
      'name': showTitle(id),
      'overview': _overview,
      'poster_path': null,
      'backdrop_path': null,
      'first_air_date': '2022-02-18',
      'vote_average': 8.1,
      'media_type': 'tv',
    };

Map<String, dynamic> _episodeJson(int show, int s, int e, String airDate) => {
      'id': show * 1000 + s * 100 + e,
      'episode_number': e,
      'season_number': s,
      'name': e.isEven ? 'Episode $e' : 'The One Where Everything Changes $e',
      'overview': _overview,
      'still_path': null,
      'air_date': airDate,
      'vote_average': 7.9,
      'runtime': 52,
    };

/// A fake TMDB that answers every endpoint the screens call with plausible
/// data (no image paths, so images render their placeholders offline).
http.Client fakeTmdbClient() => MockClient((request) async {
      final path = request.url.path.replaceFirst('/3', '');
      Object body = const <String, dynamic>{};
      final segs = path.split('/').where((s) => s.isNotEmpty).toList();
      bool isTv() => segs.contains('tv');
      List<Map<String, dynamic>> list(int base) => [
            for (var i = 0; i < 12; i++)
              isTv() ? _tvJson(base + i) : _movieJson(base + i)
          ];

      if (path.endsWith('/credits')) {
        body = {
          'cast': [
            for (var i = 1; i <= 10; i++)
              {
                'id': 900 + i,
                'name': i.isEven ? 'Actor $i' : 'Performer With Long Name $i',
                'character': 'Character $i',
                'profile_path': null,
              }
          ]
        };
      } else if (path.endsWith('/videos')) {
        body = {
          'results': [
            {'site': 'YouTube', 'key': 'abc', 'type': 'Trailer'}
          ]
        };
      } else if (path.endsWith('/reviews')) {
        body = {
          'results': [
            {
              'author': 'critic',
              'content': _overview * 2,
              'author_details': {'rating': 8}
            }
          ]
        };
      } else if (path.contains('/watch/providers')) {
        body = {'results': <String, dynamic>{}};
      } else if (path.startsWith('/genre/')) {
        body = {
          'genres': [
            for (final (i, g) in [
              'Action',
              'Comedy',
              'Drama',
              'Science Fiction',
              'Documentary',
              'Animation',
              'Thriller'
            ].indexed)
              {'id': i + 1, 'name': g}
          ]
        };
      } else if (RegExp(r'^/tv/\d+/season/\d+$').hasMatch(path)) {
        final show = int.parse(segs[1]);
        final s = int.parse(segs[3]);
        body = {
          'episodes': [
            for (var e = 1; e <= 10; e++)
              _episodeJson(show, s, e,
                  e <= 8 ? '2025-0${1 + e % 9}-1$e' : '2026-11-2$e'),
          ]
        };
      } else if (RegExp(r'^/tv/\d+$').hasMatch(path)) {
        final id = int.parse(segs[1]);
        body = {
          ..._tvJson(id),
          'last_air_date': '2025-03-01',
          'number_of_seasons': 2,
          'number_of_episodes': 20,
          'status': 'Returning Series',
          'genres': [
            {'id': 1, 'name': 'Drama'},
            {'id': 2, 'name': 'Mystery'},
          ],
          'seasons': [
            for (var s = 1; s <= 2; s++)
              {
                'season_number': s,
                'name': 'Season $s',
                'episode_count': 10,
                'poster_path': null,
                'air_date': '202$s-02-18',
                'overview': '',
              }
          ],
          'next_episode_to_air': _episodeJson(id, 2, 9, '2026-11-02'),
        };
      } else if (RegExp(r'^/movie/\d+$').hasMatch(path)) {
        final id = int.parse(segs[1]);
        body = {
          ..._movieJson(id),
          'runtime': 128,
          'genres': [
            {'id': 3, 'name': 'Drama'},
            {'id': 4, 'name': 'Science Fiction'},
          ],
        };
      } else if (RegExp(r'^/person/\d+$').hasMatch(path)) {
        body = {
          'id': int.parse(segs[1]),
          'name': 'Performer With Long Name',
          'biography': _overview * 2,
          'profile_path': null,
          'known_for_department': 'Acting',
        };
      } else if (path.endsWith('/combined_credits')) {
        body = {'cast': list(300)};
      } else if (segs.isNotEmpty) {
        // Every list endpoint: now_playing, trending, popular, top_rated,
        // discover, airing_today, on_the_air, recommendations, search.
        body = {'results': list(path.hashCode.abs() % 500 + 300)};
      }
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json'});
    });

Widget testApp(Widget home, {GlobalKey? boundaryKey}) => RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            SideSafeArea(color: AppColors.dark.background, child: child!),
        home: home,
      ),
    );

/// Bounded settle: skeletons/spinners animate forever, so pumpAndSettle
/// would never return.
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Runs [body] with every `http` call going to [fakeTmdbClient].
Future<T> withFakeTmdb<T>(Future<T> Function() body) =>
    http.runWithClient(body, fakeTmdbClient);

// ------------------------------------------------------------- rendering --

/// Loads Roboto + Material Icons under the family names the iOS typography
/// asks for, so rendered PNGs show real text instead of test-font boxes.
Future<void> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent
          .parent.path;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  Future<ByteData> read(String f) async =>
      ByteData.view(File('${dir.path}/$f').readAsBytesSync().buffer);
  const faces = [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
    'Roboto-Italic.ttf',
  ];
  for (final family in [
    'Roboto',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    '.SF Pro Text',
    '.SF Pro Display',
    '.SF UI Text',
    '.SF UI Display',
    // Styles with no family (e.g. the app-bar title) use the test default.
    'FlutterTest',
  ]) {
    final loader = FontLoader(family);
    for (final f in faces) {
      loader.addFont(read(f));
    }
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('MaterialIcons-Regular.otf'));
  await icons.load();
}

/// Writes what's inside [boundaryKey] to [path] as a PNG.
Future<void> capturePng(
    WidgetTester tester, GlobalKey boundaryKey, String path) async {
  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path)..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
