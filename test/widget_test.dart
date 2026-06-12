import 'package:flutter_test/flutter_test.dart';
import 'package:docflow/app.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const PLocketApp());
    expect(find.text('pLOCKet'), findsOneWidget);
  });
}
