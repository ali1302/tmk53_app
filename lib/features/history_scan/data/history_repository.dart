import '../../../core/network/api_client.dart';

enum HistoryStatus {
  attended,
  notAttended,
  registered,
  notRegistered,
  registeredAttended,
  notRegisteredAttended,
  registeredNotAttended,
  unknown,
}

class HistorySession {
  const HistorySession({
    required this.id,
    this.date = '',
    this.status = HistoryStatus.attended,
    this.statusLabel = 'Attended',
  });

  final String id;
  final String date;
  final HistoryStatus status;
  final String statusLabel;

  factory HistorySession.fromJson(Map<String, dynamic> json) {
    final statusRaw = '${json['status'] ?? 'attended'}'.toLowerCase();
    return HistorySession(
      id: '${json['id'] ?? ''}',
      date: '${json['date'] ?? json['scanned_date'] ?? ''}'.trim(),
      status: _parseStatus(statusRaw),
      statusLabel: '${json['status_label'] ?? statusRaw}'.trim(),
    );
  }
}

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.title,
    this.date = '',
    this.hijriDate = '',
    this.subtitle = '',
    this.status = HistoryStatus.unknown,
    this.statusLabel = '',
    this.source = '',
    this.groupKey = '',
    this.attendCount = 0,
    this.sessions = const [],
    this.grouped = false,
  });

  final String id;
  final String title;
  final String date;
  final String hijriDate;
  final String subtitle;
  final HistoryStatus status;
  final String statusLabel;
  final String source;
  /// Asbaq / sabaq id used for client-side grouping fallback.
  final String groupKey;
  final int attendCount;
  final List<HistorySession> sessions;
  final bool grouped;

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final kitab = '${json['kitab'] ?? ''}'.trim();
    final location = '${json['location'] ?? ''}'.trim();
    final type = '${json['type'] ?? ''}'.trim();
    final scanned =
        '${json['scanned_time'] ?? json['scanned_date'] ?? ''}'.trim();
    final groupKey = '${json['asbaq_id'] ?? json['group_key'] ?? ''}'.trim();

    final sessions = <HistorySession>[];
    final rawSessions = json['sessions'];
    if (rawSessions is List) {
      for (final item in rawSessions.whereType<Map>()) {
        sessions.add(HistorySession.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    final attendCountRaw = json['attend_count'];
    final attendCount = attendCountRaw is num
        ? attendCountRaw.toInt()
        : (int.tryParse('$attendCountRaw') ?? sessions.length);

    final subtitleParts = <String>[
      if (kitab.isNotEmpty) kitab,
      if (location.isNotEmpty) location,
      if (type.isNotEmpty && type != 'null') type,
      if (scanned.isNotEmpty && sessions.isEmpty) 'Scanned: $scanned',
    ];

    final groupedFlag = json['grouped'] == true ||
        json['grouped'] == 1 ||
        '${json['grouped']}' == '1' ||
        sessions.isNotEmpty;

    final resolved = _resolveMiqaatStatus(json);

    return HistoryItem(
      id: '${json['id'] ?? json['majlis_id'] ?? json['asbaq_id'] ?? ''}',
      title: '${json['title'] ?? ''}'.trim(),
      date: '${json['date'] ?? ''}'.trim(),
      hijriDate: '${json['hijriDate'] ?? ''}'.trim(),
      subtitle: subtitleParts.join(' · '),
      status: resolved.status,
      statusLabel: resolved.label,
      source: '${json['source'] ?? ''}',
      groupKey: groupKey,
      attendCount: attendCount,
      sessions: sessions,
      grouped: groupedFlag,
    );
  }

  HistoryItem copyWith({
    String? id,
    String? title,
    String? date,
    String? hijriDate,
    String? subtitle,
    HistoryStatus? status,
    String? statusLabel,
    String? source,
    String? groupKey,
    int? attendCount,
    List<HistorySession>? sessions,
    bool? grouped,
  }) {
    return HistoryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      hijriDate: hijriDate ?? this.hijriDate,
      subtitle: subtitle ?? this.subtitle,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      source: source ?? this.source,
      groupKey: groupKey ?? this.groupKey,
      attendCount: attendCount ?? this.attendCount,
      sessions: sessions ?? this.sessions,
      grouped: grouped ?? this.grouped,
    );
  }
}

HistoryStatus _parseStatus(String statusRaw) {
  switch (statusRaw) {
    case 'attended':
      return HistoryStatus.attended;
    case 'not_attended':
      return HistoryStatus.notAttended;
    case 'registered':
      return HistoryStatus.registered;
    case 'not_registered':
      return HistoryStatus.notRegistered;
    case 'registered_attended':
      return HistoryStatus.registeredAttended;
    case 'not_registered_attended':
      return HistoryStatus.notRegisteredAttended;
    case 'registered_not_attended':
      return HistoryStatus.registeredNotAttended;
    default:
      return HistoryStatus.unknown;
  }
}

bool _asBoolFlag(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final v = '$value'.trim().toLowerCase();
  return v == '1' || v == 'true' || v == 'yes';
}

