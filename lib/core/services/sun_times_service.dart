import 'package:adhan_dart/adhan_dart.dart';
import 'package:intl/intl.dart';

class SunTimes {
  const SunTimes({
    required this.sunrise,
    required this.zawal,
    required this.maghrib,
  });

  final DateTime sunrise;
  final DateTime zawal;
  final DateTime maghrib;

  String get sunriseLabel => _fmt(sunrise);
  String get zawalLabel => _fmt(zawal);
  String get maghribLabel => _fmt(maghrib);

  static String _fmt(DateTime t) => DateFormat('hh:mm').format(t);
}

/// Sunrise, Zawal (solar noon / Dhuhr), and Maghrib from lat/lon.
class SunTimesService {
  SunTimes? forCoordinates({
    required double latitude,
    required double longitude,
    DateTime? date,
  }) {
    try {
      final day = date ?? DateTime.now();
      final coords = Coordinates(latitude, longitude);
      // App is TMK Kuwait — use Kuwait calculation method.
      final params = CalculationMethodParameters.kuwait();
      final times = PrayerTimes(
        date: day,
        coordinates: coords,
        calculationParameters: params,
      );

      return SunTimes(
        sunrise: times.sunrise.toLocal(),
        zawal: times.dhuhr.toLocal(),
        maghrib: times.maghrib.toLocal(),
      );
    } catch (_) {
      return null;
    }
  }
}
