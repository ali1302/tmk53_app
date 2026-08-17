import 'dart:convert';

import '../../../core/models/app_models.dart';
import '../../../core/network/api_client.dart';

class IzanMember {
  const IzanMember({
    required this.its,
    required this.name,
    this.gender = '',
    this.misaq = '',
    this.hofId = '',
    this.registered = false,
    this.persistedRegistered = false,
  });

  final String its;
  final String name;
  final String gender;
  final String misaq;
  final String hofId;

  /// Draft toggle state (may differ from server until Save).
  final bool registered;

  /// Last confirmed registration from the server.
  final bool persistedRegistered;

  bool get isHof => hofId.isNotEmpty && its == hofId;

  IzanMember copyWith({bool? registered, bool? persistedRegistered}) {
    return IzanMember(
      its: its,
      name: name,
      gender: gender,
      misaq: misaq,
      hofId: hofId,
      registered: registered ?? this.registered,
      persistedRegistered: persistedRegistered ?? this.persistedRegistered,
    );
  }

  factory IzanMember.fromJson(Map<String, dynamic> json, {bool? registered}) {
    final its = '${json['ejamaat_id'] ?? json['its'] ?? ''}'.trim();
    final hofId = '${json['hof_id'] ?? ''}'.trim();
    final rawReg = json['registered'];
    final fromRow = rawReg == true ||
        rawReg == 1 ||
        '$rawReg' == '1' ||
        '$rawReg' == 'true';
    final isReg = registered ?? fromRow;
    return IzanMember(
      its: its,
      name: '${json['its_name'] ?? json['name'] ?? ''}'.trim(),
      gender: '${json['gender'] ?? ''}'.trim(),
      misaq: '${json['misaq'] ?? ''}'.trim(),
      hofId: hofId,
      registered: isReg,
      persistedRegistered: isReg,
    );
  }
}

class IzanGuest {
  const IzanGuest({
    required this.its,
    required this.name,
    this.gender = 'M',
    this.misaq = 'Done',
    this.persisted = false,
  });

  final String its;
  final String name;
  final String gender;
  final String misaq;

  /// True after the guest is saved on the server.
  final bool persisted;

  Map<String, String> toJson() => {
        'its': its.trim(),
        'name': name.trim(),
        'gender': gender.trim(),
        'misaq': misaq.trim(),
      };

  factory IzanGuest.fromJson(Map<String, dynamic> json) {
    return IzanGuest(
      its: '${json['its'] ?? ''}',
      name: '${json['name'] ?? ''}',
      gender: '${json['gender'] ?? 'M'}',
      misaq: '${json['misaq'] ?? 'Done'}',
      persisted: true,
    );
  }

  IzanGuest copyWith({
    String? its,
    String? name,
    String? gender,
    String? misaq,
    bool? persisted,
  }) {
    return IzanGuest(
      its: its ?? this.its,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      misaq: misaq ?? this.misaq,
      persisted: persisted ?? this.persisted,
    );
  }
}

class IzanDetail {
  const IzanDetail({
    this.majlis,
    this.members = const [],
    this.guests = const [],
    this.onlyHof = false,
  });

  final MajlisItem? majlis;
  final List<IzanMember> members;
  final List<IzanGuest> guests;
  final bool onlyHof;
}

class IzanRepository {
  IzanRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<MajlisItem>> listActive({
    required String token,
    required String itsId,
  }) async {
    List<MajlisItem> list = const [];
    try {
      final response = await _api.get(
        'Majlis/list',
        token: token,
        style: AuthHeaderStyle.xJwtToken,
      );
      list = _parseMajlisList(response);
    } on ApiException {
      // Fall back to legacy Apis when v1 is not deployed yet.
    }

    if (list.isEmpty) {
      final legacy = await _api.post(
        'majlis_list',
        fields: {'ejamaat_id': itsId},
        legacy: true,
        style: AuthHeaderStyle.none,
      );
      list = _parseMajlisList(legacy);
    }

    // Enrich Only-HOF from Home (already live) when list flag is missing.
    return _enrichOnlyHofFromHome(token: token, list: list);
  }

  Future<List<MajlisItem>> _enrichOnlyHofFromHome({
    required String token,
    required List<MajlisItem> list,
  }) async {
    if (list.isEmpty) return list;
    try {
      final response = await _api.get(
        'Home/get_home_details',
        token: token,
        style: AuthHeaderStyle.xJwtToken,
      );
      if (response is! Map) return list;
      final raw = response['majlis'];
      if (raw is! Map) return list;
      final homeMajlis = MajlisItem.fromJson(Map<String, dynamic>.from(raw));
      if (homeMajlis.id.isEmpty) return list;
      return [
        for (final m in list)
          if (m.id == homeMajlis.id && homeMajlis.onlyHof && !m.onlyHof)
            MajlisItem(
              id: m.id,
              title: m.title,
              date: m.date,
              hijriDate: m.hijriDate,
              onlyHof: true,
              passStatus: m.passStatus || homeMajlis.passStatus,
            )
          else
            m,
      ];
    } catch (_) {
      return list;
    }
  }

  Future<IzanDetail> getUsers({
    required String token,
    required String itsId,
    required String majlisId,
  }) async {
    // Prefer legacy first — deployed on live and does not require JWT.
    // v1 Majlis/users often returns "failed" when the token cookie is missing.
    try {
      final legacy = await _api.post(
        'get_majlis_user/$majlisId',
        fields: {'ejamaat_id': itsId.trim()},
        legacy: true,
        style: AuthHeaderStyle.none,
      );
      final detail = _parseDetail(legacy);
      if (detail.members.isNotEmpty) {
        return detail;
      }
    } on ApiException {
      // Fall through to v1.
    }

    final response = await _api.get(
      'Majlis/users/$majlisId',
      token: token,
      style: AuthHeaderStyle.xJwtToken,
    );
    return _parseDetail(response);
  }

