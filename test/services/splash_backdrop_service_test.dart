import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/splash_backdrop_service.dart';

void main() {
  test('bundled fallback never repeats the last shown poster', () {
    final random = Random(1);
    for (final last in SplashBackdropService.bundled) {
      for (var i = 0; i < 50; i++) {
        expect(SplashBackdropService.pickBundled(last, random), isNot(last));
      }
    }
  });

  test('bundled fallback eventually uses every poster', () {
    final random = Random(2);
    final seen = <String>{};
    String? last;
    for (var i = 0; i < 200; i++) {
      last = SplashBackdropService.pickBundled(last, random);
      seen.add(last);
    }
    expect(seen, SplashBackdropService.bundled.toSet());
  });
}
