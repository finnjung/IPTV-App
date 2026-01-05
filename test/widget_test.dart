import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const IPTVApp());
    expect(find.text('Live TV'), findsOneWidget);
  });
}
