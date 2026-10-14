import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/utils/avatar_image.dart';

void main() {
  test('data URIs round-trip to a MemoryImage with the same bytes', () {
    final bytes = Uint8List.fromList(List.generate(300, (i) => i % 256));
    final uri = avatarDataUri(bytes)!;
    expect(uri, startsWith('data:image/jpeg;base64,'));
    final provider = avatarImageProvider(uri);
    expect(provider, isA<MemoryImage>());
    expect((provider as MemoryImage).bytes, bytes);
    // Memoized: same bytes instance, so Flutter's image cache hits.
    expect((avatarImageProvider(uri) as MemoryImage).bytes,
        same(provider.bytes));
  });

  test('http URLs still load from the network; empty is null', () {
    expect(avatarImageProvider('https://example.com/a.jpg'),
        isA<NetworkImage>());
    expect(avatarImageProvider(''), isNull);
    expect(avatarImageProvider(null), isNull);
    expect(avatarImageProvider('data:image/jpeg;base64,@@not-base64@@'),
        isNull);
  });

  test('oversized photos are rejected', () {
    expect(avatarDataUri(Uint8List(avatarMaxBytes + 1)), isNull);
    expect(avatarDataUri(Uint8List(avatarMaxBytes)), isNotNull);
  });
}