({HistoryStatus status, String label}) _resolveMiqaatStatus(
  Map<String, dynamic> json,
) {
  final statusRaw = '${json['status'] ?? ''}'.toLowerCase().trim();
  final labelRaw = '${json['status_label'] ?? ''}'.trim();
  final source = '${json['source'] ?? ''}'.toLowerCase();

  // Prefer explicit combo statuses from API.
  if (statusRaw == 'registered_attended' ||
      statusRaw == 'not_registered_attended' ||
      statusRaw == 'registered_not_attended') {
    return (
      status: _parseStatus(statusRaw),
      label: labelRaw.isNotEmpty ? labelRaw : statusRaw,
    );
  }

  // Derive combo labels for Miqaat when flags are present.
  final hasRegFlag = json.containsKey('is_registered');
  final hasScanFlag = json.containsKey('is_scanned');
  if (source == 'tmk53' || hasRegFlag || hasScanFlag) {
    final isRegistered = _asBoolFlag(json['is_registered']);
    final isScanned = _asBoolFlag(json['is_scanned']);

    // Keep future-only Registered / Not Registered when API already sent those.
    if (statusRaw == 'registered' || statusRaw == 'not_registered') {
      return (
        status: _parseStatus(statusRaw),
        label: labelRaw.isNotEmpty
            ? labelRaw
            : (statusRaw == 'registered' ? 'Registered' : 'Not Registered'),
      );
    }

    if (isRegistered && isScanned) {
      return (
        status: HistoryStatus.registeredAttended,
        label: 'Registered and Attended',
      );
    }
    if (!isRegistered && isScanned) {
      return (
        status: HistoryStatus.notRegisteredAttended,
        label: 'Not Registered and Attended',
      );
    }
    if (isRegistered && !isScanned) {
      return (
        status: HistoryStatus.registeredNotAttended,
        label: 'Registered and Not Attended',
      );
    }

    // Fallback from legacy attended / not_attended.
    if (statusRaw == 'attended') {
      return (
        status: isRegistered
            ? HistoryStatus.registeredAttended
            : HistoryStatus.notRegisteredAttended,
        label: isRegistered
            ? 'Registered and Attended'
            : 'Not Registered and Attended',
      );
    }
    if (statusRaw == 'not_attended') {
      return (
        status: HistoryStatus.registeredNotAttended,
        label: 'Registered and Not Attended',
      );
    }
  }

  return (
    status: _parseStatus(statusRaw),
    label: labelRaw.isNotEmpty ? labelRaw : statusRaw,
  );
}

class HistoryRepository {
  HistoryRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<HistoryItem>> fetchMajlisHistory(String token) async {
    final response = await _api.get(
      'History/majlis',
      token: token,
      style: AuthHeaderStyle.xJwtToken,
    );
    return _parseList(response);
  }

  Future<List<HistoryItem>> fetchAsbaqHistory(String token) async {
    // Served by main TMK API (same cookie/JWT auth as Miqaat), not /asbaq/.
    final response = await _api.get(
      'History/asbaq',
      token: token,
      style: AuthHeaderStyle.xJwtToken,
    );
    return _groupAsbaqHistory(_parseList(response));
  }

  List<HistoryItem> _parseList(dynamic response) {
    List? raw;
    if (response is List) {
      raw = response;
    } else if (response is Map) {
      final data = response['data'];
      if (data is List) raw = data;
    }
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.title.isNotEmpty || e.id.isNotEmpty)
        .toList();
  }

  /// Ensure one card per asbaq/halka even if API still returns flat scan rows.
  List<HistoryItem> _groupAsbaqHistory(List<HistoryItem> items) {
    if (items.isEmpty) return items;
    if (items.every((e) => e.grouped || e.sessions.isNotEmpty)) {
      return items;
    }

    final byGroup = <String, List<HistoryItem>>{};
    final order = <String>[];
    for (final item in items) {
      final key = item.groupKey.isNotEmpty
          ? item.groupKey
          : (item.title.isNotEmpty ? item.title : item.id);
      if (!byGroup.containsKey(key)) {
        byGroup[key] = [];
        order.add(key);
      }
      byGroup[key]!.add(item);
    }

    return [
      for (final key in order)
        _collapseGroup(key, byGroup[key]!),
    ];
  }

  HistoryItem _collapseGroup(String key, List<HistoryItem> rows) {
    final first = rows.first;
    final sessions = <HistorySession>[];
    for (final row in rows) {
      if (row.sessions.isNotEmpty) {
        sessions.addAll(row.sessions);
      } else if (row.status == HistoryStatus.attended ||
          row.date.isNotEmpty && row.id.startsWith('scan-')) {
        sessions.add(
          HistorySession(
            id: row.id,
            date: row.date,
            status: HistoryStatus.attended,
            statusLabel: row.statusLabel.isNotEmpty ? row.statusLabel : 'Attended',
          ),
        );
      }
    }

    HistoryStatus status;
    String statusLabel;
    if (sessions.isNotEmpty) {
      status = HistoryStatus.attended;
      statusLabel = sessions.length == 1
          ? 'Attended · 1 day'
          : 'Attended · ${sessions.length} days';
    } else {
      status = first.status;
      statusLabel = first.statusLabel;
    }

    return first.copyWith(
      id: 'group-$key',
      groupKey: key,
      attendCount: sessions.length,
      sessions: sessions,
      grouped: true,
      status: status,
      statusLabel: statusLabel,
      date: sessions.isNotEmpty ? sessions.first.date : first.date,
    );
  }
}
