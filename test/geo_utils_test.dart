import 'package:flutter_test/flutter_test.dart';
import 'package:sound_drop/utils/geo_utils.dart';

void main() {
  group('distanceMeters', () {
    test('同一地点は0m', () {
      expect(distanceMeters(38.2601, 140.8824, 38.2601, 140.8824),
          closeTo(0, 0.001));
    });

    test('仙台駅から約400m北のピンまでの距離', () {
      // pin_002 (38.2637,140.8820) はおおよそ400m北。
      final d = distanceMeters(38.2601, 140.8824, 38.2637, 140.8820);
      expect(d, greaterThan(350));
      expect(d, lessThan(450));
    });

    test('約30m離れた地点は50m圏内', () {
      // 緯度方向に約30m（0.00027度）。
      final d = distanceMeters(38.2601, 140.8824, 38.26037, 140.8824);
      expect(d, lessThan(50));
      expect(d, greaterThan(20));
    });
  });
}
