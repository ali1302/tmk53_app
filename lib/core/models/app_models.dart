import '../calendar/misri_calendar.dart';

class JamaatUser {
  const JamaatUser({
    required this.ejamaatId,
    this.itsName = '',
    this.sabeelNo = '',
    this.hofId = '',
    this.gender = '',
    this.contactNo = '',
  });

  final String ejamaatId;
  final String itsName;
  final String sabeelNo;
  final String hofId;
  final String gender;
  final String contactNo;

  factory JamaatUser.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const JamaatUser(ejamaatId: '');
    }
    return JamaatUser(
      ejamaatId: '${json['ejamaat_id'] ?? ''}',
      itsName: '${json['its_name'] ?? ''}',
      sabeelNo: '${json['sabeel_no'] ?? ''}',
      hofId: '${json['hof_id'] ?? ''}',
      gender: '${json['gender'] ?? ''}',
      contactNo: '${json['contact_no'] ?? ''}',
    );
  }
}

class DueItem {
  const DueItem({
    required this.lagaat,
    required this.takhmeen,
    required this.due,
    required this.lastPaidMonth,
  });

  final String lagaat;
  final String takhmeen;
  final String due;
  final String lastPaidMonth;

  factory DueItem.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && '$value'.trim().isNotEmpty) {
          return '$value'.trim();
        }
      }
      // Case-insensitive fallback.
      final lower = {for (final e in json.entries) e.key.toLowerCase(): e.value};
      for (final key in keys) {
        final value = lower[key.toLowerCase()];
        if (value != null && '$value'.trim().isNotEmpty) {
          return '$value'.trim();
        }
      }
      return '';
    }

    return DueItem(
      lagaat: pick(const ['Lagaat', 'lagaat', 'name']),
      takhmeen: pick(const ['Takhmeen', 'takhmeen']),
      due: pick(const ['Due', 'due', 'amount']),
      lastPaidMonth: pick(const ['LastPaidMonth', 'lastPaidMonth', 'last_paid_month']),
    );
  }

  String get displayAmount {
    final cleaned = due.replaceAll(RegExp(r'[^0-9.\-]'), '');
    final value = double.tryParse(cleaned);
    if (value == null) {
      return due.isEmpty ? '—' : '$due KD';
    }
    final formatted = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$formatted KD';
  }
}

class BroadcastItem {
  const BroadcastItem({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    this.file,
    this.appendInfo,
    this.link,
    this.itsId,
  });

  final String id;
  final String title;
  final String date;
  final String type;
  final String? file;
  final String? appendInfo;
  final String? link;
  final String? itsId;

  factory BroadcastItem.fromJson(Map<String, dynamic> json) {
    return BroadcastItem(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      date: '${json['date'] ?? ''}',
      type: '${json['type'] ?? ''}',
      file: json['file']?.toString(),
      appendInfo: json['appendInfo']?.toString(),
      link: json['link']?.toString(),
      itsId: json['its_id']?.toString(),
    );
  }

  String get displayBody {
    // `title` is the broadcast message text.
    // `appendInfo` is only a 0/1 flag (append ITS name in push), not UI content.
    // `its_id` is a targeting field, not part of the message body.
    return title.trim();
  }

  /// Admin stores optional CTA as `https://...[###]Link Title`.
  String? get linkUrl {
    final raw = link?.trim();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') {
      return null;
    }
    final parts = raw.split('[###]');
    var url = parts.first.trim();
    if (url.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return url;
  }

  String get linkLabel {
    final raw = link?.trim() ?? '';
    final parts = raw.split('[###]');
    if (parts.length > 1 && parts[1].trim().isNotEmpty) {
      return parts[1].trim();
    }
    final url = linkUrl ?? '';
    if (url.contains('forms.gle') || url.contains('docs.google.com/forms')) {
      return 'Open Google Form';
    }
    return 'Open link';
  }

  bool get hasLink => linkUrl != null;

