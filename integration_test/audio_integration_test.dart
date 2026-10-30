import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tempo_tune/core/audio/audio_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native output emits ordered beats at 60, 120 and 180 BPM', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Native audio verification')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final audio = AudioEngine();
      for (final bpm in [60.0, 120.0, 180.0]) {
        final times = <int>[];
        final beats = <int>[];
        final clock = Stopwatch()..start();
        final done = Completer<void>();
        final sub = audio.stream.listen((e) {
          if (e['type'] == 'beat') {
            times.add(clock.elapsedMicroseconds);
            beats.add(e['beat'] as int);
            if (times.length == 5 && !done.isCompleted) done.complete();
          }
        }, onError: done.completeError);
        try {
          await audio.configure({
            'bpm': bpm,
            'beats': 4,
            'denominator': 4,
            'volume': 0.05,
            'sound': 'wood',
            'muted': <int>[],
            'accent': true,
          });
          await audio.start();
          await done.future.timeout(const Duration(seconds: 8));
          expect(beats.take(5), [0, 1, 2, 3, 0]);
          final measured = (times[4] - times[1]) / 3 / 1000000;
          expect(measured, closeTo(60 / bpm, .10));
          // UI-delivered callback timing only; hardware output latency is not measured.
          // ignore: avoid_print
          print('Native $bpm BPM: callback interval $measured seconds');
        } finally {
          await audio.stop();
          await sub.cancel();
        }
      }
    });
  });
  testWidgets('Native microphone returns 4096 actual PCM samples', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Native audio verification')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final audio = AudioEngine();
      final done = Completer<List<dynamic>>();
      final sub = audio.stream.listen((e) {
        if (e['type'] == 'pcm' && !done.isCompleted) {
          done.complete(e['samples'] as List);
        }
      }, onError: done.completeError);
      try {
        await audio.startMic();
        final samples = await done.future.timeout(const Duration(seconds: 8));
        expect(samples.length, 4096);
        expect(samples.every((v) => v is num && v.isFinite), true);
      } finally {
        await audio.stopMic();
        await sub.cancel();
      }
    });
  });
}
