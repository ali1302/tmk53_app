import 'package:adhan_dart/adhan_dart.dart';
import 'package:intl/intl.dart';

class SunTimes {
  const SunTimes({
    required this.fajr,
    required this.sunrise,
    required this.zawal,
    required this.maghrib,
  });

  final DateTime fajr;
  final DateTime sunrise;
  final DateTime zawal;
  final DateTime maghrib;

  String get fajrLabel => _fmt(fajr);
  String get sunriseLabel => _fmt(sunrise);
  String get zawalLabel => _fmt(zawal);
  String get maghribLabel => _fmt(maghrib);

  static String _fmt(DateTime t) => DateFormat('hh:mm').format(t);
}

/// Sunrise, Zawal (solar noon / Dhuhr), Maghrib, and Fajr from lat/lon.
class SunTimesService {
  /// Kuwait City — used when GPS is unavailable so Misri Maghrib/Fajr still work.
  static const kuwaitLatitude = 29.3759;
  static const kuwaitLongitude = 47.9774;

  SunTimes? forCoordinates({
    required double latitude,
    required double longitude,
    DateTime? date,
  }) {
    try {
      final day = date ?? DateTime.now();
      final coords = Coordinates(latitude, longitude);
      // App is TMK 53 (Kuwait) — use Kuwait calculation method.
      final params = CalculationMethodParameters.kuwait();
      final times = PrayerTimes(
        date: day,
        coordinates: coords,
        calculationParameters: params,
      );

      return SunTimes(
        fajr: times.fajr.toLocal(),
        sunrise: times.sunrise.toLocal(),
        zawal: times.dhuhr.toLocal(),
        maghrib: times.maghrib.toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  SunTimes? forKuwait({DateTime? date}) => forCoordinates(
        latitude: kuwaitLatitude,
        longitude: kuwaitLongitude,
        date: date,
      );
}
