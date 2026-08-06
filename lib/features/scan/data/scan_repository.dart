import '../../../core/models/app_models.dart';
import '../../../core/network/api_client.dart';

class ScanRepository {
  ScanRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<bool> isScanUser(String token) async {
    try {
      final response = await _api.get('Scan/is_scan_user', token: token);
      if (response is Map<String, dynamic>) {
        final data = response['data'];
        if (data is bool) return data;
        if (data is num) return data != 0;
        if (data is String) return data == '1' || data.toLowerCase() == 'true';
      }
    } catch (_) {}
    return false;
  }

  Future<List<ScanEvent>> getEvents(String token) async {
    final events = <ScanEvent>[];

    try {
      final sabaq = await _api.get('Sabaq/list', token: token);
      if (sabaq is Map<String, dynamic> && sabaq['data'] is List) {
        for (final item in sabaq['data'] as List) {
          if (item is Map) {
            events.add(ScanEvent.fromSabaq(Map<String, dynamic>.from(item)));
          }
        }
      }
    } catch (_) {}

    try {
      final majlis = await _api.get('Scan/get_scan_events', token: token);
      if (majlis is Map<String, dynamic> && majlis['data'] is List) {
        for (final item in majlis['data'] as List) {
          if (item is Map) {
            events.add(ScanEvent.fromMajlis(Map<String, dynamic>.from(item)));
          }
        }
      }
    } catch (_) {}

    try {
      final general = await _api.get('Generalscan/list', token: token);
      if (general is Map<String, dynamic> && general['data'] is List) {
        for (final item in general['data'] as List) {
          if (item is Map) {
            events.add(ScanEvent.fromGeneral(Map<String, dynamic>.from(item)));
          }
        }
      }
    } catch (_) {}

    // Asbaq (Halka) events from https://tmk53.com/asbaq admin module
    try {
      final asbaq = await _api.get('Asbaq/list', token: token, asbaq: true);
      if (asbaq is Map<String, dynamic> && asbaq['data'] is List) {
        for (final item in asbaq['data'] as List) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final disabled = map['disabled'];
            final isDisabled = disabled == true ||
                disabled == 1 ||
                disabled == '1' ||
                '$disabled'.toLowerCase() == 'true';
            if (isDisabled) continue;
            events.add(ScanEvent.fromAsbaq(map));
          }
        }
      }
    } catch (_) {}

    return events;
  }

  Future<ScanCounts> getMajlisCounts({
    required String token,
    required String majlisId,
  }) async {
    final response = await _api.get(
      'Scan/get_total_counts/$majlisId',
      token: token,
    );
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return ScanCounts.fromJson(data);
      }
    }
    return const ScanCounts();
  }

  Future<String> registerSabaq({
    required String token,
    required String its,
    required String sabaqId,
  }) async {
    final response = await _api.post(
      'Sabaq/register',
      token: token,
      fields: {
        'its': its,
        'sabaq_id': sabaqId,
      },
    );
    if (response is Map<String, dynamic>) {
      return response['message']?.toString() ?? 'Scanned successfully.';
    }
    return 'Scanned successfully.';
  }

  Future<String> registerGeneral({
    required String token,
    required String its,
    required String eventId,
  }) async {
    final response = await _api.post(
      'Generalscan/register',
      token: token,
      fields: {
        'its': its,
        'generalscan_id': eventId,
      },
    );
    if (response is Map<String, dynamic>) {
      return response['message']?.toString() ?? 'Scanned successfully.';
    }
    return 'Scanned successfully.';
  }

  Future<String> saveMajlisScan({
    required String token,
    required String majlisId,
    required String its,
  }) async {
    final users = '[{"its":"$its","scanning_time":"${DateTime.now().toIso8601String()}"}]';
    final response = await _api.post(
      'Scan/save_scan_users',
      token: token,
      fields: {
        'majlis_id': majlisId,
        'users': users,
      },
    );
    if (response is Map<String, dynamic>) {
      return response['status']?.toString() == 'done'
          ? 'Scanned successfully.'
          : (response['message']?.toString() ?? 'Scanned successfully.');
    }
    return 'Scanned successfully.';
  }

  Future<int> getSabaqEligibleCount({
    required String token,
    required String sabaqId,
  }) async {
    try {
      final response = await _api.get('Sabaq/itsList/$sabaqId', token: token);
      if (response is Map<String, dynamic> && response['data'] is List) {
        return (response['data'] as List).length;
      }
    } catch (_) {}
    return 0;
  }

  Future<ScanCounts> getAsbaqCounts({
    required String token,
    required String asbaqId,
  }) async {
    try {
      final response = await _api.get(
        'Asbaq/get_total_counts/$asbaqId',
        token: token,
        asbaq: true,
      );
      if (response is Map<String, dynamic>) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          return ScanCounts.fromJson(data);
        }
      }
    } catch (_) {}
    return const ScanCounts();
  }

  Future<int> getAsbaqEligibleCount({
    required String token,
    required String asbaqId,
  }) async {
    try {
      final response = await _api.get(
        'Asbaq/scan_totals/$asbaqId',
        token: token,
        asbaq: true,
      );
      if (response is Map<String, dynamic>) {
        final totalIts = response['totalIts'];
        if (totalIts is num) return totalIts.toInt();
        return int.tryParse('${totalIts ?? ''}') ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<String> saveAsbaqScan({
    required String token,
    required String asbaqId,
    required String its,
  }) async {
    final users = '[{"its":"$its"}]';
    final response = await _api.post(
      'Asbaq/save_scan_users',
      token: token,
      asbaq: true,
      fields: {
        'asbaq_id': asbaqId,
        'users': users,
      },
    );
    if (response is Map<String, dynamic>) {
      final code = response['code']?.toString();
      if (code == '200') {
        return 'Scanned successfully.';
      }
      return response['message']?.toString() ?? 'Scanned successfully.';
    }
    return 'Scanned successfully.';
  }
}
