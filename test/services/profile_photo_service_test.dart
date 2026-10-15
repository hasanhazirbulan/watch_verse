import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/profile_photo_service.dart';
import 'package:watch_verse/utils/avatar_image.dart';

/// A [width]×[height] PNG of noise — compresses badly, like a photo.
Future<Uint8List> noisyPng(int width, int height) async {
  final rnd = Random(1);
  final pixels = Uint8List(width * height * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = rnd.nextInt(256);
    pixels[i + 1] = rnd.nextInt(256);
    pixels[i + 2] = rnd.nextInt(256);
    pixels[i + 3] = 255;
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(buffer,
      width: width, height: height, pixelFormat: ui.PixelFormat.rgba8888);
  final image =
      (await (await descriptor.instantiateCodec()).getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<ui.Image> decode(Uint8List bytes) async =>
    (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;

Uint8List payload(String dataUri) =>
    base64Decode(dataUri.substring(dataUri.indexOf(',') + 1));

void main() {
  const uid = 'u1';
  late FakeFirebaseFirestore db;
  late ProfilePhotoService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = ProfilePhotoService(
      firestore: db,
      auth: MockFirebaseAuth(mockUser: MockUser(uid: uid), signedIn: true),
    );
  });

  Future<Map<String, dynamic>?> profile() async =>
      (await db.collection('users').doc(uid).get()).data();

  testWidgets('a small JPEG is stored as-is on users/{uid}', (tester) async {
    await tester.runAsync(() async {
      await db.collection('users').doc(uid).set({'name': 'Ann'});
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
      final url = await service.setPhoto(jpeg);
      expect(url, 'data:image/jpeg;base64,${base64Encode(jpeg)}');
      expect(await profile(), {'name': 'Ann', 'photoURL': url});
    });
  });

  testWidgets(
      'a PNG over the limit (iOS picker ignores imageQuality for PNG) is '
      'shrunk instead of rejected', (tester) async {
    await tester.runAsync(() async {
      final big = await noisyPng(192, 192);
      expect(big.length, greaterThan(avatarMaxBytes));
      final url = await service.setPhoto(big);
      expect(url, startsWith('data:image/png;base64,'));
      final stored = payload((await profile())!['photoURL'] as String);
      expect(stored.length, lessThanOrEqualTo(avatarMaxBytes));
      final img = await decode(stored);
      expect(img.width, img.height);
      expect(img.width, lessThan(192));
    });
  });

  testWidgets('shrinking keeps the aspect ratio', (tester) async {
    await tester.runAsync(() async {
      final wide = await noisyPng(192, 96);
      final small = (await shrinkAvatar(wide, maxBytes: 20 * 1024))!;
      expect(small.length, lessThanOrEqualTo(20 * 1024));
      final img = await decode(small);
      expect(img.width, img.height * 2);
    });
  });

  testWidgets('undecodable oversized bytes are refused, nothing written',
      (tester) async {
    await tester.runAsync(() async {
      await expectLater(service.setPhoto(Uint8List(avatarMaxBytes + 1)),
          throwsA(isA<ProfilePhotoTooLargeException>()));
      expect(await profile(), isNull);
    });
  });

  test('removePhoto deletes only the photo field', () async {
    await db
        .collection('users')
        .doc(uid)
        .set({'name': 'Ann', 'photoURL': 'data:image/jpeg;base64,AA=='});
    await service.removePhoto();
    expect(await profile(), {'name': 'Ann'});
  });

  test('guests are refused', () async {
    final guest = ProfilePhotoService(firestore: db, auth: MockFirebaseAuth());
    expect(() => guest.setPhoto(Uint8List(4)), throwsStateError);
    expect(() => guest.removePhoto(), throwsStateError);
  });

  test('data URI MIME type follows the bytes', () {
    expect(avatarMimeType(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0])),
        'image/png');
    expect(avatarMimeType(Uint8List.fromList(utf8.encode('GIF89a'))),
        'image/gif');
    expect(
        avatarMimeType(Uint8List.fromList(utf8.encode('RIFF\x00\x00\x00\x00WEBPVP8'))),
        'image/webp');
    expect(avatarMimeType(Uint8List.fromList([0xFF, 0xD8, 0xFF])),
        'image/jpeg');
  });
}
