import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cozy_focus_app/main.dart';

void main() {
  testWidgets('App smoke test initializes', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CozyFocusApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('记录'), findsOneWidget);
    expect(find.text('成长'), findsOneWidget);
  });
}