  Future<String> register({
    required String token,
    required String itsId,
    required String majlisId,
    required Map<String, bool> selections,
    required List<IzanGuest> guests,
  }) async {
    // Always send ITS keys as plain strings so PHP lookup matches DB values.
    final dataMap = <String, dynamic>{
      for (final e in selections.entries)
        e.key.trim(): e.value ? 1 : 0,
      'mid': majlisId.trim(),
    };
    final dataJson = jsonEncode(dataMap);
    final guestsJson = jsonEncode(guests.map((g) => g.toJson()).toList());

    // Prefer legacy endpoint first — it is deployed on live and proven for RSVP.
    // Fall back to v1 Majlis/register when legacy is unavailable.
    try {
      final legacy = await _api.post(
        'majlis_registrations/$majlisId',
        fields: {
          'ejamaat_id': itsId.trim(),
          'data': dataJson,
          'guests': guestsJson,
        },
        legacy: true,
        style: AuthHeaderStyle.none,
        allowPlainText: true,
      );
      return _messageFrom(legacy, fallback: 'Registered Successfully');
    } on ApiException {
      // Fall through to v1.
    }

    final response = await _api.post(
      'Majlis/register/$majlisId',
      token: token,
      style: AuthHeaderStyle.xJwtToken,
      fields: {
        'data': dataJson,
        'guests': guestsJson,
      },
      allowPlainText: true,
    );
    return _messageFrom(response, fallback: 'Registered Successfully');
  }

  List<MajlisItem> _parseMajlisList(dynamic response) {
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((e) => MajlisItem.fromJson(Map<String, dynamic>.from(e)))
        .where((m) => m.id.isNotEmpty)
        .toList();
  }

  IzanDetail _parseDetail(dynamic response) {
    if (response is! Map) {
      return const IzanDetail();
    }
    final map = Map<String, dynamic>.from(response);
    MajlisItem? majlis;
    final rawMajlis = map['majlis'];
    if (rawMajlis is Map) {
      majlis = MajlisItem.fromJson(Map<String, dynamic>.from(rawMajlis));
    }

    final registerIds = <String, bool>{};
    final rawReg = map['register_ids'];
    if (rawReg is Map) {
      rawReg.forEach((key, value) {
        registerIds['$key'.trim()] =
            value == true || value == 1 || '$value' == '1' || '$value' == 'true';
      });
    }

    final members = <IzanMember>[];
    final rawUsers = map['user'];
    if (rawUsers is List) {
      for (final item in rawUsers.whereType<Map>()) {
        final m = Map<String, dynamic>.from(item);
        final its = '${m['ejamaat_id'] ?? m['its'] ?? ''}'.trim();
        final fromMap = registerIds[its];
        final fromRow = m['registered'] == true ||
            m['registered'] == 1 ||
            '${m['registered']}' == '1' ||
            '${m['registered']}' == 'true';
        members.add(
          IzanMember.fromJson(
            m,
            registered: fromMap ?? fromRow,
          ),
        );
      }
    }

    final guests = <IzanGuest>[];
    final rawGuests = map['guests'];
    if (rawGuests is List) {
      for (final item in rawGuests.whereType<Map>()) {
        guests.add(IzanGuest.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    final onlyHof = (majlis?.onlyHof ?? false) || _asBool(map['only_hof_status']);
    final passStatus =
        (majlis?.passStatus ?? false) || _asBool(map['pass_status']);
    final resolvedMajlis = majlis == null
        ? null
        : MajlisItem(
            id: majlis.id,
            title: majlis.title,
            date: majlis.date,
            hijriDate: majlis.hijriDate,
            onlyHof: onlyHof || majlis.onlyHof,
            passStatus: passStatus || majlis.passStatus,
          );

    return IzanDetail(
      majlis: resolvedMajlis,
      members: members,
      guests: guests,
      onlyHof: onlyHof,
    );
  }

  bool _asBool(dynamic value) {
    return value == true ||
        value == 1 ||
        '$value' == '1' ||
        '$value' == 'true';
  }

  String _messageFrom(dynamic response, {required String fallback}) {
    if (response is Map) {
      final success = response['success'];
      final msg = response['message']?.toString().trim() ?? '';
      if (success == false || msg.toLowerCase() == 'error' || msg.toLowerCase() == 'failed') {
        throw ApiException(
          statusCode: 400,
          message: msg.isNotEmpty && msg.toLowerCase() != 'error'
              ? msg
              : 'Unable to save registration.',
        );
      }
      final cleaned = msg.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      if (cleaned.isNotEmpty && !cleaned.contains('{') && cleaned.length < 160) {
        return cleaned;
      }
      return fallback;
    }
    if (response is String) {
      final t = response.trim().replaceAll(RegExp(r'<[^>]*>'), '').trim();
      final lower = t.toLowerCase();
      if (lower.contains('<html') || lower.contains('warning') || lower.contains('undefined')) {
        throw ApiException(statusCode: 500, message: 'Unable to save registration.');
      }
      if (t.isNotEmpty && t != 'error' && t != 'failed' && t.length < 160 && !t.contains('{')) {
        return t;
      }
      if (t == 'error' || t == 'failed') {
        throw ApiException(statusCode: 400, message: 'Unable to save registration.');
      }
    }
    return fallback;
  }
}
