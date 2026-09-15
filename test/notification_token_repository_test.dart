import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tmk_kuwait/core/network/api_client.dart';
import 'package:tmk_kuwait/features/notifications/data/notification_token_repository.dart';

void main() {
  test('NotificationTokenRepository sends correct fields to API and handles "added"', () async {
    String? postedPath;
    Map<String, String>? postedBody;

    final mockClient = MockClient((request) async {
      postedPath = request.url.path;
      postedBody = request.bodyFields;
      return http.Response('added', 200, headers: {'content-type': 'text/html'});
    });

    final apiClient = ApiClient(client: mockClient);
    final repo = NotificationTokenRepository(apiClient: apiClient);

    await repo.register(itsId: '12345678', token: 'fcm_test_token_abc123');

    expect(postedPath, contains('/apis/notification_token'));
    expect(postedBody, isNotNull);
    expect(postedBody!['ejamaat_id'], equals('12345678'));
    expect(postedBody!['token'], equals('fcm_test_token_abc123'));
  });

  test('NotificationTokenRepository ignores empty parameters', () async {
    var callCount = 0;
    final mockClient = MockClient((request) async {
      callCount++;
      return http.Response('added', 200);
    });

    final repo = NotificationTokenRepository(apiClient: ApiClient(client: mockClient));

    await repo.register(itsId: '', token: 'valid_token');
    await repo.register(itsId: '12345678', token: '');
    await repo.register(itsId: '   ', token: '   ');

    expect(callCount, equals(0));
  });
}
