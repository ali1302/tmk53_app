import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/calendar/misri_calendar.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/sun_times_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/kaaba_icon.dart';
import '../../auth/providers/auth_provider.dart';
import '../../broadcast/providers/broadcast_provider.dart';
import '../../broadcast/widgets/broadcast_detail_sheet.dart';
import '../providers/home_provider.dart';
import '../widgets/sun_times_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenQr,
    this.onOpenQibla,
    this.onOpenBroadcast,
    this.onOpenContactUs,
  });

  final VoidCallback onOpenQr;
  final ValueChanged<String>? onOpenQibla;
  final VoidCallback? onOpenBroadcast;
  final VoidCallback? onOpenContactUs;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _locationCacheKey = 'tmk_user_geo_location';
  static const _latCacheKey = 'tmk_user_geo_lat';
  static const _lonCacheKey = 'tmk_user_geo_lon';

  final _locationService = LocationService();
  final _sunTimesService = SunTimesService();
  String _geoLocation = 'Detecting location…';
  bool _locating = false;
  String? _locationError;
  SunTimes? _sunTimes;
  Timer? _misriTick;

  @override
  void initState() {
    super.initState();
    // Fallback until GPS arrives; then times follow the user's location.
    _sunTimes = _sunTimesService.forKuwait();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _restoreAndFetchLocation();
    });
    // Refresh Misri date / رات when Maghrib or Sunrise crosses.
    _misriTick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _misriTick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final home = context.read<HomeProvider>();
    await home.load(
      token: auth.token ?? '',
      itsId: auth.itsId ?? '',
      preview: auth.isDesignPreview,
    );
    if (!auth.isDesignPreview && home.details != null) {
      auth.updateFromHome(home.details!);
    }
  }

  Future<void> _restoreAndFetchLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_locationCacheKey);
    final lat = prefs.getDouble(_latCacheKey);
    final lon = prefs.getDouble(_lonCacheKey);
    if (mounted) {
      setState(() {
        if (cached != null &&
            cached.trim().isNotEmpty &&
            !LocationService.isArabicLabel(cached)) {
          _geoLocation = cached.trim();
        } else if (cached != null && LocationService.isArabicLabel(cached)) {
          // Drop stale Arabic cache so English reverse-geocode can replace it.
          prefs.remove(_locationCacheKey);
        }
        if (lat != null && lon != null) {
          _sunTimes = _sunTimesService.forCoordinates(
            latitude: lat,
            longitude: lon,
          );
        }
      });
    }
    await _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
      if (_geoLocation == 'Location unavailable') {
        _geoLocation = 'Detecting location…';
      }
    });
    try {
      final location = await _locationService.getCurrentLocation();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_locationCacheKey, location.label);
      await prefs.setDouble(_latCacheKey, location.latitude);
      await prefs.setDouble(_lonCacheKey, location.longitude);
      if (!mounted) return;
      setState(() {
        _geoLocation = location.label;
        _sunTimes = _sunTimesService.forCoordinates(
          latitude: location.latitude,
          longitude: location.longitude,
        );
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is StateError
          ? e.message
          : 'Unable to detect location. Tap refresh to retry.';
      setState(() {
        _locationError = message;
        if (_geoLocation == 'Detecting location…' ||
            _geoLocation == 'Location unavailable') {
          _geoLocation = 'Location unavailable';
        }
        // Keep last GPS times if we have them; otherwise Kuwait fallback.
        _sunTimes ??= _sunTimesService.forKuwait();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () async {
              if (message.toLowerCase().contains('blocked') ||
                  message.toLowerCase().contains('permission')) {
                await _locationService.openAppSettings();
              } else {
                await _locationService.openLocationSettings();
              }
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _openMapsForCurrentLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latCacheKey);
    final lon = prefs.getDouble(_lonCacheKey);
    final uri = (lat != null && lon != null)
        ? Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon')
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_geoLocation)}',
          );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openQibla() {
    widget.onOpenQibla?.call(_geoLocation);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final home = context.watch<HomeProvider>();
    final details = home.details;
    final dateParts = _parseEnDate(details?.enDate);
    // Use local Misri (Fatimid) calendar — advances after Maghrib; رات until Sunrise.
    final hijriDisplay = _formatMisriDate(DateTime.now());

    return Column(
      children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Home',
                  style: GoogleFonts.inter(
                    color: AppColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: home.isLoading ? null : _load,
                icon: const Icon(Icons.refresh, color: AppColors.accent, size: 20),
              ),
              if (widget.onOpenContactUs != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: widget.onOpenContactUs,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.15),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.phone_in_talk_outlined, size: 18, color: AppColors.accent),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              InkWell(
                onTap: widget.onOpenQr,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.qr_code_2, size: 18, color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: home.isLoading && details == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      if (home.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            home.errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateParts.weekday,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.5,
                                      color: AppColors.gray500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateParts.day,
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w700,
                                      height: 1,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateParts.monthYear,
                                    style: const TextStyle(fontSize: 14, color: AppColors.gray500),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  textDirection: TextDirection.rtl,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      hijriDisplay.dayArabic,
                                      style: GoogleFonts.notoNaskhArabic(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accent,
                                        height: 1,
                                      ),
                                    ),
                                    if (hijriDisplay.isRaat) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        'رات',
                                        style: GoogleFonts.notoNaskhArabic(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accent,
                                          height: 1,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hijriDisplay.monthYearArabic,
                                  textDirection: TextDirection.rtl,
                                  style: GoogleFonts.notoNaskhArabic(
                                    fontSize: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        color: AppColors.cream,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: AppColors.muted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: GestureDetector(
                                onTap: _geoLocation == 'Location unavailable'
                                    ? _fetchLocation
                                    : _openMapsForCurrentLocation,
                                child: Text(
                                  _locationError != null &&
                                          _geoLocation == 'Location unavailable'
                                      ? 'Tap to enable location'
                                      : _geoLocation,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF5A4A30),
                                  ),
                                ),
                              ),
                            ),
                            Tooltip(
                              message: 'Qibla Finder',
                              child: Material(
                                color: AppColors.accent,
                                shape: const CircleBorder(),
                                elevation: 1,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: widget.onOpenQibla == null ? null : _openQibla,
                                  child: const SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Center(
                                      child: KaabaIcon(size: 28),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (_locating)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              InkWell(
                                onTap: _fetchLocation,
                                child: const Icon(Icons.refresh, size: 16, color: AppColors.muted),
                              ),
                          ],
                        ),
                      ),
                      SunTimesBar(times: _sunTimes),
                      if (details?.currentQiyam.isNotEmpty == true)
                        _InfoCard(
                          title: 'Current Qiyaam Shareef',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Syedna Abu Jafar us Sadiq Aaliqadr Mufaddal Saifuddin (TUS) Is In :',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4B5563),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                details!.currentQiyam,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (details != null && details.izanPasses.isNotEmpty)
                        ...details.izanPasses.map(
                          (pass) => _InfoCard(
                            title:
                                'Your ${details.izanLabel} Pass is available',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pass.title.isNotEmpty
                                      ? pass.title
                                      : 'Event',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                                if (pass.dateLine.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    pass.dateLine,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.gray500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      if (details?.majlis != null && !details!.majlis!.isEmpty)
                        _InfoCard(
                          title: 'Current Majlis',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                details.majlis!.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  details.majlis!.misriDateLabel,
                                  details.majlis!.date,
                                ].where((e) => e.isNotEmpty).join(' · '),
                                style: const TextStyle(fontSize: 12, color: AppColors.gray500),
                              ),
                            ],
                          ),
                        ),
                      _InfoCard(
                        title: 'Latest Notification',
                        child: details?.notify == null
                            ? const Text(
                                'No notifications.',
                                style: TextStyle(fontSize: 14, color: AppColors.gray500),
                              )
                            : Builder(
                                builder: (context) {
                                  final notify = details!.notify!;
                                  final isNew =
                                      !context.watch<BroadcastProvider>().isRead(notify.id);
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      InkWell(
                                        onTap: () async {
                                          await showBroadcastDetailSheet(context, notify);
                                          widget.onOpenBroadcast?.call();
                                        },
                                        child: _NotifyBlock(
                                          item: notify,
                                          showNew: isNew,
                                          showMedia: false,
                                        ),
                                      ),
                                      if (notify.hasMedia) ...[
                                        const SizedBox(height: 8),
                                        BroadcastMediaView(item: notify, compact: true),
                                      ],
                                      if (notify.hasLink) ...[
                                        const SizedBox(height: 8),
                                        BroadcastLinkButton(item: notify),
                                      ],
                                    ],
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  _HijriDisplay _formatMisriDate(DateTime now) {
    final times = _sunTimes ?? _sunTimesService.forKuwait(date: now);
    final MisriDate misri;
    final bool raat;
    if (times != null) {
      misri = MisriDate.fromGregorianAt(
        now: now,
        maghrib: times.maghrib,
      );
      raat = MisriDate.isRaat(
        now: now,
        sunrise: times.sunrise,
        maghrib: times.maghrib,
      );
    } else {
      misri = MisriDate.fromGregorian(now);
      raat = false;
    }
    final monthAr = MisriDate.monthNamesAr[misri.month - 1];
    final yearAr = _toArabicDigits('${misri.year}هـ');
    return _HijriDisplay(
      dayArabic: _toArabicDigits('${misri.day}'),
      monthYearArabic: '$monthAr $yearAr',
      isRaat: raat,
    );
  }

  String _toArabicDigits(String input) {
    const western = '0123456789';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final buffer = StringBuffer();
    for (final code in input.runes) {
      final ch = String.fromCharCode(code);
      final index = western.indexOf(ch);
      buffer.write(index >= 0 ? arabic[index] : ch);
    }
    return buffer.toString();
  }

  _DateParts _parseEnDate(String? enDate) {
    if (enDate == null || enDate.isEmpty) {
      final now = DateTime.now();
      const weekdays = [
        'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'
      ];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return _DateParts(
        weekday: weekdays[now.weekday - 1],
        day: now.day.toString().padLeft(2, '0'),
        monthYear: '${months[now.month - 1]} ${now.year}',
      );
    }

    // Expected: "Wednesday,22, July, 2026" or similar.
    final cleaned = enDate.replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final parts = cleaned.split(' ');
    final weekday = parts.isNotEmpty ? parts.first.toUpperCase() : 'TODAY';
    final day = parts.length > 1 ? parts[1].padLeft(2, '0') : '--';
    final month = parts.length > 2 ? parts[2] : '';
    final year = parts.length > 3 ? parts[3] : '';
    return _DateParts(
      weekday: weekday,
      day: day,
      monthYear: '$month $year'.trim(),
    );
  }
}

class _DateParts {
  const _DateParts({
    required this.weekday,
    required this.day,
    required this.monthYear,
  });
  final String weekday;
  final String day;
  final String monthYear;
}

class _HijriDisplay {
  const _HijriDisplay({
    required this.dayArabic,
    required this.monthYearArabic,
    this.isRaat = false,
  });
  final String dayArabic;
  final String monthYearArabic;
  final bool isRaat;
}

class _NotifyBlock extends StatelessWidget {
  const _NotifyBlock({
    required this.item,
    this.showNew = true,
    this.showMedia = true,
  });
  final BroadcastItem item;
  final bool showNew;
  final bool showMedia;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cream,
            border: Border.all(color: AppColors.accent, width: 2),
          ),
          child: Text(
            'TMK',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'TMK Broadcast',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (showNew) ...[
                    const SizedBox(width: 8),
                    const _NewBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(item.date, style: const TextStyle(fontSize: 10, color: AppColors.gray400)),
              const SizedBox(height: 6),
              BroadcastBodyText(
                text: item.displayBody,
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.4),
              ),
              if (showMedia && item.hasMedia) ...[
                const SizedBox(height: 8),
                BroadcastMediaView(item: item, compact: true),
              ],
              if (showMedia && item.hasLink) ...[
                const SizedBox(height: 8),
                BroadcastLinkButton(item: item),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}
