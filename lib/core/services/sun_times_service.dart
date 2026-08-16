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

/// Sunrise, Zawal (solar noon / Dhuhr), Maghrib, and Fajr for the user's location.
///
/// Uses Kuwait calculation angles (Fajr 18°, Isha 17.5°), but coordinates come
/// from GPS. Times are shown in the device's local timezone (where the user is).
class SunTimesService {
  /// Fallback when GPS is unavailable.
  static const kuwaitLatitude = 29.3759;
  static const kuwaitLongitude = 47.9774;

  /// Kuwait City fallback (only when location is unknown).
  SunTimes? forKuwait({DateTime? date}) => forCoordinates(
        latitude: kuwaitLatitude,
        longitude: kuwaitLongitude,
        date: date,
      );

  /// Prayer/sun times for [latitude]/[longitude], in the device local clock.
  SunTimes? forCoordinates({
    required double latitude,
    required double longitude,
    DateTime? date,
  }) {
    try {
      // Calendar day on the user's device (where they are logged in).
      final local = (date ?? DateTime.now()).toLocal();
      final day = DateTime(local.year, local.month, local.day);

      final coords = Coordinates(latitude, longitude);
      final params = CalculationMethodParameters.kuwait();
      final times = PrayerTimes(
        date: day,
        coordinates: coords,
        calculationParameters: params,
      );

      // adhan_dart returns UTC — convert to the user's local timezone.
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
}
