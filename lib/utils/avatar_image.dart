import 'dart:convert';
import 'dart:typed_data';

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

/// `data:` URI for a JPEG avatar, or null when [bytes] is too large to keep
/// on the profile doc (it's copied onto comments and polls too).
String? avatarDataUri(Uint8List bytes) => bytes.length > avatarMaxBytes
    ? null
    : 'data:image/jpeg;base64,${base64Encode(bytes)}';
