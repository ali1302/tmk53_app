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

  Future<List<ScannedUser>> getScannedUsersByUser({
    required String token,
    required ScanEvent event,
  }) async {
    if (event.category == 'Majlis') {
      final response = await _api.get(
        'Scan/get_its_scanned_list_by_user/${event.id}',
        token: token,
      );
      return _parseScannedList(response);
    }
    if (event.category == 'Asbaq') {
      final response = await _api.get(
        'Asbaq/get_its_scanned_list_by_user/${event.id}',
        token: token,
        asbaq: true,
      );
      return _parseScannedList(response);
    }
    return const [];
  }

  List<ScannedUser> _parseScannedList(dynamic response) {
    if (response is! Map<String, dynamic>) return const [];
    final data = response['data'];
    if (data is! List) return const [];
    final users = <ScannedUser>[];
    for (final item in data) {
      if (item is Map) {
        final user = ScannedUser.fromJson(Map<String, dynamic>.from(item));
        if (user.its.isNotEmpty) users.add(user);
      }
    }
    users.sort((a, b) {
      final aAt = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bAt.compareTo(aAt);
    });
    return users;
  }

  String _nameFromScanned(dynamic response, String its) {
    if (response is! Map<String, dynamic>) return '';
    final scanned = response['scanned'];
    if (scanned is List) {
      for (final item in scanned) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          if ('${map['its'] ?? ''}' == its) {
            final name = '${map['name'] ?? map['its_name'] ?? ''}'.trim();
            if (name.isNotEmpty) return name;
          }
        }
      }
      if (scanned.isNotEmpty && scanned.first is Map) {
        final map = Map<String, dynamic>.from(scanned.first as Map);
        final name = '${map['name'] ?? map['its_name'] ?? ''}'.trim();
        if (name.isNotEmpty) return name;
      }
    }
    return '';
  }

  Map<String, dynamic>? _scannedItem(dynamic response, String its) {
    if (response is! Map<String, dynamic>) return null;
    final scanned = response['scanned'];
    if (scanned is! List) return null;
    for (final item in scanned) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        if ('${map['its'] ?? ''}' == its) return map;
      }
    }
    if (scanned.isNotEmpty && scanned.first is Map) {
      return Map<String, dynamic>.from(scanned.first as Map);
    }
    return null;
  }

  ScanUserKind _kindFromScanned(dynamic response, String its, String name) {
    final map = _scannedItem(response, its);
    return parseScanUserKind(
      scanKind: map == null ? '' : '${map['scan_kind'] ?? ''}',
      statusLabel: map == null ? '' : '${map['status_label'] ?? ''}',
      name: name,
    );
  }

  String _statusLabelFromScanned(dynamic response, String its) {
    final map = _scannedItem(response, its);
    return map == null ? '' : '${map['status_label'] ?? ''}'.trim();
  }

  bool _alreadyFromResponse(dynamic response, String its) {
    if (response is! Map<String, dynamic>) return false;
    final flag = response['already_scanned'];
    if (flag == true || flag == 1 || '$flag' == '1' || '$flag'.toLowerCase() == 'true') {
      return true;
    }
    final status = '${response['status'] ?? ''}'.toLowerCase();
    if (status == 'present') return true;
    final message = '${response['message'] ?? ''}'.toLowerCase();
    if (message.contains('already')) return true;
    final scanned = response['scanned'];
    if (scanned is List) {
      for (final item in scanned) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          if ('${map['its'] ?? ''}' == its) {
            final itemStatus = '${map['status'] ?? ''}'.toLowerCase();
            if (itemStatus == 'present') return true;
            final already = map['already_scanned'];
            if (already == true || already == 1 || '$already' == '1') return true;
          }
        }
      }
    }
    return false;
  }

  String _messageFromResponse(dynamic response, {required bool already}) {
    if (response is Map<String, dynamic>) {
      final message = response['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    return already ? 'ITS is already scanned.' : 'Scanned successfully.';
  }

  Future<ScanSubmitResult> registerSabaq({
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
      final already = _alreadyFromResponse(response, its);
      return ScanSubmitResult(
        message: _messageFromResponse(response, already: already),
        its: its,
        name: _nameFromScanned(response, its),
        alreadyScanned: already,
      );
    }
    return ScanSubmitResult(message: 'Scanned successfully.', its: its);
  }

  Future<ScanSubmitResult> registerGeneral({
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
      final already = _alreadyFromResponse(response, its);
      return ScanSubmitResult(
        message: _messageFromResponse(response, already: already),
        its: its,
        name: _nameFromScanned(response, its),
        alreadyScanned: already,
      );
    }
    return ScanSubmitResult(message: 'Scanned successfully.', its: its);
  }

  Future<ScanSubmitResult> saveMajlisScan({
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
      final already = _alreadyFromResponse(response, its);
      final name = _nameFromScanned(response, its);
      return ScanSubmitResult(
        message: _messageFromResponse(response, already: already),
        its: its,
        name: name,
        alreadyScanned: already,
        kind: _kindFromScanned(response, its, name),
        statusLabel: _statusLabelFromScanned(response, its),
      );
    }
    return ScanSubmitResult(message: 'Scanned successfully.', its: its);
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

  Future<int> getMajlisRegisteredCount({
    required String token,
    required String majlisId,
  }) async {
    try {
      final response = await _api.get(
        'Scan/get_majlis_registration_list/$majlisId',
        token: token,
      );
      if (response is Map<String, dynamic>) {
        final data = response['data'];
        if (data is List) return data.length;
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

  Future<ScanSubmitResult> saveAsbaqScan({
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
      final already = _alreadyFromResponse(response, its);
      final name = _nameFromScanned(response, its);
      return ScanSubmitResult(
        message: _messageFromResponse(response, already: already),
        its: its,
        name: name,
        alreadyScanned: already,
        kind: _kindFromScanned(response, its, name),
        statusLabel: _statusLabelFromScanned(response, its),
      );
    }
    return ScanSubmitResult(message: 'Scanned successfully.', its: its);
  }

  Future<String> removeScan({
    required String token,
    required ScanEvent event,
    required String its,
  }) async {
    Future<dynamic> postRemove({
      required String path,
      required Map<String, String> fields,
      bool asbaq = false,
    }) {
      return _api.post(
        path,
        token: token,
        asbaq: asbaq,
        fields: fields,
      );
    }

    late final dynamic response;
    if (event.category == 'Asbaq') {
      try {
        response = await postRemove(
          path: 'Asbaq/remove_scan_user',
          asbaq: true,
          fields: {
            'asbaq_id': event.id,
            'its': its,
          },
        );
      } on ApiException {
        // Older servers may only support action=remove on save_scan_users.
        response = await postRemove(
          path: 'Asbaq/save_scan_users',
          asbaq: true,
          fields: {
            'asbaq_id': event.id,
            'its': its,
            'action': 'remove',
            'users': '[]',
          },
        );
      }
    } else if (event.category == 'Majlis') {
      try {
        response = await postRemove(
          path: 'Scan/remove_scan_user',
          fields: {
            'majlis_id': event.id,
            'its': its,
          },
        );
      } on ApiException {
        response = await postRemove(
          path: 'Scan/save_scan_users',
          fields: {
            'majlis_id': event.id,
            'its': its,
            'action': 'remove',
            'users': '[]',
          },
        );
      }
    } else if (event.category == 'Sabaq') {
      response = await postRemove(
        path: 'Sabaq/remove',
        fields: {
          'sabaq_id': event.id,
          'its': its,
        },
      );
    } else if (event.category == 'General') {
      response = await postRemove(
        path: 'Generalscan/remove',
        fields: {
          'generalscan_id': event.id,
          'its': its,
        },
      );
    } else {
      throw ApiException(statusCode: 400, message: 'Remove not supported for this event.');
    }

    if (response is! Map<String, dynamic>) {
      throw ApiException(
        statusCode: 500,
        message: 'Unable to remove scan from server.',
      );
    }

    final status = '${response['status'] ?? ''}'.toLowerCase();
    final message = response['message']?.toString() ?? '';
    final code = '${response['code'] ?? ''}';
    final removed = status == 'removed' ||
        message.toLowerCase().contains('removed') ||
        (code == '200' &&
            (event.category == 'Sabaq' || event.category == 'General'));

    if (!removed) {
      if (event.category == 'Asbaq' || event.category == 'Majlis') {
        throw ApiException(
          statusCode: 409,
          message:
              'Server did not remove this ITS. Upload the latest Scan/Asbaq API files, then try again.',
        );
      }
      throw ApiException(
        statusCode: 500,
        message: message.isNotEmpty ? message : 'Unable to remove scan from server.',
      );
    }

    return message.isNotEmpty ? message : 'ITS removed from scanned list.';
  }
}
