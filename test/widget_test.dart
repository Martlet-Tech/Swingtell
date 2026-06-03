import 'package:flutter_test/flutter_test.dart';
import 'package:epub_reader/app.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('SwingTell 阅读器'), findsOneWidget);
  });
}
