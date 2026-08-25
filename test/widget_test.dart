// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sentinel_hub/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App loads kTsentinel command center', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SentinelApp());

    expect(find.bySemanticsLabel('kTsentinel logo'), findsOneWidget);
  });

  testWidgets('Home screen shows empty state when no cameras are registered',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SentinelApp());
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma câmera cadastrada'), findsOneWidget);
  });
}
