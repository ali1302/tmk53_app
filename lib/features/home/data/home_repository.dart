import '../../../core/models/app_models.dart';
import '../../../core/network/api_client.dart';

class HomeRepository {
  HomeRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<HomeDetails> getHomeDetails({
    required String token,
    required String itsId,
  }) async {
    HomeDetails? primary;

    try {
      final response = await _api.get(
        'Home/get_home_details',
        token: token,
        style: AuthHeaderStyle.xJwtToken,
      );
      final map = _asMap(response);
      if (map != null) {
        primary = HomeDetails.fromJson(map);
      }
    } on ApiException {
      // Fall through to legacy endpoint.
    }

    // Prefer primary when it already has dues; otherwise try legacy merge.
    if (primary != null && primary.dues.isNotEmpty) {
      return primary;
    }

    try {
      final legacy = await _api.post(
        'get_home_details',
        fields: {'ejamaat_id': itsId},
        legacy: true,
        style: AuthHeaderStyle.none,
      );
      final map = _asMap(legacy);
      if (map != null) {
        final fromLegacy = HomeDetails.fromJson(map);
        if (primary == null) {
          return fromLegacy;
        }
        if (fromLegacy.dues.isNotEmpty) {
          return primary.copyWith(dues: fromLegacy.dues);
        }
        return primary;
      }
    } on ApiException {
      if (primary != null) return primary;
      rethrow;
    }

    if (primary != null) return primary;
    throw ApiException(statusCode: 500, message: 'Unable to load home details.');
  }

  Future<String> getQrUrl({required String token}) async {
    final response = await _api.get(
      'Qr',
      token: token,
      style: AuthHeaderStyle.xJwtToken,
      allowPlainText: true,
    );
    return response.toString();
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return {
        for (final entry in value.entries) entry.key.toString(): entry.value,
      };
    }
    return null;
  }
}