  String? get mediaUrl {
    final raw = file?.trim();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') {
      return null;
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      // Ignore empty/broken broadcast folder URLs from API when no file was uploaded.
      final uri = Uri.tryParse(raw);
      if (uri == null || uri.path.endsWith('/broadcasts/') || uri.path.endsWith('/broadcasts')) {
        return null;
      }
      return raw;
    }
    final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;
    if (cleaned.isEmpty) return null;
    if (cleaned.startsWith('broadcasts/') || cleaned.startsWith('pdf/')) {
      return 'https://tmk53.com/$cleaned';
    }
    return 'https://tmk53.com/broadcasts/$cleaned';
  }

  bool get isPdf {
    final t = type.toLowerCase().trim();
    final url = (mediaUrl ?? file ?? '').toLowerCase();
    return t == 'pdf' ||
        url.contains('/pdf/') ||
        url.endsWith('.pdf') ||
        url.contains('application/pdf');
  }

  bool get isImage {
    if (isPdf || isVideo) return false;
    final t = type.toLowerCase().trim();
    final url = (mediaUrl ?? file ?? '').toLowerCase();
    if (t == 'image' || t == 'photo' || t == 'img') return mediaUrl != null;
    return url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.gif') ||
        url.endsWith('.webp') ||
        url.endsWith('.bmp');
  }

  bool get isVideo {
    final t = type.toLowerCase().trim();
    final url = (mediaUrl ?? file ?? '').toLowerCase();
    return t == 'video' ||
        url.endsWith('.mp4') ||
        url.endsWith('.mov') ||
        url.endsWith('.webm') ||
        url.contains('/live');
  }

  bool get hasMedia => mediaUrl != null && (isImage || isPdf || isVideo);
}

class MajlisItem {
  const MajlisItem({
    required this.id,
    required this.title,
    this.date = '',
    this.hijriDate = '',
    this.onlyHof = false,
    this.passStatus = false,
  });

  final String id;
  final String title;
  final String date;
  final String hijriDate;
  final bool onlyHof;
  final bool passStatus;

  factory MajlisItem.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const MajlisItem(id: '', title: '');
    }
    final onlyHofRaw = json['only_hof_status'] ?? json['onlyHof'];
    final passRaw = json['pass_status'] ?? json['passStatus'];
    return MajlisItem(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}'.trim(),
      date: '${json['date'] ?? ''}',
      hijriDate: '${json['hijriDate'] ?? ''}',
      onlyHof: onlyHofRaw == true ||
          onlyHofRaw == 1 ||
          '$onlyHofRaw' == '1' ||
          '$onlyHofRaw' == 'true',
      passStatus: passRaw == true ||
          passRaw == 1 ||
          '$passRaw' == '1' ||
          '$passRaw' == 'true',
    );
  }

  bool get isEmpty => id.isEmpty && title.isEmpty;

  /// Prefer local Misri conversion from Gregorian date (API hijri can be wrong).
  String get misriDateLabel {
    final local = MisriDate.labelFromGregorianString(date);
    if (local != null && local.isNotEmpty) return local;
    if (_looksLikeValidHijri(hijriDate)) return hijriDate;
    return '';
  }

  static bool _looksLikeValidHijri(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    // Reject broken values like "2183, 1441" / "2179, ,1441"
    if (RegExp(r'^\d{3,4}\s*[,.]?\s*\d{3,4}$').hasMatch(v)) return false;
    if (v.contains(', ,') || v.contains(',,')) return false;
    return RegExp(r'\d{3,4}').hasMatch(v) && RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(v);
  }
}

class IzanPassItem {
  const IzanPassItem({
    required this.majlisId,
    required this.title,
    this.date = '',
    this.hijriDate = '',
    this.shortDate = '',
    this.its = '',
    this.itsName = '',
  });

  final String majlisId;
  final String title;
  final String date;
  final String hijriDate;
  final String shortDate;
  final String its;
  final String itsName;

  factory IzanPassItem.fromJson(Map<String, dynamic> json) {
    return IzanPassItem(
      majlisId: '${json['majlis_id'] ?? json['id'] ?? ''}'.trim(),
      title: '${json['title'] ?? json['majlis_title'] ?? ''}'.trim(),
      date: '${json['date'] ?? json['majlis_date'] ?? ''}'.trim(),
      hijriDate: '${json['hijriDate'] ?? ''}'.trim(),
      shortDate: '${json['majlis_date'] ?? ''}'.trim(),
      its: '${json['its'] ?? json['ejamaat_id'] ?? ''}'.trim(),
      itsName: '${json['its_name'] ?? json['name'] ?? ''}'.trim(),
    );
  }

