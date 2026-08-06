import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

enum AuthHeaderStyle { bearer, xJwtToken, none }

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(
    String path, {
    bool legacy = false,
    bool asbaq = false,
    Map<String, String>? query,
  }) {
    final root = asbaq
        ? AppConfig.asbaqApiBaseUrl
        : (legacy ? AppConfig.legacyApiBaseUrl : AppConfig.apiBaseUrl);
    final cleaned = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$root/$cleaned').replace(queryParameters: query);
  }

  Map<String, String> _headers({
    String? token,
    AuthHeaderStyle style = AuthHeaderStyle.bearer,
    bool form = false,
  }) {
    return {
      'Accept': 'application/json',
      if (form) 'Content-Type': 'application/x-www-form-urlencoded',
      if (token != null && token.isNotEmpty) ...{
        if (style == AuthHeaderStyle.bearer) 'Authorization': 'Bearer $token',
        if (style == AuthHeaderStyle.xJwtToken) 'X-JWT-TOKEN': token,
      },
    };
  }

  Future<dynamic> post(
    String path, {
    Map<String, String>? fields,
    String? token,
    AuthHeaderStyle style = AuthHeaderStyle.bearer,
    bool legacy = false,
    bool asbaq = false,
    bool allowPlainText = false,
  }) async {
    try {
      final response = await _client.post(
        _uri(path, legacy: legacy, asbaq: asbaq),
        headers: _headers(token: token, style: style, form: true),
        body: fields,
      );
      return _decode(response, allowPlainText: allowPlainText);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error talking to TMK server. ${e.runtimeType}',
      );
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    String? token,
    AuthHeaderStyle style = AuthHeaderStyle.bearer,
    bool legacy = false,
    bool asbaq = false,
    bool allowPlainText = false,
  }) async {
    try {
      final response = await _client.get(
        _uri(path, legacy: legacy, asbaq: asbaq, query: query),
        headers: _headers(token: token, style: style),
      );
      return _decode(response, allowPlainText: allowPlainText);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error talking to TMK server. ${e.runtimeType}',
      );
    }
  }

  dynamic _decode(http.Response response, {bool allowPlainText = false}) {
    final raw = response.body.trim();
    if (raw.isEmpty) {
      throw ApiException(statusCode: response.statusCode, message: 'Empty response from server.');
    }

    if (raw == 'failed') {
      throw ApiException(statusCode: 401, message: 'Authentication failed.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      if (allowPlainText || response.statusCode >= 200 && response.statusCode < 300) {
        return raw;
      }
      throw ApiException(
        statusCode: response.statusCode,
        message: raw.length > 120 ? 'Unexpected response from server.' : raw,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractMessage(decoded) ?? 'Request failed.',
        payload: decoded is Map<String, dynamic> ? decoded : null,
      );
    }

    if (decoded is Map<String, dynamic>) {
      final code = decoded['code']?.toString();
      final error = decoded['error']?.toString();
      if (error != null && error.isNotEmpty && code != '200') {
        throw ApiException(
          statusCode: response.statusCode,
          message: _extractMessage(decoded) ?? error,
          payload: decoded,
        );
      }
    }

    return decoded;
  }

  String? _extractMessage(dynamic json) {
    if (json is! Map) return null;
    final message = json['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }
    return null;
  }
}

class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.payload,
  });

  final int statusCode;
  final String message;
  final Map<String, dynamic>? payload;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
