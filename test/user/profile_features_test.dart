import 'package:flutter_test/flutter_test.dart';

String formatCount(num count) {
  if (count >= 1000000) {
    double value = count / 1000000;
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1) + 'M';
  } else if (count >= 1000) {
    double value = count / 1000;
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1) + 'K';
  }
  return count.toString();
}

String getFollowStateLabel(bool isFollowed, bool isFollower) {
  if (isFollowed && isFollower) {
    return 'Mutual';
  } else if (isFollowed) {
    return 'Following';
  } else if (isFollower) {
    return 'Follow Back';
  }
  return 'Follow';
}

void main() {
  group('Profile Features Unit Tests', () {
    test('Count Formatting Range Tests', () {
      expect(formatCount(0), '0');
      expect(formatCount(150), '150');
      expect(formatCount(999), '999');
      expect(formatCount(1000), '1K');
      expect(formatCount(1500), '1.5K');
      expect(formatCount(12345), '12.3K');
      expect(formatCount(100000), '100K');
      expect(formatCount(1000000), '1M');
      expect(formatCount(2500000), '2.5M');
      expect(formatCount(12345678), '12.3M');
    });

    test('Follow State Calculation Label Tests', () {
      expect(getFollowStateLabel(false, false), 'Follow');
      expect(getFollowStateLabel(false, true), 'Follow Back');
      expect(getFollowStateLabel(true, false), 'Following');
      expect(getFollowStateLabel(true, true), 'Mutual');
    });
  });
}
