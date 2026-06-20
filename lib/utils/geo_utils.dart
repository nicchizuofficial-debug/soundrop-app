import 'dart:math' as math;

/// 2点間の距離（メートル）を Haversine 公式で計算する純粋関数。
///
/// プラットフォーム非依存なので単体テストでそのまま検証できる
/// （Geolocator.distanceBetween と同等の結果）。
double distanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadius = 6371000.0; // 地球半径(m)
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double _toRad(double deg) => deg * math.pi / 180.0;
