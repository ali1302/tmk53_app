/// Dawoodi Bohra Misri (Fatimid / Type III) tabular Hijri calendar.
///
/// Leap years in each 30-year cycle: remainders 2, 5, 8, 10, 13, 16, 19, 21, 24, 27, 29.
/// Odd months have 30 days, even months 29; Zilhijjah has 30 days in leap years.
/// Epoch: 1 Muharram 1 AH = Thursday 15 Jul 622 CE (Julian Day 1948439).
class MisriDate {
  const MisriDate(this.year, this.month, this.day);

  final int year;
  final int month; // 1–12
  final int day;

  static const leapRemainders = {2, 5, 8, 10, 13, 16, 19, 21, 24, 27, 29};

  /// Astronomical (Thursday) epoch JD for 1 Muharram 1 AH.
  static const epochJd = 1948439;

  static bool isLeapYear(int year) => leapRemainders.contains(year % 30);

  static int daysInMonth(int year, int month) {
    if (month == 12 && isLeapYear(year)) return 30;
    return month.isOdd ? 30 : 29;
  }

  static int daysBeforeYear(int year) {
    final completed = year - 1;
    var leaps = 0;
    for (var n = 1; n <= completed; n++) {
      if (isLeapYear(n)) leaps++;
    }
    return completed * 354 + leaps;
  }

  static int toJulianDay(int year, int month, int day) {
    var days = daysBeforeYear(year);
    for (var m = 1; m < month; m++) {
      days += daysInMonth(year, m);
    }
    days += day - 1;
    return epochJd + days;
  }

  int get julianDay => toJulianDay(year, month, day);

  static MisriDate fromJulianDay(int jd) {
    final days = jd - epochJd;
    var year = days ~/ 354;
    if (year < 1) year = 1;
    while (daysBeforeYear(year) > days) {
      year--;
    }
    while (daysBeforeYear(year + 1) <= days) {
      year++;
    }
    var rem = days - daysBeforeYear(year);
    var month = 1;
    for (; month <= 12; month++) {
      final len = daysInMonth(year, month);
      if (rem < len) break;
      rem -= len;
    }
    return MisriDate(year, month, rem + 1);
  }

