import '../../../core/network/api_client.dart';

class NotificationTokenRepository {
  NotificationTokenRepository({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  /// Registers / updates the Expo (or device) push token for this ITS id.
  Future<void> register({
    required String itsId,
    required String token,
  }) async {
    final cleanedIts = itsId.trim();
    final cleanedToken = token.trim();
    if (cleanedIts.isEmpty || cleanedToken.isEmpty) return;

    await _api.post(
      'notification_token',
      legacy: true,
      allowPlainText: true,
      fields: {
        'ejamaat_id': cleanedIts,
        'token': cleanedToken,
      },
    );
  }
}
