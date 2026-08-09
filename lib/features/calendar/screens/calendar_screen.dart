import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/calendar/misri_calendar.dart';
import '../../../core/services/sun_times_service.dart';
import '../../../core/theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _hijriMonths = [
    'Muharramul Haram',
    'Safarul Khair',
    'Rabi ul Awwal',
    'Rabi ul Aakhar',
    'Jumadil Ula',
    'Jumadil Ukhra',
    'Rajab ul Asab',
    'Shaabaan',
    'Ramadan',
    'Shawwal',
    'Zilqadah',
    'Zilhijjah',
  ];

  static const _latCacheKey = 'tmk_user_geo_lat';
  static const _lonCacheKey = 'tmk_user_geo_lon';
  // TMK Kuwait fallback when GPS not available yet.
  static const _kuwaitLat = 29.3759;
  static const _kuwaitLon = 47.9774;

  final _sunTimesService = SunTimesService();

  late MisriDate _hijriMonth;
  DateTime? _selected;
  double _latitude = _kuwaitLat;
  double _longitude = _kuwaitLon;
  SunTimes? _sunTimes;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    final todayMisri = MisriDate.fromGregorian(now);
    _hijriMonth = MisriDate(todayMisri.year, todayMisri.month, 1);
    _sunTimes = _computeSunTimes();
    _loadCachedCoordinates();
  }

  Future<void> _loadCachedCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latCacheKey);
    final lon = prefs.getDouble(_lonCacheKey);
    if (!mounted) return;
    if (lat != null && lon != null) {
      setState(() {
        _latitude = lat;
        _longitude = lon;
        _sunTimes = _computeSunTimes();
      });
    }
  }

  SunTimes? _computeSunTimes() {
    final day = _selected ?? DateTime.now();
    return _sunTimesService.forCoordinates(
      latitude: _latitude,
      longitude: _longitude,
      date: day,
    );
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selected = date;
      _sunTimes = _computeSunTimes();
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      var year = _hijriMonth.year;
      var month = _hijriMonth.month + delta;
      while (month < 1) {
        month += 12;
        year -= 1;
      }
      while (month > 12) {
        month -= 12;
        year += 1;
      }
      _hijriMonth = MisriDate(year, month, 1);
    });
  }

  DateTime _gregorianForHijriDay(int day) {
    return MisriDate(_hijriMonth.year, _hijriMonth.month, day).toGregorian();
  }

  int _lengthOfHijriMonth() {
    return MisriDate.daysInMonth(_hijriMonth.year, _hijriMonth.month);
  }

  String _toArabicDigits(int n) {
    const western = '0123456789';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) {
      final i = western.indexOf(c);
      return i >= 0 ? arabic[i] : c;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    final monthLen = _lengthOfHijriMonth();
    final firstGreg = _gregorianForHijriDay(1);
    final startDow = firstGreg.weekday % 7; // Sun=0
    final cells = <Widget>[];

    for (var i = 0; i < startDow; i++) {
      cells.add(Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
      ));
    }

    for (var day = 1; day <= monthLen; day++) {
      final date = _gregorianForHijriDay(day);
      final isSelected = _selected != null && DateUtils.isSameDay(_selected!, date);
      final isToday = DateUtils.isSameDay(date, DateTime.now());
      final showMon = day == 1 || date.day == 1;
      final gregLabel = showMon
          ? '${DateFormat('MMM').format(date)} ${date.day}'
          : '${date.day}';

      cells.add(
        InkWell(
          onTap: () => _selectDate(date),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected && !isToday ? const Color(0xFFFDF6E3) : Colors.white,
              border: Border.all(
                color: isToday ? AppColors.accent : const Color(0xFFE5E7EB),
                width: isToday ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  gregLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9, color: AppColors.gray400, height: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  _toArabicDigits(day),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoNaskhArabic(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.hijriGreen,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    while (cells.length % 7 != 0) {
      cells.add(Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
      ));
    }

    final selHijri = _selected == null ? null : MisriDate.fromGregorian(_selected!);
    final monthTitle =
        '${_hijriMonths[_hijriMonth.month - 1]} - ${_hijriMonth.year}';

    return Material(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 4,
              left: 8,
              right: 8,
              bottom: 10,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onClose,
                  icon: Icon(Icons.chevron_left, color: AppColors.accent),
                ),
                Text(
                  'Calendar',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _shiftMonth(-1),
                        icon: Icon(Icons.chevron_left, color: AppColors.gray500),
                      ),
                      Expanded(
                        child: Text(
                          monthTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _shiftMonth(1),
                        icon: Icon(Icons.chevron_right, color: AppColors.gray500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .map(
                        (d) => Expanded(
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gray500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 6),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 7,
                  childAspectRatio: 0.75,
                  children: cells,
                ),
                if (selHijri != null && _selected != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${DateFormat('EEEE').format(_selected!)} , '
                    '${selHijri.day} ${_hijriMonths[selHijri.month - 1]} ${selHijri.year}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d MMMM yyyy').format(_selected!),
                    style: const TextStyle(fontSize: 12, color: AppColors.gray500),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PrayerChip(
                        label: 'Sunrise',
                        time: _sunTimes?.sunriseLabel ?? '—',
                      ),
                      _PrayerChip(
                        label: 'Zawal',
                        time: _sunTimes?.zawalLabel ?? '—',
                      ),
                      _PrayerChip(
                        label: 'Maghrib',
                        time: _sunTimes?.maghribLabel ?? '—',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Each cell shows English date (top) and Misri / Hijri day (bottom).',
                  style: TextStyle(fontSize: 11, color: AppColors.gray400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerChip extends StatelessWidget {
  const _PrayerChip({required this.label, required this.time});

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
        ),
      ],
    );
  }
}
