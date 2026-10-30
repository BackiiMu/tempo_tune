import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audio_engine.dart';
import '../core/storage/app_state.dart';
import '../features/tap_tempo/domain/tap_tracker.dart';
import '../features/tuner/data/tunings.dart';
import '../features/tuner/domain/pitch.dart';

part '../features/metronome/presentation/metronome_page.dart';
part '../features/tap_tempo/presentation/tap_tempo_page.dart';
part '../features/tuner/presentation/tuner_page.dart';
part '../features/settings/presentation/settings_page.dart';

const blue = Color(0xff0075de),
    paper = Color(0xfff6f5f4),
    muted = Color(0xff615d59),
    line = Color(0xffe6e6e6);

class TempoTuneApp extends StatelessWidget {
  const TempoTuneApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TempoTune',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: blue,
        primary: blue,
        surface: Colors.white,
        secondary: blue,
        secondaryContainer: const Color(0xffe8f3fc),
        onSecondaryContainer: blue,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          color: Color(0xff171715),
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
        bodyMedium: TextStyle(fontSize: 15, color: Color(0xff31302e)),
      ),
      dividerColor: line,
      sliderTheme: const SliderThemeData(trackHeight: 3),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: line),
        ),
      ),
    ),
    home: const PracticeHome(),
  );
}

class PracticeHome extends ConsumerStatefulWidget {
  const PracticeHome({super.key});
  @override
  ConsumerState<PracticeHome> createState() => _PracticeHomeState();
}