  static int gregorianToJulianDay(int year, int month, int day) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
  }

  static DateTime julianDayToGregorian(int jd) {
    var l = jd + 68569;
    final n = (4 * l) ~/ 146097;
    l = l - (146097 * n + 3) ~/ 4;
    final i = (4000 * (l + 1)) ~/ 1461001;
    l = l - (1461 * i) ~/ 4 + 31;
    final j = (80 * l) ~/ 2447;
    final d = l - (2447 * j) ~/ 80;
    l = j ~/ 11;
    final m = j + 2 - 12 * l;
    final y = 100 * (n - 49) + i + l;
    return DateTime(y, m, d);
  }

  factory MisriDate.fromGregorian(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final jd = gregorianToJulianDay(local.year, local.month, local.day);
    return fromJulianDay(jd);
  }

  /// Misri civil day starts at Maghrib, not at Gregorian midnight.
  ///
  /// - After Maghrib → next Misri date (رات until Sunrise)
  /// - After Sunrise until Maghrib → same Misri date, without رات
  /// - After midnight until Sunrise → still last night's Misri date, with رات
  ///
  /// [maghrib] is the Maghrib clock time; it is applied on [now]'s civil day so
  /// a stale yesterday Maghrib cannot advance the date at 12:00 midnight.
  static MisriDate fromGregorianAt({
    required DateTime now,
    required DateTime maghrib,
  }) {
    now = now.toLocal();
    maghrib = maghrib.toLocal();
    final civil = DateTime(now.year, now.month, now.day);
    final maghribToday = DateTime(
      civil.year,
      civil.month,
      civil.day,
      maghrib.hour,
      maghrib.minute,
      maghrib.second,
    );
    if (!now.isBefore(maghribToday)) {
      // Maghrib has passed on this Gregorian day — Misri date advances.
      return MisriDate.fromGregorian(civil.add(const Duration(days: 1)));
    }
    return MisriDate.fromGregorian(civil);
  }

  /// True from Maghrib until Sunrise (Islamic night / رات), including after midnight.
  static bool isRaat({
    required DateTime now,
    required DateTime sunrise,
    required DateTime maghrib,
  }) {
    now = now.toLocal();
    sunrise = sunrise.toLocal();
    maghrib = maghrib.toLocal();
    final civil = DateTime(now.year, now.month, now.day);
    final sunriseToday = DateTime(
      civil.year,
      civil.month,
      civil.day,
      sunrise.hour,
      sunrise.minute,
      sunrise.second,
    );
    final maghribToday = DateTime(
      civil.year,
      civil.month,
      civil.day,
      maghrib.hour,
      maghrib.minute,
      maghrib.second,
    );
    return !now.isBefore(maghribToday) || now.isBefore(sunriseToday);
  }

  DateTime toGregorian() => julianDayToGregorian(julianDay);

  static const monthNames = [
    'Shehre Moharramul Haram',
    'Safarul Muzaffar',
    'Rabiul Awwal',
    'Rabiul Akhar',
    'Jamadal Ula',
    'Jamadal Ukhra',
    'Shehre Rajabul Asab',
    'Shabanul Karim',
    'Shehre Ramazanul Moazzam',
    'Shawwalul Mukarram',
    'Zilqadatil Haram',
    'Zilhijjatil Haram',
  ];

  static const monthNamesAr = [
    'شهر محرم الحرام',
    'صفر المظفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'شهر رجب الأصب',
    'شعبان الكريم',
    'شهر رمضان المعظم',
    'شوال المكرم',
    'ذي القعدة الحرام',
    'ذي الحجة الحرام',
  ];

  /// Display like API: "27, Safarul Muzaffar, 1448H"
  String get displayLabel =>
      '$day, ${monthNames[month - 1]}, ${year}H';

  String get displayLabelAr =>
      '$day ${monthNamesAr[month - 1]} $year';

  /// Parse common majlis Gregorian strings from API (e.g. "10-August-2026").
  static DateTime? tryParseGregorian(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return null;
    const patterns = [
      'd-MMMM-yyyy',
      'dd-MMMM-yyyy',
      'd-MMM-yyyy',
      'dd-MMM-yyyy',
      'd-M-yyyy',
      'dd-MM-yyyy',
      'yyyy-MM-dd',
    ];
    for (final pattern in patterns) {
      try {
        // Avoid depending on intl here — manual parse for month names.
        if (pattern.contains('MMMM') || pattern.contains('MMM')) {
          final parsed = _parseNamedMonth(cleaned);
          if (parsed != null) return parsed;
          break;
        }
      } catch (_) {}
    }
    final parts = cleaned.split(RegExp(r'[-/.\s]+'));
    if (parts.length == 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a != null && b != null && c != null) {
        if (parts[0].length == 4) {
          return DateTime(a, b, c);
        }
        return DateTime(c, b, a);
      }
    }
    return _parseNamedMonth(cleaned);
  }

  static DateTime? _parseNamedMonth(String cleaned) {
    const months = {
      'january': 1, 'jan': 1,
      'february': 2, 'feb': 2,
      'march': 3, 'mar': 3,
      'april': 4, 'apr': 4,
      'may': 5,
      'june': 6, 'jun': 6,
      'july': 7, 'jul': 7,
      'august': 8, 'aug': 8,
      'september': 9, 'sep': 9, 'sept': 9,
      'october': 10, 'oct': 10,
      'november': 11, 'nov': 11,
      'december': 12, 'dec': 12,
    };
    final match = RegExp(
      r'^(\d{1,2})[-/\s]+([A-Za-z]+)[-/\s]+(\d{4})$',
    ).firstMatch(cleaned);
    if (match == null) return null;
    final day = int.tryParse(match.group(1)!);
    final month = months[match.group(2)!.toLowerCase()];
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  /// Misri label for a Gregorian majlis date string; null if unparsable.
  static String? labelFromGregorianString(String gregorian) {
    final date = tryParseGregorian(gregorian);
    if (date == null) return null;
    return MisriDate.fromGregorian(date).displayLabel;
  }

  MisriDate copyWith({int? year, int? month, int? day}) {
    return MisriDate(year ?? this.year, month ?? this.month, day ?? this.day);
  }

  @override
  String toString() => '$day/$month/$year H';
}
