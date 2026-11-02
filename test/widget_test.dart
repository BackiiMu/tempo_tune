import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempo_tune/app/app.dart';
import 'package:tempo_tune/core/storage/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BPM controls persist and tab measurement uses real taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppState(await SharedPreferences.getInstance());
    const channel = MethodChannel('tempotune/audio');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => null,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('tempotune/events'),
      (_) async => null,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWithValue(store)],
        child: const TempoTuneApp(),
      ),
    );
    expect(find.text('120'), findsOneWidget);
    expect(
      tester.getRect(find.widgetWithText(FilledButton, '연습 시작')).bottom,
      lessThan(tester.getTopLeft(find.byType(NavigationBar)).dy),
    );
    await tester.tap(find.text('+5'));
    await tester.pump();
    expect(store.bpm, 125);
    await tester.tap(find.text('탭 템포'));
    await tester.pumpAndSettle();
    expect(find.text('TAP'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
    await tester.ensureVisible(find.text('TAP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TAP'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.text('튜너'));
    await tester.pumpAndSettle();
    expect(find.text('아직 감지된 음이 없어요'), findsOneWidget);
    expect(find.text('마이크 켜기'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('1번줄 · E4'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1번줄 · E4'));
    await tester.pumpAndSettle();
    expect(find.text('기본 튜닝 (Standard)'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('6번줄 · E2')).dy,
      lessThan(tester.getTopLeft(find.text('1번줄 · E4')).dy),
    );
    await tester.tap(find.text('1번줄 · E4'));
    await tester.pump();
    expect(
      tester
          .widget<ChoiceChip>(
            find.ancestor(
              of: find.text('1번줄 · E4'),
              matching: find.byType(ChoiceChip),
            ),
          )
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('Settings and custom tunings survive reload', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final state = AppState(p);
    await state.set('bpm', 143.0);
    await state.set('customTunings', [
      {
        'instrument': '사용자 정의',
        'name': 'Test',
        'notes': [38, 45, 50, 55, 59, 64],
      },
    ]);
    final restored = AppState(p);
    expect(restored.bpm, 143);
    expect(restored.customTunings.single.notes.first, 38);
  });
  test(
    'Tuning memory can be disabled without losing the current selection',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AppState(prefs);
      await store.set('tuning', '4현 베이스/Drop D');
      await store.set('rememberTuning', false);
      expect(store.get('tuning', ''), '4현 베이스/Drop D');
      expect(AppState(prefs).get('tuning', '6현 기타/Standard'), '6현 기타/Standard');
      await store.reset();
      expect(store.data, isEmpty);
    },
  );
}
