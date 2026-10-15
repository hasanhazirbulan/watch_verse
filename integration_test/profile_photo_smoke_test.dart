// On-device smoke test for profile photos (inline `data:` URI on
// users/{uid}, no Cloud Storage): creates a throwaway Firebase Auth user,
// sets a photo through ProfilePhotoService (the Edit Profile path), reads it
// back from Firestore and renders it, does the same for a large PNG (what
// image_picker returns on iOS for screenshots/PNGs — never compressed),
// removes the photo, then deletes the account. Run on a simulator:
//   flutter test integration_test/profile_photo_smoke_test.dart \
//     --dart-define-from-file=secrets.json -d <simulator-id>
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:watch_verse/firebase_options.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/public_profile_screen.dart';
import 'package:watch_verse/services/account_deletion_service.dart';
import 'package:watch_verse/services/profile_photo_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/avatar_image.dart';
import 'package:watch_verse/widgets/social_widgets.dart';

// 48px JPEG made with: sips -s format jpeg -Z 48 assets/images/logoW.png
const _jpegB64 =
    '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';

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

/// A 192×192 PNG of photo-like noise — what image_picker hands back on iOS
/// for a PNG at `maxWidth: 192` (imageQuality is ignored for PNGs).
Future<Uint8List> _noisyPng() async {
  const side = 192;
  final rnd = Random(7);
  final pixels = Uint8List(side * side * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = rnd.nextInt(256);
    pixels[i + 1] = rnd.nextInt(256);
    pixels[i + 2] = rnd.nextInt(256);
    pixels[i + 3] = 255;
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(buffer,
      width: side, height: side, pixelFormat: ui.PixelFormat.rgba8888);
  final codec = await descriptor.instantiateCodec();
  final image = (await codec.getNextFrame()).image;
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  User? user;
  late String email;
  late String password;
  late DocumentReference<Map<String, dynamic>> userRef;

  setUpAll(() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    email = 'smoke-photo-$stamp@example.com';
    password = 'smoke-$stamp-pw';
    final cred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    user = cred.user;
    userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    await userRef.set({'name': 'Photo Smoke'});
    debugPrint('SMOKE created temp user ${user?.uid} ($email)');
  });

  tearDownAll(() async {
    if (user == null) return;
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    await AccountDeletionService.instance.deleteAccount();
    debugPrint('SMOKE deleted temp user via AccountDeletionService');
  });

  Future<String?> storedPhoto() async =>
      (await userRef.get(const GetOptions(source: Source.server)))
          .data()?['photoURL'] as String?;

  testWidgets('JPEG photo is stored inline, read back and rendered',
      (tester) async {
    final jpeg = base64Decode(_jpegB64);
    final url = (await tester
        .runAsync(() => ProfilePhotoService.instance.setPhoto(jpeg)))!;
    expect(url, startsWith('data:image/jpeg;base64,'));

    final back = await storedPhoto();
    expect(back, url);
    final bytes = base64Decode(back!.substring(back.indexOf(',') + 1));
    expect(bytes, jpeg, reason: 'a small JPEG is stored untouched');
    expect(bytes.length, lessThanOrEqualTo(avatarMaxBytes));
    debugPrint('SMOKE[photo] jpeg ${bytes.length} B, '
        'field ${back.length} chars');

    await tester.pumpWidget(
        _app(PublicProfileScreen(userId: user!.uid, name: 'Photo Smoke')));
    await _wait(tester, 5);
    final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar).first);
    expect(avatar.photoURL, url);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a large PNG (iOS picker output) is shrunk to fit',
      (tester) async {
    final png = (await tester.runAsync(_noisyPng))!;
    debugPrint('SMOKE[photo] picked PNG ${png.length} B '
        '(limit $avatarMaxBytes B)');
    expect(png.length, greaterThan(avatarMaxBytes),
        reason: 'the case that used to fail as "too large"');

    final url = (await tester
        .runAsync(() => ProfilePhotoService.instance.setPhoto(png)))!;
    expect(url, startsWith('data:image/png;base64,'));
    final back = await storedPhoto();
    expect(back, url);
    final bytes = base64Decode(back!.substring(back.indexOf(',') + 1));
    expect(bytes.length, lessThanOrEqualTo(avatarMaxBytes));

    final size = (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      return Size(image.width.toDouble(), image.height.toDouble());
    }))!;
    debugPrint('SMOKE[photo] stored PNG ${bytes.length} B, $size');
    expect(size.width, size.height);
    expect(size.width, lessThan(192));

    await tester.pumpWidget(
        _app(PublicProfileScreen(userId: user!.uid, name: 'Photo Smoke')));
    await _wait(tester, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing the photo clears it', (tester) async {
    await tester.runAsync(() => ProfilePhotoService.instance.removePhoto());
    final data =
        (await userRef.get(const GetOptions(source: Source.server))).data()!;
    expect(data.containsKey('photoURL'), isFalse);
    expect(data['name'], 'Photo Smoke', reason: 'rest of the profile kept');

    await tester.pumpWidget(
        _app(PublicProfileScreen(userId: user!.uid, name: 'Photo Smoke')));
    await _wait(tester, 5);
    final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar).first);
    expect(avatar.photoURL, anyOf(isNull, isEmpty));
    expect(tester.takeException(), isNull);
  });
}
