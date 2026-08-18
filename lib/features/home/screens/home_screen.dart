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
  double? _lat;
  double? _lon;
  Timer? _misriTick;

  @override
  void initState() {
    super.initState();
    // Fallback until GPS arrives; then times follow the user's location.
    _refreshSunTimes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _restoreAndFetchLocation();
    });
    // Refresh sun times + Misri date / رات across Maghrib, midnight, and Sunrise.
    _misriTick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(_refreshSunTimes);
    });
  }

  @override
  void dispose() {
    _misriTick?.cancel();
    super.dispose();
  }

  void _refreshSunTimes([DateTime? now]) {
    final day = now ?? DateTime.now();
    if (_lat != null && _lon != null) {
      _sunTimes = _sunTimesService.forCoordinates(
        latitude: _lat!,
        longitude: _lon!,
        date: day,
      );
    } else {
      _sunTimes = _sunTimesService.forKuwait(date: day);
    }
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
          _lat = lat;
          _lon = lon;
          _refreshSunTimes();
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
        _lat = location.latitude;
        _lon = location.longitude;
        _refreshSunTimes();
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
        _refreshSunTimes();
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
        Expanded(
          child: home.isLoading && details == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ColoredBox(
                    color: AppColors.background,
                    child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (home.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            home.errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      if (details?.currentQiyam.isNotEmpty == true)
                        _DashboardCard(
                          icon: Icons.mosque_outlined,
                          title: 'Current Qiyaam Shareef',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Syedna Abu Jafar us Sadiq Aaliqadr Mufaddal Saifuddin (TUS) Is In :',
                                style: _CardStyle.secondary,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                details!.currentQiyam,
                                style: _CardStyle.primary,
                              ),
                            ],
                          ),
                        ),
                      if (details != null && details.izanPasses.isNotEmpty)
                        ...details.izanPasses.map((pass) {
                          final fallbackIts = details.itsId.isNotEmpty
                              ? details.itsId
                              : details.user.ejamaatId;
                          final fallbackName = details.user.itsName;
                          final members = pass.memberPeople(
                            fallbackIts: fallbackIts,
                            fallbackName: fallbackName,
                          );
                          final guests = pass.guestPeople(
                            fallbackIts: fallbackIts,
                            fallbackName: fallbackName,
                          );
                          return _DashboardCard(
                            icon: Icons.confirmation_number_outlined,
                            title: 'Jaman ${details.izanLabel} Pass',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pass.title.isNotEmpty ? pass.title : 'Event',
                                  style: _CardStyle.primary,
                                ),
                                if (pass.displayDate.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(pass.displayDate, style: _CardStyle.secondary),
                                ],
                                if (members.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const _IzanPassSectionTitle(
                                    label: 'User Pass',
                                  ),
                                  const SizedBox(height: 6),
                                  for (final person in members) ...[
                                    _IzanPassPersonDetails(
                                      person: person,
                                      fallbackIts: fallbackIts,
                                      fallbackName: fallbackName,
                                    ),
                                    if (person != members.last)
                                      const SizedBox(height: 8),
                                  ],
                                ],
                                if (guests.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const _IzanPassSectionTitle(
                                    label: 'Guest User Pass',
                                  ),
                                  const SizedBox(height: 6),
                                  for (final person in guests) ...[
                                    _IzanPassPersonDetails(
                                      person: person,
                                      fallbackIts: fallbackIts,
                                      fallbackName: fallbackName,
                                    ),
                                    if (person != guests.last)
                                      const SizedBox(height: 8),
                                  ],
                                ],
                              ],
                            ),
                          );
                        }),
                      _DashboardCard(
                        icon: Icons.notifications_none,
                        title: 'Latest Notification',
                        child: details?.notify == null
                            ? const Text('No notifications.', style: _CardStyle.secondary)
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
                    ],
                  ),
                  ),
                ),
        ),
      ],
    );
  }

  _HijriDisplay _formatMisriDate(DateTime now) {
    // Always resolve Maghrib/Sunrise for the current Gregorian day so midnight
    // does not keep using yesterday's Maghrib (which wrongly advanced the date).
    final times = (_lat != null && _lon != null)
        ? _sunTimesService.forCoordinates(
            latitude: _lat!,
            longitude: _lon!,
            date: now,
          )
        : (_sunTimes ?? _sunTimesService.forKuwait(date: now));
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  if (showNew) ...[
                    const SizedBox(width: 8),
                    const _NewBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(item.date, style: _CardStyle.meta),
              const SizedBox(height: 6),
              BroadcastBodyText(
                text: item.displayBody,
                style: _CardStyle.secondary,
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

class _IzanPassSectionTitle extends StatelessWidget {
  const _IzanPassSectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    );
  }
}

class _IzanPassPersonDetails extends StatelessWidget {
  const _IzanPassPersonDetails({
    required this.person,
    required this.fallbackIts,
    required this.fallbackName,
  });

  final IzanPassPerson person;
  final String fallbackIts;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final its = person.resolvedIts(fallbackIts: fallbackIts);
    final name = person.resolvedName(
      fallbackIts: fallbackIts,
      fallbackName: fallbackName,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (its.isNotEmpty)
          Text('ITS: $its', style: _CardStyle.secondary),
        if (name.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: its.isNotEmpty ? 2 : 0),
            child: Text(name, style: _CardStyle.secondary),
          ),
      ],
    );
  }
}

class _CardStyle {
  static TextStyle get primary => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        height: 1.3,
      );

  static const secondary = TextStyle(
    fontSize: 13,
    color: Color(0xFF4B5563),
    height: 1.35,
  );

  static const meta = TextStyle(
    fontSize: 12,
    color: AppColors.gray500,
  );
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    this.title,
    this.icon,
  });

  final String? title;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E0D0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.accent, width: 4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 16, color: AppColors.accent),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          title!.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFE8E0D0)),
                  const SizedBox(height: 12),
                ],
                child,
              ],
            ),
          ),
        ),
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
