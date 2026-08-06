import '../../../core/models/app_models.dart';
import '../../../core/network/api_client.dart';

class BroadcastRepository {
  BroadcastRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<BroadcastItem>> list(String itsId) async {
    final response = await _api.get(
      'broadcast_list/$itsId',
      legacy: true,
      style: AuthHeaderStyle.none,
    );

    if (response is! List) {
      return const [];
    }

    return response
        .whereType<Map>()
        .map((e) => BroadcastItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
