// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:hcm_explorer/main.dart';

void main() {
  testWidgets('home screen shows the main sections',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SaigonExplorerApp());

    expect(find.text('Saigon Explorer'), findsOneWidget);
    expect(find.text('Tourist Places'), findsOneWidget);
    expect(find.text('Vietnamese Phrases'), findsOneWidget);
    expect(find.text('Local Food'), findsOneWidget);
  });
}
