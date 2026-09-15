import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tmk_kuwait/main.dart';

void main() {
  testWidgets('TMK app boots to login', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TmkApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Login with ITS'), findsOneWidget);
  });
}
