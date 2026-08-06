import 'dart:math' as math;

/// Kaaba coordinates (Masjid al-Haram, Makkah).
class QiblaService {
  static const double kaabaLatitude = 21.422487;
  static const double kaabaLongitude = 39.826206;

  /// Bearing in degrees from [lat]/[lon] to the Kaaba (0–360, clockwise from north).
  static double bearingToKaaba(double lat, double lon) {
    return bearingBetween(lat, lon, kaabaLatitude, kaabaLongitude);
  }

  /// Great-circle distance in kilometres.
  static double distanceKm(double lat, double lon) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(kaabaLatitude - lat);
    final dLon = _toRad(kaabaLongitude - lon);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat)) *
            math.cos(_toRad(kaabaLatitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double bearingBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final lat1Rad = _toRad(lat1);
    final lat2Rad = _toRad(lat2);
    final dLon = _toRad(lon2 - lon1);
    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    final theta = math.atan2(y, x);
    return (_toDeg(theta) + 360) % 360;
  }

  /// Shortest signed angle from [fromDeg] to [toDeg] (−180…180).
  static double shortestAngle(double fromDeg, double toDeg) {
    var diff = (toDeg - fromDeg) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return diff;
  }

  static String cardinalLabel(double bearing) {
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) % 360 / 45).floor();
    return labels[index];
  }

  static double _toRad(double deg) => deg * math.pi / 180;
  static double _toDeg(double rad) => rad * 180 / math.pi;
}