  bool get isEmpty => title.isEmpty && majlisId.isEmpty;

  String get dateLine {
    final local = MisriDate.labelFromGregorianString(date);
    final hijri = (local != null && local.isNotEmpty)
        ? local
        : (hijriDate.isNotEmpty ? hijriDate : '');
    return [hijri, date].where((e) => e.isNotEmpty).join(' · ');
  }

  /// Dashboard date like "18 Aug".
  String get displayDate {
    if (shortDate.isNotEmpty && !shortDate.contains('-')) return shortDate;
    final source = shortDate.isNotEmpty ? shortDate : date;
    final match = RegExp(r'^(\d{1,2})[- ]([A-Za-z]{3})').firstMatch(source);
    if (match != null) return '${match.group(1)} ${match.group(2)}';
    return source;
  }

  String personLine({String fallbackIts = '', String fallbackName = ''}) {
    final id = its.isNotEmpty ? its : fallbackIts.trim();
    final name = itsName.isNotEmpty ? itsName : fallbackName.trim();
    if (id.isEmpty && name.isEmpty) return '';
    if (name.isEmpty) return id;
    if (id.isEmpty) return name;
    return '$id: $name';
  }
}

class HomeDetails {
  const HomeDetails({
    required this.enDate,
    required this.hijriDate,
    required this.user,
    required this.dues,
    this.notify,
    this.majlis,
    this.izanPasses = const [],
    this.currentQiyam = '',
    this.address = '',
    this.mapLink = '',
    this.canScan = false,
    this.qrUrl,
    this.itsId = '',
    this.izanLabel = 'Izan',
    this.izanHeading = 'Registration for Jaman Izan',
  });

  final String enDate;
  final String hijriDate;
  final JamaatUser user;
  final List<DueItem> dues;
  final BroadcastItem? notify;
  final MajlisItem? majlis;
  /// Pass-enabled majlis events the user (family) is registered for.
  final List<IzanPassItem> izanPasses;
  final String currentQiyam;
  final String address;
  final String mapLink;
  final bool canScan;
  final String? qrUrl;
  final String itsId;
  final String izanLabel;
  final String izanHeading;

  /// True when an active majlis exists and this user has no pass/registration for it.
  bool get needsIzanRegistration {
    final current = majlis;
    if (current == null || current.isEmpty) return false;
    final id = current.id.trim();
    if (id.isEmpty) {
      return izanPasses.isEmpty;
    }
    return !izanPasses.any((p) => p.majlisId.trim() == id);
  }

