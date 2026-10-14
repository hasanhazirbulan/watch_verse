// On-device smoke test for the games that need an account (Daily Movie,
// Plot, Who's the Actor?): creates a throwaway Firebase Auth user, plays one
// guess in each against real Firestore + TMDB, then deletes the user's
// gamePlays docs and the account. Run on a simulator:
//   flutter test integration_test/signed_in_games_smoke_test.dart \
//     --dart-define-from-file=secrets.json -d <simulator-id>
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:watch_verse/firebase_options.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/actor_guess_screen.dart';
import 'package:watch_verse/screens/daily_game_screen.dart';
import 'package:watch_verse/screens/games/plot_guess_screen.dart';
import 'package:watch_verse/screens/public_profile_screen.dart';
import 'package:watch_verse/utils/avatar_image.dart';
import 'package:watch_verse/widgets/social_widgets.dart';
import 'dart:convert';
import 'package:watch_verse/screens/streaming_services_screen.dart';
import 'package:watch_verse/screens/year_in_review_screen.dart';
import 'package:watch_verse/theme/app_theme.dart';

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    );

Future<void> _wait(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void _dumpTexts(String label) {
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? '')
      .where((t) => t.trim().isNotEmpty)
      .take(30)
      .toList();
  debugPrint('SMOKE[$label] texts: $texts');
}

/// Types [query] into the screen's search field and taps the first result.
Future<void> _guess(WidgetTester tester, String label, String query) async {
  final field = find.byType(TextField);
  expect(field, findsWidgets, reason: '$label has no search field');
  await tester.enterText(field.first, query);
  await _wait(tester, 5);
  _dumpTexts('$label-results');
  final results = find.byType(ListTile);
  if (results.evaluate().isEmpty) {
    debugPrint('SMOKE[$label] no ListTile results to tap');
    return;
  }
  await tester.tap(results.first, warnIfMissed: false);
  await _wait(tester, 6);
  _dumpTexts('$label-after-guess');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  User? user;

  setUpAll(() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'smoke-$stamp@example.com', password: 'smoke-$stamp-pw');
    user = cred.user;
    debugPrint('SMOKE created temp user ${user?.uid}');
  });

  tearDownAll(() async {
    final u = user;
    if (u == null) return;
    final plays = await FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .collection('gamePlays')
        .get();
    for (final d in plays.docs) {
      await d.reference.delete();
    }
    // The streaming test writes prefs onto users/{uid}; remove the doc too.
    await FirebaseFirestore.instance.collection('users').doc(u.uid).delete();
    await u.delete();
    debugPrint('SMOKE cleaned up ${plays.size} gamePlays doc(s) + profile doc + user');
  });

  testWidgets('Daily movie game loads and accepts a guess', (tester) async {
    await tester.pumpWidget(_app(const DailyGameScreen()));
    await _wait(tester, 8);
    // First visit opens the how-to sheet; close it.
    final gotIt = find.text('Got it');
    if (gotIt.evaluate().isNotEmpty) {
      await tester.tap(gotIt.first);
      await _wait(tester, 2);
    }
    _dumpTexts('daily');
    await _guess(tester, 'daily', 'Inception');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Plot game loads and accepts a guess', (tester) async {
    await tester.pumpWidget(_app(const PlotGuessScreen()));
    await _wait(tester, 6);
    _dumpTexts('plot');
    await _guess(tester, 'plot', 'Titanic');
    expect(tester.takeException(), isNull);
  });

  testWidgets("Who's the Actor? loads and accepts a guess", (tester) async {
    await tester.pumpWidget(_app(const ActorGuessScreen()));
    await _wait(tester, 6);
    _dumpTexts('actor');
    await _guess(tester, 'actor', 'Tom Hanks');
    expect(tester.takeException(), isNull);
  });

  testWidgets('My streaming services loads regions + providers live',
      (tester) async {
    await tester.pumpWidget(_app(const StreamingServicesScreen()));
    await _wait(tester, 10);
    _dumpTexts('streaming');
    expect(tester.takeException(), isNull);
    final boxes = find.byType(CheckboxListTile);
    debugPrint('SMOKE[streaming] provider rows: ${boxes.evaluate().length}');
    if (boxes.evaluate().isNotEmpty) {
      await tester.tap(boxes.first);
      await _wait(tester, 3);
      _dumpTexts('streaming-after-pick');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Year in Review opens for an account with no history',
      (tester) async {
    await tester.pumpWidget(_app(const YearInReviewScreen()));
    await _wait(tester, 8);
    _dumpTexts('yir');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inline profile photo saves to Firestore and renders',
      (tester) async {
    final u = FirebaseAuth.instance.currentUser!;
    // 48px JPEG made with: sips -s format jpeg -Z 48 assets/images/logoW.png
    final jpeg = base64Decode(
        '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');
    final uri = avatarDataUri(jpeg)!;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .set({'name': 'Smoke', 'photoURL': uri}, SetOptions(merge: true));
    final back = (await FirebaseFirestore.instance
            .collection('users')
            .doc(u.uid)
            .get())
        .data()!['photoURL'];
    expect(back, uri);
    await tester.pumpWidget(_app(PublicProfileScreen(userId: u.uid, name: 'Smoke')));
    await _wait(tester, 5);
    final avatars = find.byType(UserAvatar);
    debugPrint('SMOKE[avatar] UserAvatar widgets: ${avatars.evaluate().length}');
    expect(avatars, findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
