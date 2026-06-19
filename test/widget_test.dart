import 'package:flutter_test/flutter_test.dart';
import 'package:cyber_ex/app.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const CyberExApp());
    // 验证应用启动后显示加载指示器
    expect(find.byType(CyberExApp), findsOneWidget);
  });
}
