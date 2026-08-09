import '../../../core/network/api_client.dart';

class FeedbackRepository {
  FeedbackRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<String> submit({
    required String token,
    required String subject,
    required String message,
  }) async {
    final response = await _api.post(
      'Feedback/submit',
      token: token,
      style: AuthHeaderStyle.xJwtToken,
      fields: {
        'subject': subject,
        'message': message,
      },
    );
    if (response is Map<String, dynamic>) {
      return response['message']?.toString() ??
          'Thank you. Your feedback has been submitted.';
    }
    return 'Thank you. Your feedback has been submitted.';
  }
}