  /// One-line location for the home geography bar.
  String get displayLocation {
    final cleaned = address
        .replaceAll(RegExp(r'[\r\n]+'), ', ')
        .replaceAll(RegExp(r'\s*,\s*,+'), ',')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'^,+|,+$'), '')
        .trim();
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
    return 'Khaitan, Kuwait';
  }

  factory HomeDetails.fromJson(Map<String, dynamic> json) {
    BroadcastItem? notify;
    final rawNotify = _asStringKeyedMap(json['notify']);
    if (rawNotify != null) {
      notify = BroadcastItem.fromJson(rawNotify);
    }

    MajlisItem? majlis;
    final rawMajlis = _asStringKeyedMap(json['majlis']);
    if (rawMajlis != null && rawMajlis.isNotEmpty) {
      majlis = MajlisItem.fromJson(rawMajlis);
    }

    final dues = <DueItem>[];
    final rawDues = json['dues'];
    if (rawDues is List) {
      for (final item in rawDues) {
        final map = _asStringKeyedMap(item);
        if (map != null) {
          final due = DueItem.fromJson(map);
          if (due.lagaat.isNotEmpty || due.due.isNotEmpty) {
            dues.add(due);
          }
        }
      }
    }

    final userJson = _asStringKeyedMap(json['user']);

    final izanPasses = <IzanPassItem>[];
    final rawPasses = json['majlis_registrations'] ?? json['izan_passes'];
    if (rawPasses is List) {
      final seen = <String>{};
      for (final item in rawPasses) {
        final map = _asStringKeyedMap(item);
        if (map == null) continue;
        final pass = IzanPassItem.fromJson(map);
        if (pass.isEmpty) continue;
        final key = pass.majlisId.isNotEmpty ? pass.majlisId : pass.title;
        if (seen.contains(key)) continue;
        seen.add(key);
        izanPasses.add(pass);
      }
    }

    return HomeDetails(
      enDate: '${json['enDate'] ?? ''}',
      hijriDate: '${json['hijriDate'] ?? ''}',
      user: JamaatUser.fromJson(userJson),
      dues: dues,
      notify: notify,
      majlis: majlis,
      izanPasses: izanPasses,
      currentQiyam: '${json['current_qiyam'] ?? ''}'.trim(),
      address: '${json['address'] ?? ''}'.trim(),
      mapLink: '${json['maplink'] ?? ''}'.trim(),
      canScan: _asBool(json['can_scan']),
      qrUrl: json['qr']?.toString(),
      itsId: '${json['its_id'] ?? userJson?['ejamaat_id'] ?? ''}',
      izanLabel: _nonEmptyLabel(json['izan_label'], 'Izan'),
      izanHeading: _nonEmptyLabel(
        json['izan_heading'],
        'Registration for Jaman Izan',
      ),
    );
  }

  HomeDetails copyWith({
    List<DueItem>? dues,
    List<IzanPassItem>? izanPasses,
  }) {
    return HomeDetails(
      enDate: enDate,
      hijriDate: hijriDate,
      user: user,
      dues: dues ?? this.dues,
      notify: notify,
      majlis: majlis,
      izanPasses: izanPasses ?? this.izanPasses,
      currentQiyam: currentQiyam,
      address: address,
      mapLink: mapLink,
      canScan: canScan,
      qrUrl: qrUrl,
      itsId: itsId,
      izanLabel: izanLabel,
      izanHeading: izanHeading,
    );
  }
}

String _nonEmptyLabel(dynamic value, String fallback) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? fallback : text;
}

Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
  return null;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }
  return false;
}

class ScanEvent {
  const ScanEvent({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.dates,
    this.raw = const {},
  });

  final String id;
  final String category;
  final String title;
  final String description;
  final String dates;
  final Map<String, dynamic> raw;

  factory ScanEvent.fromMajlis(Map<String, dynamic> json) {
    final title = '${json['title'] ?? ''}'.trim();
    final date = '${json['date'] ?? ''}';
    final hijri = '${json['hijriDate'] ?? ''}';
    return ScanEvent(
      id: '${json['id'] ?? ''}',
      category: 'Majlis',
      title: title,
      description: title,
      dates: [date, hijri].where((e) => e.isNotEmpty).join(' | '),
      raw: json,
    );
  }

  factory ScanEvent.fromSabaq(Map<String, dynamic> json) {
    final venue = '${json['venue'] ?? ''}';
    final author = '${json['author'] ?? ''}';
    final date = '${json['date'] ?? ''}';
    return ScanEvent(
      id: '${json['id'] ?? ''}',
      category: 'Sabaq',
      title: venue.isNotEmpty ? venue : 'Sabaq',
      description: [venue, author].where((e) => e.isNotEmpty).join(',\n'),
      dates: date,
      raw: json,
    );
  }

  factory ScanEvent.fromGeneral(Map<String, dynamic> json) {
    final title = '${json['title'] ?? ''}';
    return ScanEvent(
      id: '${json['id'] ?? ''}',
      category: 'General',
      title: title,
      description: title,
      dates: '',
      raw: json,
    );
  }

  factory ScanEvent.fromAsbaq(Map<String, dynamic> json) {
    final title = '${json['text'] ?? json['title'] ?? 'Asbaq'}'.trim();
    final location = '${json['location'] ?? ''}'.trim();
    final kitab = '${json['kitab'] ?? ''}'.trim();
    final ustad = '${json['ustad_name'] ?? ''}'.trim();
    final start = '${json['start_date'] ?? ''}'.trim();
    final end = '${json['end_date'] ?? ''}'.trim();
    final description = [
      if (location.isNotEmpty) location,
      if (kitab.isNotEmpty) kitab,
      if (ustad.isNotEmpty) ustad,
    ].join(',\n');
    return ScanEvent(
      id: '${json['id'] ?? ''}',
      category: 'Asbaq',
      title: title.isNotEmpty ? title : 'Asbaq',
      description: description.isNotEmpty ? description : title,
      dates: [start, end].where((e) => e.isNotEmpty).join(' | '),
      raw: json,
    );
  }
}

