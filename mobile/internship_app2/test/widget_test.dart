// Basic widget test for Qadam app

import 'package:flutter_test/flutter_test.dart';
import 'package:internship_app2/main.dart';

void main() {
  testWidgets('App launches and shows auth screen', (WidgetTester tester) async {
    await tester.pumpWidget(const QadamApp());

    expect(find.text('Qadam'), findsWidgets);
  });
}
