import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Profile photos are stored inline as a small JPEG `data:` URI in
/// `users/{uid}.photoURL` (the Firebase project is on the free Spark plan,
/// which can't create a Cloud Storage bucket). Older/external values may
/// still be http(s) URLs. This resolves either to an [ImageProvider].
///
/// Decoded `data:` bytes are memoized per URI so a list of 50 comments by
/// the same person decodes the base64 once and hits Flutter's image cache
/// (MemoryImage compares by bytes identity) instead of re-decoding.
const avatarMaxBytes = 60 * 1024;

final _decoded = <String, Uint8List>{};

ImageProvider? avatarImageProvider(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('data:')) {
    final bytes = _decoded[url] ?? _decode(url);
    if (bytes == null) return null;
    return MemoryImage(bytes);
  }
  return NetworkImage(url);
}

Uint8List? _decode(String url) {
  final comma = url.indexOf(',');
  if (comma < 0) return null;
  try {
    final bytes = base64Decode(url.substring(comma + 1));
    if (_decoded.length > 200) _decoded.clear();
    return _decoded[url] = bytes;
  } on FormatException {
    return null;
  }
}

/// `data:` URI for an avatar image, or null when [bytes] is too large to
/// keep on the profile doc (it's copied onto comments and polls too). The
/// MIME type is sniffed from the bytes (JPEG unless it's clearly PNG, GIF or
/// WebP).
String? avatarDataUri(Uint8List bytes) => bytes.length > avatarMaxBytes
    ? null
    : 'data:${avatarMimeType(bytes)};base64,${base64Encode(bytes)}';

String avatarMimeType(Uint8List b) {
  bool starts(List<int> sig, [int at = 0]) {
    if (b.length < at + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[at + i] != sig[i]) return false;
    }
    return true;
  }

  if (starts(const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (starts(const [0x47, 0x49, 0x46, 0x38])) return 'image/gif';
  if (starts(const [0x52, 0x49, 0x46, 0x46]) &&
      starts(const [0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

/// Side lengths (px) tried, largest first, when a picked photo is over
/// [avatarMaxBytes].
const _shrinkSides = [160, 128, 96, 64];

/// Returns [bytes] if they already fit in [maxBytes], else a smaller PNG
/// re-encode of the same picture (longest side stepped down until it fits),
/// or null if it can't be decoded or never fits.
///
/// Needed because image_picker on iOS only applies `imageQuality` to JPEGs:
/// a PNG (screenshot, saved/edited image) or GIF comes back at its original
/// encoding, merely resized to 192px — a photo-like 192px PNG is ~80–110 KB,
/// which used to fail with "photo is too large after compression". Flutter
/// can't encode JPEG, so the fallback is a smaller PNG (96px RGBA is at most
/// ~37 KB, so it always fits).
Future<Uint8List?> shrinkAvatar(Uint8List bytes,
    {int maxBytes = avatarMaxBytes}) async {
  if (bytes.length <= maxBytes) return bytes;
  final ui.ImageDescriptor descriptor;
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
  } catch (_) {
    return null;
  }
  try {
    final longest = math.max(descriptor.width, descriptor.height);
    if (longest <= 0) return null;
    for (final side in _shrinkSides) {
      final scale = math.min(1.0, side / longest);
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      if (data != null && data.lengthInBytes <= maxBytes) {
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      }
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    descriptor.dispose();
  }
}
