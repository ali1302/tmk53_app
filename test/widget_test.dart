import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_kuwait/main.dart';

void main() {
  testWidgets('TMK app boots to login', (WidgetTester tester) async {
    await tester.pumpWidget(const TmkApp());
    await tester.pump();

    expect(find.text('TMK 53'), findsWidgets);
  });
}
