import 'package:flutter_test/flutter_test.dart';
import 'package:internship_app/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const InternshipApp());
    expect(find.text('Internships (Kazakhstan)'), findsOneWidget);
  });
}
