import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:tempo_tune/features/tap_tempo/domain/tap_tracker.dart';
import 'package:tempo_tune/features/tuner/domain/pitch.dart';
import 'package:tempo_tune/features/tuner/data/tunings.dart';

void main() {
  test('Tap tempo 500 / 600 / 750 ms, debounce, reset, tempo changes', () {
    for (final entry in {500: 120, 600: 100, 750: 80}.entries) {
      final t = TapTracker();
      for (var i = 0; i < 8; i++) {
        t.tap(i * entry.key);
      }
      expect(t.bpm, closeTo(entry.value, .001));
    }
    final t = TapTracker();
    t.tap(0);
    expect(t.bpm, isNull);
    expect(t.tap(20), false);
    t.tap(500);
    expect(t.bpm, 120);
    t.tap(5000);
    expect(t.count, 1);
    expect(t.bpm, isNull);
    for (var i = 1; i <= 8; i++) {
      t.tap(5000 + i * 600);
    }
    expect(t.bpm, closeTo(100, .01));
  });
  test('Tap outlier rejection and sustained change', () {
    final t = TapTracker();
    for (final ms in [0, 500, 1000, 1500, 2200, 2700, 3200]) {
      t.tap(ms);
    }
    expect(t.bpm, closeTo(120, .01));
    for (var i = 1; i < 10; i++) {
      t.tap(3200 + i * 300);
    }
    expect(t.bpm, closeTo(200, .01));
  });
  test('Idle tap session expires without a new tap', () {
    final tracker = TapTracker()
      ..tap(0)
      ..tap(500);
    expect(tracker.expire(3500), false);
    expect(tracker.expire(3501), true);
    expect(tracker.count, 0);
    expect(tracker.bpm, isNull);
  });
  test('YIN runs in the same worker-isolate path as live PCM', () async {
    final samples = List.generate(
      4096,
      (i) => .4 * sin(2 * pi * 41.2034 * i / 12000),
    );
    final pitch = await compute(detectPitch, samples);
    expect(pitch, isNotNull);
    expect(centsBetween(pitch!.frequency, 41.2034).abs(), lessThan(2));
  });
  test('Known cents values and note names', () {
    expect(centsBetween(440, 440), 0);
    expect(centsBetween(442, 440), closeTo(7.85, .01));
    expect(centsBetween(432, 440), closeTo(-31.77, .01));
    expect(noteName(nearestMidi(440, 440)), 'A4');
    expect(noteName(39, flats: true), 'E♭2');
  });
  for (final hz in [30.8677, 41.2034, 82.4069, 432.0, 440.0, 442.0, 880.0]) {
    test('YIN detects generated $hz Hz sine within 2 cents', () {
      final samples = List.generate(
        4096,
        (i) => .4 * sin(2 * pi * hz * i / 12000),
      );
      final p = detectPitch(samples);
      expect(p, isNotNull);
      expect(centsBetween(p!.frequency, hz).abs(), lessThan(2));
      expect(p.confidence, greaterThan(.9));
    });
  }
  test('YIN silence, noise, harmonics, low input rejection', () {
    expect(detectPitch(List.filled(4096, 0)), isNull);
    final r = Random(17);
    expect(
      detectPitch(List.generate(4096, (_) => (r.nextDouble() - .5) * .1)),
      isNull,
    );
    expect(
      detectPitch(
        List.generate(4096, (i) => .001 * sin(2 * pi * 440 * i / 12000)),
      ),
      isNull,
    );
    final samples = List.generate(
      4096,
      (i) =>
          .2 * sin(2 * pi * 82.4069 * i / 12000) +
          .3 * sin(2 * pi * 164.8138 * i / 12000) +
          .1 * sin(2 * pi * 247.2207 * i / 12000) +
          (r.nextDouble() - .5) * .01,
    );
    final p = detectPitch(samples);
    expect(p, isNotNull);
    expect(centsBetween(p!.frequency, 82.4069).abs(), lessThan(3));
  });
  test('All 18 tuning definitions and reentrant ukulele order', () {
    expect(tunings.length, 18);
    expect(tunings.where((t) => t.instrument == '6현 기타').length, 8);
    for (final t in tunings) {
      expect(t.notes.every((n) => n >= 23 && n <= 69), true);
      if (t.instrument != '우쿨렐레') {
        expect([...t.notes]..sort(), t.notes);
      }
      for (final n in t.notes) {
        expect(nearestMidi(midiFrequency(n, 440), 440), n);
      }
    }
    expect(tunings.firstWhere((t) => t.name == 'Standard High G').notes, [
      67,
      60,
      64,
      69,
    ]);
  });
}