class ScanCounts {
  const ScanCounts({
    this.male = '0',
    this.female = '0',
    this.child = '0',
    this.mehman = '0',
    this.unregistered = '0',
    this.all = '0',
  });

  final String male;
  final String female;
  final String child;
  final String mehman;
  final String unregistered;
  final String all;

  factory ScanCounts.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ScanCounts();
    return ScanCounts(
      male: '${json['male_total'] ?? 0}',
      female: '${json['female_total'] ?? 0}',
      child: '${json['child_total'] ?? 0}',
      mehman: '${json['mehman_total'] ?? 0}',
      unregistered: '${json['unregistered_total'] ?? 0}',
      all: '${json['all_total'] ?? 0}',
    );
  }
}

enum ScanUserKind {
  registered,
  mehman,
  notRegistered,
}

ScanUserKind parseScanUserKind({
  String? scanKind,
  String? statusLabel,
  String? name,
}) {
  final raw = '${scanKind ?? ''} ${statusLabel ?? ''}'.trim().toLowerCase();
  if (raw.contains('mehman')) return ScanUserKind.mehman;
  if (raw.contains('not_reg') ||
      raw.contains('not reg') ||
      raw.contains('unregistered') ||
      raw.contains('not register')) {
    return ScanUserKind.notRegistered;
  }
  if (raw.contains('regist')) return ScanUserKind.registered;

  final n = (name ?? '').trim().toLowerCase();
  if (n.isEmpty || n == 'mehman') return ScanUserKind.mehman;
  return ScanUserKind.registered;
}

class ScannedUser {
  const ScannedUser({
    required this.its,
    this.name = '',
    this.message = '',
    this.at,
    this.kind = ScanUserKind.registered,
    this.statusLabel = '',
  });

  final String its;
  final String name;
  final String message;
  final DateTime? at;
  final ScanUserKind kind;
  final String statusLabel;

  String get displayName => name.trim().isEmpty ? 'Mehman' : name.trim();

  String get kindLabel {
    if (statusLabel.trim().isNotEmpty) return statusLabel.trim();
    switch (kind) {
      case ScanUserKind.mehman:
        return 'Mehman';
      case ScanUserKind.notRegistered:
        return 'Not Register';
      case ScanUserKind.registered:
        return 'Registered Member';
    }
  }

  factory ScannedUser.fromJson(Map<String, dynamic> json) {
    final rawTime = '${json['scanning_time'] ?? json['scanned_date'] ?? ''}'.trim();
    DateTime? at;
    if (rawTime.isNotEmpty) {
      // Date-only values (YYYY-MM-DD) parse as midnight — treat as unknown time.
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawTime)) {
        at = null;
      } else {
        at = DateTime.tryParse(rawTime);
        if (at != null &&
            at.hour == 0 &&
            at.minute == 0 &&
            at.second == 0 &&
            !rawTime.contains(':')) {
          at = null;
        }
      }
    }
    final name = '${json['name'] ?? json['its_name'] ?? ''}'.trim();
    final statusLabel = '${json['status_label'] ?? ''}'.trim();
    final kind = parseScanUserKind(
      scanKind: '${json['scan_kind'] ?? ''}',
      statusLabel: statusLabel,
      name: name,
    );
    return ScannedUser(
      its: '${json['its'] ?? ''}',
      name: name,
      message: '${json['message'] ?? ''}'.trim(),
      at: at,
      kind: kind,
      statusLabel: statusLabel,
    );
  }
}

class ScanSubmitResult {
  const ScanSubmitResult({
    required this.message,
    this.name = '',
    this.its = '',
    this.alreadyScanned = false,
    this.kind = ScanUserKind.registered,
    this.statusLabel = '',
  });

  final String message;
  final String name;
  final String its;
  final bool alreadyScanned;
  final ScanUserKind kind;
  final String statusLabel;
}

