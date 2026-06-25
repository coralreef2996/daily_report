import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:daily_report/main.dart';

void main() {
  testWidgets('Initial screen load test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Verify that the initial question is shown.
    expect(find.text('今日1日はどんな日でしたか？'), findsOneWidget);
  });
}
