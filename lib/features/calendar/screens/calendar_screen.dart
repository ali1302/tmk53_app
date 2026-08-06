import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

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

  late HijriCalendar _hijriMonth;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _hijriMonth = HijriCalendar.fromDate(now);
    _hijriMonth.hDay = 1;
  }

  void _shiftMonth(int delta) {
    setState(() {
      var year = _hijriMonth.hYear;
      var month = _hijriMonth.hMonth + delta;
      while (month < 1) {
        month += 12;
        year -= 1;
      }
      while (month > 12) {
        month -= 12;
        year += 1;
      }
      _hijriMonth = HijriCalendar()
        ..hYear = year
        ..hMonth = month
        ..hDay = 1;
    });
  }

  DateTime _gregorianForHijriDay(int day) {
    final h = HijriCalendar()
      ..hYear = _hijriMonth.hYear
      ..hMonth = _hijriMonth.hMonth
      ..hDay = day;
    return h.hijriToGregorian(h.hYear, h.hMonth, h.hDay);
  }

  int _lengthOfHijriMonth() {
    return _hijriMonth.getDaysInMonth(_hijriMonth.hYear, _hijriMonth.hMonth);
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
          onTap: () => setState(() => _selected = date),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected && !isToday ? const Color(0xFFFDF6E3) : Colors.white,
              border: Border.all(
                color: isToday ? AppColors.accent : const Color(0xFFE5E7EB),
                width: isToday ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              children: [
                Text(
                  gregLabel,
                  style: const TextStyle(fontSize: 9, color: AppColors.gray400, height: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  _toArabicDigits(day),
                  style: GoogleFonts.notoNaskhArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

    final selHijri = _selected == null ? null : HijriCalendar.fromDate(_selected!);
    final monthTitle =
        '${_hijriMonths[_hijriMonth.hMonth - 1]} - ${_hijriMonth.hYear}';

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
                  childAspectRatio: 0.85,
                  children: cells,
                ),
                if (selHijri != null && _selected != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${DateFormat('EEEE').format(_selected!)} , '
                    '${selHijri.hDay} ${_hijriMonths[selHijri.hMonth - 1]} ${selHijri.hYear}',
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
                    children: const [
                      _PrayerChip(label: 'Sunrise', time: '—'),
                      _PrayerChip(label: 'Zawal', time: '—'),
                      _PrayerChip(label: 'Maghrib', time: '—'),
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
