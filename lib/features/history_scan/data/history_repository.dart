import '../../../core/network/api_client.dart';

enum HistoryStatus { attended, notAttended, registered, notRegistered, unknown }

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
  });

  final String id;
  final String title;
  final String date;
  final String hijriDate;
  final String subtitle;
  final HistoryStatus status;
  final String statusLabel;
  final String source;

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final statusRaw = '${json['status'] ?? ''}'.toLowerCase();
    HistoryStatus status;
    switch (statusRaw) {
      case 'attended':
        status = HistoryStatus.attended;
        break;
      case 'not_attended':
        status = HistoryStatus.notAttended;
        break;
      case 'registered':
        status = HistoryStatus.registered;
        break;
      case 'not_registered':
        status = HistoryStatus.notRegistered;
        break;
      default:
        status = HistoryStatus.unknown;
    }

    final kitab = '${json['kitab'] ?? ''}'.trim();
    final location = '${json['location'] ?? ''}'.trim();
    final type = '${json['type'] ?? ''}'.trim();
    final scanned = '${json['scanned_time'] ?? json['scanned_date'] ?? ''}'.trim();

    final subtitleParts = <String>[
      if (kitab.isNotEmpty) kitab,
      if (location.isNotEmpty) location,
      if (type.isNotEmpty && type != 'null') type,
      if (scanned.isNotEmpty) 'Scanned: $scanned',
    ];

    return HistoryItem(
      id: '${json['id'] ?? json['majlis_id'] ?? json['asbaq_id'] ?? ''}',
      title: '${json['title'] ?? ''}'.trim(),
      date: '${json['date'] ?? ''}'.trim(),
      hijriDate: '${json['hijriDate'] ?? ''}'.trim(),
      subtitle: subtitleParts.join(' · '),
      status: status,
      statusLabel: '${json['status_label'] ?? statusRaw}'.trim(),
      source: '${json['source'] ?? ''}',
    );
  }
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
    return _parseList(response);
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
}
