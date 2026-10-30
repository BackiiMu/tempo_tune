import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tempo_tune/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Practice screens render and navigate on iOS', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.text('나만의 리듬을 찾아요.'), findsOneWidget);
    await binding.takeScreenshot('metronome');
    await tester.tap(find.text('탭 템포'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('tap-tempo');
    await tester.tap(find.text('튜너'));
    await tester.pumpAndSettle();
    expect(find.text('아직 감지된 음이 없어요'), findsOneWidget);
    await binding.takeScreenshot('tuner');
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('settings');
  });
}
