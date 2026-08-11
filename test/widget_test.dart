import 'package:flutter_test/flutter_test.dart';
import 'package:labeeb_wep/main.dart'; // مسار المشروع الخاص بك

void main() {
  testWidgets('Labeeb App Gate Load Test', (WidgetTester tester) async {
    // 1. بناء التطبيق باستخدام الاسم الصحيح للكلاس MyApp
    await tester.pumpWidget(const MyApp());

    // انتهاء عمليات التوجيه وبناء الشاشات المبدئية
    await tester.pumpAndSettle();

    // 2. التحقق من تحميل التطبيق بنجاح
    expect(find.byType(MyApp), findsOneWidget);
  });
}