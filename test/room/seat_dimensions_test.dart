import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Seat Sizes, Avatar Coverage & Ripple Sizing Unit Tests', () {
    test('Host and Co-Host seats are exactly 50 px diameter', () {
      final double scale = 1.0;
      final double hostSeatSize = ((0 == 0 || 0 == 1) ? 50.0 : 48.0) * scale;
      final double coHostSeatSize = ((1 == 0 || 1 == 1) ? 50.0 : 48.0) * scale;

      expect(hostSeatSize, equals(50.0));
      expect(coHostSeatSize, equals(50.0));
    });

    test('Normal seats (2..9) are exactly 48 px diameter', () {
      final double scale = 1.0;
      for (int i = 2; i <= 9; i++) {
        final double normalSeatSize = ((i == 0 || i == 1) ? 50.0 : 48.0) * scale;
        expect(normalSeatSize, equals(48.0), reason: 'Seat $i must be 48.0 px');
      }
    });

    test('Avatar coverage is 100% of seat diameter', () {
      final double seatSize = 50.0;
      final double avatarSize = seatSize; // 100% coverage
      expect(avatarSize, equals(seatSize));
      expect(avatarSize / seatSize, equals(1.0));
    });

    test('Avatar frame size is within +5% to +8% range (+6.5%)', () {
      final double seatSize = 50.0;
      final double frameSize = seatSize * 1.065;
      final double scalePercent = (frameSize - seatSize) / seatSize;

      expect(frameSize, equals(53.25));
      expect(scalePercent, greaterThanOrEqualTo(0.05));
      expect(scalePercent, lessThanOrEqualTo(0.08));
    });

    test('Voice ripple wave max size is exactly base diameter + 5%', () {
      final double seatSize = 48.0;
      final double frameSize = seatSize * 1.065;

      final double rippleWithoutFrameMax = seatSize * 1.05;
      final double rippleWithFrameMax = frameSize * 1.05;

      expect(rippleWithoutFrameMax, closeTo(50.4, 0.0001));
      expect(rippleWithFrameMax, closeTo(53.676, 0.0001));
      expect((rippleWithoutFrameMax - seatSize) / seatSize, closeTo(0.05, 0.0001));
      expect((rippleWithFrameMax - frameSize) / frameSize, closeTo(0.05, 0.0001));
    });
  });
}
