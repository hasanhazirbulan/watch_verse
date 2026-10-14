import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/daily_game_clues.dart';

void main() {
  group('dailyGameHintsUnlocked', () {
    test('no hints before the 5th guess', () {
      for (var n = 0; n < 5; n++) {
        expect(dailyGameHintsUnlocked(n), 0, reason: 'guess count $n');
      }
    });

    test('first hint stays unlocked after guess 5 (not only at exactly 5)', () {
      for (var n = 5; n < 8; n++) {
        expect(dailyGameHintsUnlocked(n), 1, reason: 'guess count $n');
      }
    });

    test('both hints unlocked from guess 8 on', () {
      for (var n = 8; n <= 10; n++) {
        expect(dailyGameHintsUnlocked(n), 2, reason: 'guess count $n');
      }
    });
  });
}