class _PracticeHomeState extends ConsumerState<PracticeHome>
    with WidgetsBindingObserver {
  final audio = AudioEngine();
  final tracker = TapTracker();
  final clock = Stopwatch()..start();
  StreamSubscription<Map<dynamic, dynamic>>? subscription;
  late AppState store;
  int tab = 0, beat = -1, manualString = -1;
  bool playing = false, mic = false, analyzing = false;
  bool settings = false;
  String? error;
  double? frequency;
  final Set<int> tuned = {};
  final List<double> recent = [];
  int lastPitchAt = 0;
  Timer? staleTimer;
  final meters = const [
    '2/4',
    '3/4',
    '4/4',
    '5/4',
    '6/8',
    '7/8',
    '9/8',
    '12/8',
  ];
  bool strongBeat(int i) =>
      i == 0 ||
      (store.meter.endsWith('/8') &&
          (beats == 7 ? i == 2 || i == 4 : i % 3 == 0));
  int get beats => int.parse(store.meter.split('/').first);
  List<Tuning> get allTunings => [...tunings, ...store.customTunings];
  Tuning get tuning => allTunings.firstWhere(
    (t) => '${t.instrument}/${t.name}' == store.get('tuning', '6현 기타/Standard'),
    orElse: () => tunings.first,
  );
  double get a4 => store.number('a4', 440);
  double get tolerance => store.number('tolerance', 5);
  List<int> get mutedBeats =>
      List<int>.from(store.data['muted'] as List? ?? []);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store = ref.read(appProvider);
    store.addListener(changed);
    subscription = audio.stream.listen(
      onAudio,
      onError: (Object e) {
        if (mounted) {
          setState(() {
            error = '$e';
            playing = false;
            mic = false;
          });
        }
      },
    );
    staleTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && tracker.expire(clock.elapsedMilliseconds)) setState(() {});
      if (mounted &&
          frequency != null &&
          clock.elapsedMilliseconds - lastPitchAt > 800) {
        setState(() {
          frequency = null;
          recent.clear();
        });
      }
    });
  }

  void update(VoidCallback change) => setState(change);

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(changed);
    subscription?.cancel();
    staleTimer?.cancel();
    audio.stop();
    audio.stopMic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      audio.stop();
      audio.stopMic();
      if (mounted) {
        setState(() {
          playing = false;
          mic = false;
          frequency = null;
          beat = -1;
        });
      }
    }
  }

  Future<void> onAudio(Map<dynamic, dynamic> event) async {
    if (!mounted) return;
    if (event['type'] == 'beat' && playing) {
      setState(() => beat = (event['beat'] as num).toInt());
      if (store.get('vibration', false)) HapticFeedback.selectionClick();
    }
    if (event['type'] == 'stopped') {
      setState(() {
        playing = false;
        mic = false;
        frequency = null;
        beat = -1;
        error = event['reason'] as String?;
      });
    }
    if (event['type'] == 'pcm' && mic && !analyzing) {
      analyzing = true;
      try {
        final samples = (event['samples'] as List)
            .map((v) => (v as num).toDouble())
            .toList();
        final result = await compute(detectPitch, samples);
        if (!mounted || !mic) return;
        if (result == null) {
          recent.clear();
          setState(() => frequency = null);
          return;
        }
        if (recent.isNotEmpty &&
            centsBetween(result.frequency, recent.last).abs() > 90) {
          recent.clear();
        }
        recent.add(result.frequency);
        if (recent.length > 3) recent.removeAt(0);
        final sorted = [...recent]..sort();
        setState(() {
          frequency = sorted[sorted.length ~/ 2];
          lastPitchAt = clock.elapsedMilliseconds;
          if (!store.get('chromatic', false)) {
            final index = targetIndex(frequency!);
            if (centsBetween(
                      frequency!,
                      midiFrequency(tuning.notes[index], a4),
                    ).abs() <=
                    tolerance &&
                recent.length >= 3) {
              tuned.add(index);
            }
          }
        });
      } finally {
        analyzing = false;
      }
    }
  }

  int targetIndex(double f) {
    if (manualString >= 0 && manualString < tuning.notes.length) {
      return manualString;
    }
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < tuning.notes.length; i++) {
      final d = centsBetween(f, midiFrequency(tuning.notes[i], a4)).abs();
      if (d < distance) {
        distance = d;
        best = i;
      }
    }
    return best;
  }

  Future<void> configure() => audio.configure({
    'bpm': store.bpm,
    'beats': beats,
    'denominator': int.parse(store.meter.split('/').last),
    'volume': store.number('volume', .7),
    'sound': store.get('sound', 'wood'),
    'muted': mutedBeats,
    'accent': store.get('accent', true),
  });
  Future<void> setBpm(double value) async {
    await store.set('bpm', value.clamp(30, 300).roundToDouble());
    if (playing) await safe(configure);
  }

  Future<void> safe(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (e) {
      if (e is PlatformException && e.code == 'cancelled') return;
      if (mounted) {
        setState(
          () => error = e is PlatformException ? e.message ?? e.code : '$e',
        );
      }
    }
  }

  Future<void> togglePlay() async {
    await safe(() async {
      if (playing) {
        await audio.stop();
        setState(() {
          playing = false;
          beat = -1;
        });
      } else {
        await audio.stopMic();
        setState(() {
          mic = false;
          frequency = null;
        });
        await configure();
        await audio.start();
        setState(() {
          playing = true;
          error = null;
        });
      }
    });
  }

  Future<void> toggleMic() async {
    await safe(() async {
      if (mic) {
        await audio.stopMic();
        setState(() {
          mic = false;
          frequency = null;
        });
      } else {
        await audio.stop();
        setState(() {
          playing = false;
          beat = -1;
        });
        await audio.startMic();
        setState(() {
          mic = true;
          error = null;
        });
      }
    });
  }

  Future<void> switchTab(int index) async {
    if (index != tab) {
      await audio.stopMic();
      setState(() {
        mic = false;
        frequency = null;
        tab = index;
        settings = false;
        error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: paper,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: line),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.graphic_eq, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'TempoTune',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -.7,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: settings ? '연습 화면' : '설정',
            onPressed: () async {
              await audio.stopMic();
              setState(() {
                settings = !settings;
                mic = false;
                frequency = null;
              });
            },
            icon: Icon(settings ? Icons.close : Icons.tune_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              key: PageStorageKey(settings ? 'settings' : 'tab-$tab'),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(error!),
                          TextButton(
                            onPressed: () => safe(audio.openSettings),
                            child: const Text('앱 권한 설정 열기'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => error = null),
                            child: const Text('닫기'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (settings)
                  ...settingsPage()
                else if (tab == 0)
                  ...metronomePage()
                else if (tab == 1)
                  ...tapPage()
                else
                  ...tunerPage(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: switchTab,
        backgroundColor: Colors.white,
        indicatorColor: blue.withValues(alpha: .09),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.speed_rounded), label: '메트로놈'),
          NavigationDestination(
            icon: Icon(Icons.touch_app_outlined),
            label: '탭 템포',
          ),
          NavigationDestination(
            icon: Icon(Icons.graphic_eq_rounded),
            label: '튜너',
          ),
        ],
      ),
    );
  }

  Widget panel(Widget child, {EdgeInsets padding = const EdgeInsets.all(24)}) =>
      Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(padding: padding, child: child),
      );
  Widget eyebrow(String text) => Text(
    text,
    style: const TextStyle(
      color: muted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
    ),
  );
  Widget heading(String tag, String title, String description) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        eyebrow(tag),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 10),
        Text(description, style: const TextStyle(color: muted, height: 1.6)),
      ],
    ),
  );
  Widget label(String text) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  );
  Widget dropdown<T>(
    T value,
    List<T> values,
    String Function(T) title,
    ValueChanged<T?> onChanged,
  ) => DropdownButtonFormField<T>(
    key: ValueKey(value),
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    items: values
        .map(
          (v) => DropdownMenuItem(
            value: v,
            child: Text(title(v), overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );
}

class CentsPainter extends CustomPainter {
  final double? cents;
  CentsPainter(this.cents);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final p = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var i = -10; i <= 10; i++) {
      final x = center + i * size.width / 22;
      canvas.drawLine(Offset(x, 32), Offset(x, i % 5 == 0 ? 58 : 46), p);
    }
    p
      ..color = blue.withValues(alpha: .1)
      ..strokeWidth = 12;
    canvas.drawLine(Offset(center - 8, 33), Offset(center + 8, 33), p);
    if (cents != null) {
      final x = center + cents!.clamp(-50, 50) / 50 * (size.width / 2 - 12);
      p
        ..color = blue
        ..strokeWidth = 3;
      canvas.drawLine(Offset(x, 4), Offset(x, 60), p);
      canvas.drawCircle(Offset(x, 6), 4, p);
    }
  }

  @override
  bool shouldRepaint(CentsPainter old) => old.cents != cents;
}
