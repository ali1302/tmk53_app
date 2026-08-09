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
  });

  final String its;
  final String name;
  final String gender;
  final String misaq;
  final String hofId;
  final bool registered;

  bool get isHof => hofId.isNotEmpty && its == hofId;

  IzanMember copyWith({bool? registered}) {
    return IzanMember(
      its: its,
      name: name,
      gender: gender,
      misaq: misaq,
      hofId: hofId,
      registered: registered ?? this.registered,
    );
  }

  factory IzanMember.fromJson(Map<String, dynamic> json, {bool? registered}) {
    return IzanMember(
      its: '${json['ejamaat_id'] ?? json['its'] ?? ''}',
      name: '${json['its_name'] ?? json['name'] ?? ''}',
      gender: '${json['gender'] ?? ''}',
      misaq: '${json['misaq'] ?? ''}',
      hofId: '${json['hof_id'] ?? ''}',
      registered: registered ??
          json['registered'] == true ||
              json['registered'] == 1 ||
              '${json['registered']}' == 'true',
    );
  }
}

class IzanGuest {
  const IzanGuest({
    required this.its,
    required this.name,
    this.gender = 'M',
    this.misaq = 'Done',
  });

  final String its;
  final String name;
  final String gender;
  final String misaq;

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
    );
  }

  IzanGuest copyWith({
    String? its,
    String? name,
    String? gender,
    String? misaq,
  }) {
    return IzanGuest(
      its: its ?? this.its,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      misaq: misaq ?? this.misaq,
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
    try {
      final response = await _api.get(
        'Majlis/users/$majlisId',
        token: token,
        style: AuthHeaderStyle.xJwtToken,
      );
      return _parseDetail(response);
    } on ApiException {
      // Fall through.
    }

    final legacy = await _api.post(
      'get_majlis_user/$majlisId',
      fields: {'ejamaat_id': itsId},
      legacy: true,
      style: AuthHeaderStyle.none,
    );
    return _parseDetail(legacy);
  }

  Future<String> register({
    required String token,
    required String itsId,
    required String majlisId,
    required Map<String, bool> selections,
    required List<IzanGuest> guests,
  }) async {
    final dataMap = <String, dynamic>{
      for (final e in selections.entries) e.key: e.value ? 1 : 0,
      'mid': majlisId,
    };
    final dataJson = jsonEncode(dataMap);
    final guestsJson = jsonEncode(guests.map((g) => g.toJson()).toList());

    try {
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
    } on ApiException {
      // Fall through to legacy.
    }

    final legacy = await _api.post(
      'majlis_registrations/$majlisId',
      fields: {
        'ejamaat_id': itsId,
        'data': dataJson,
        'guests': guestsJson,
      },
      legacy: true,
      style: AuthHeaderStyle.none,
      allowPlainText: true,
    );
    return _messageFrom(legacy, fallback: 'Registered Successfully');
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
        registerIds['$key'] =
            value == true || value == 1 || '$value' == 'true';
      });
    }

    final members = <IzanMember>[];
    final rawUsers = map['user'];
    if (rawUsers is List) {
      for (final item in rawUsers.whereType<Map>()) {
        final m = Map<String, dynamic>.from(item);
        final its = '${m['ejamaat_id'] ?? ''}';
        members.add(
          IzanMember.fromJson(
            m,
            registered: registerIds[its] ?? false,
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

    return IzanDetail(
      majlis: majlis,
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
      final msg = response['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    if (response is String) {
      final t = response.trim();
      if (t.isNotEmpty && t != 'error' && t != 'failed') return t;
      if (t == 'error' || t == 'failed') {
        throw ApiException(statusCode: 400, message: 'Unable to save registration.');
      }
    }
    return fallback;
  }
}
