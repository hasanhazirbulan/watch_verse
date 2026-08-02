import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/services/poll_service.dart';

void main() {
  group('ratingBucket', () {
    test('returns null for an unrated score so no vote is cast', () {
      expect(PollService.ratingBucket(0), isNull);
    });

    test('maps whole stars onto their own bucket', () {
      expect(PollService.ratingBucket(1), 'bad');
      expect(PollService.ratingBucket(2), 'ok');
      expect(PollService.ratingBucket(3), 'good');
      expect(PollService.ratingBucket(4), 'great');
      expect(PollService.ratingBucket(5), 'wow');
    });

    test('rounds half stars up to the better bucket', () {
      expect(PollService.ratingBucket(0.5), 'bad');
      expect(PollService.ratingBucket(1.5), 'ok');
      expect(PollService.ratingBucket(2.5), 'good');
      expect(PollService.ratingBucket(3.5), 'great');
      expect(PollService.ratingBucket(4.5), 'wow');
    });

    test('clamps an out-of-range score instead of throwing', () {
      expect(PollService.ratingBucket(9), 'wow');
    });
  });
}
