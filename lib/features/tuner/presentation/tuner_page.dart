part of '../../../app/app.dart';

extension _TunerPage on _PracticeHomeState {
  List<Widget> tunerPage() {
    final chromatic = store.get('chromatic', false);
    final f = frequency;
    final index = f == null ? -1 : targetIndex(f);
    final midi = f == null
        ? null
        : chromatic
        ? nearestMidi(f, a4)
        : tuning.notes[index];
    final cents = f == null ? null : centsBetween(f, midiFrequency(midi!, a4));
    final inTune = cents != null && cents.abs() <= tolerance;
    final instruments = allTunings.map((t) => t.instrument).toSet().toList();
    final choices = allTunings
        .where((t) => t.instrument == tuning.instrument)
        .toList();
    return [
      heading('03 / FIND YOUR NOTE', '좋은 소리의 시작.', '작은 차이까지 듣는, 나만의 튜닝 도구.'),
      Row(
        children: [
          Expanded(
            child: ChoiceChip(
              label: const Text('악기별 튜닝'),
              selected: !chromatic,
              onSelected: (_) {
                store.set('chromatic', false);
                tuned.clear();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: const Text('크로매틱'),
              selected: chromatic,
              onSelected: (_) => store.set('chromatic', true),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      panel(
        Column(
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              children: [
                eyebrow(mic ? 'MICROPHONE ON' : 'MICROPHONE OFF'),
                Text(
                  'A4 = ${a4.round()} Hz',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              midi == null
                  ? '—'
                  : noteName(midi, flats: store.get('flats', false)),
              style: const TextStyle(
                fontSize: 84,
                fontWeight: FontWeight.w700,
                letterSpacing: -3,
                height: 1.25,
              ),
            ),
            Text(
              f == null ? '아직 감지된 음이 없어요' : '${f.toStringAsFixed(2)} Hz',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 72,
              child: CustomPaint(
                size: const Size(double.infinity, 72),
                painter: CentsPainter(cents),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [eyebrow('낮음 ♭'), eyebrow('0'), eyebrow('높음 ♯')],
            ),
            const SizedBox(height: 22),
            Text(
              cents == null
                  ? (mic ? '한 줄을 가볍게 튕겨 주세요' : '마이크를 켜고 튜닝을 시작하세요')
                  : inTune
                  ? '정확해요. 좋은 소리예요!'
                  : '${cents > 0 ? '+' : ''}${cents.toStringAsFixed(1)} cents · ${cents > 0 ? '조금 풀어주세요' : '조금 조여주세요'}',
              style: TextStyle(
                color: inTune ? blue : muted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: toggleMic,
                icon: Icon(
                  mic ? Icons.mic_off_outlined : Icons.mic_none_rounded,
                ),
                label: Text(mic ? '마이크 끄기' : '마이크 켜기'),
              ),
            ),
          ],
        ),
      ),
      if (!chromatic) ...[
        label('악기와 튜닝'),
        panel(
          Column(
            children: [
              dropdown(
                tuning.instrument,
                instruments,
                (v) => v,
                (v) => selectTuning(
                  allTunings.firstWhere((t) => t.instrument == v),
                ),
              ),
              const SizedBox(height: 12),
              dropdown(
                '${tuning.instrument}/${tuning.name}',
                choices.map((t) => '${t.instrument}/${t.name}').toList(),
                (v) => v.split('/').last,
                (v) => selectTuning(
                  allTunings.firstWhere(
                    (t) => '${t.instrument}/${t.name}' == v,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('자동'),
                    selected: manualString < 0,
                    onSelected: (_) => update(() => manualString = -1),
                  ),
                  ...List.generate(
                    tuning.notes.length,
                    (i) => ChoiceChip(
                      label: Text(
                        '${i + 1} · ${noteName(tuning.notes[i], flats: store.get('flats', false))}${tuned.contains(i) ? ' ✓' : ''}',
                      ),
                      selected: manualString == i,
                      onSelected: (_) => update(() => manualString = i),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                tuned.length == tuning.notes.length
                    ? '모든 줄 튜닝 완료 ✓'
                    : '${tuned.length} / ${tuning.notes.length} 줄 완료 · 줄을 선택하면 해당 음에 고정해요',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              TextButton(
                onPressed: () => update(tuned.clear),
                child: const Text('완료 표시 초기화'),
              ),
            ],
          ),
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => customTuning(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('커스텀 튜닝'),
            ),
            if (tuning.custom) ...[
              IconButton(
                tooltip: '튜닝 수정',
                onPressed: () => customTuning(existing: tuning),
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                tooltip: '튜닝 삭제',
                onPressed: () async {
                  final items = store.customTunings
                      .where(
                        (t) =>
                            t.name != tuning.name ||
                            t.instrument != tuning.instrument,
                      )
                      .map((t) => t.toJson())
                      .toList();
                  await selectTuning(tunings.first);
                  await store.set('customTunings', items);
                },
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ],
        ),
      ],
      const SizedBox(height: 16),
      const Text(
        '조용한 곳에서 한 줄씩 연주해 주세요. 베이스 저음은 기기 마이크에 따라 감지 범위가 달라질 수 있어요. 우쿨렐레는 G–C–E–A 줄 순서를 유지합니다.',
        style: TextStyle(color: muted, fontSize: 12, height: 1.7),
      ),
    ];
  }

  Future<void> selectTuning(Tuning t) async {
    update(() {
      tuned.clear();
      manualString = -1;
      frequency = null;
      recent.clear();
    });
    await store.set('tuning', '${t.instrument}/${t.name}');
  }

  Future<void> customTuning({Tuning? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final notes = TextEditingController(
      text:
          existing?.notes
              .map((n) => noteName(n).replaceAll('♯', '#'))
              .join(' ') ??
          'E2 A2 D3 G3 B3 E4',
    );
    String? validation;
    final result = await showDialog<Tuning>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('커스텀 튜닝'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 40,
                decoration: const InputDecoration(labelText: '튜닝 이름'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                decoration: InputDecoration(
                  labelText: '낮은 줄부터 음정 입력',
                  helperText: '예: D2 A2 D3 G3 B3 E4',
                  errorText: validation,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final parsed = <int>[];
                for (final s in notes.text.trim().split(RegExp(r'\s+'))) {
                  final m = RegExp(r'^([A-Ga-g])([#b]?)([0-8])$').firstMatch(s);
                  if (m == null) {
                    update(() => validation = 'E2, F#3, Bb2 형식으로 입력해 주세요');
                    return;
                  }
                  final base = {
                    'C': 0,
                    'D': 2,
                    'E': 4,
                    'F': 5,
                    'G': 7,
                    'A': 9,
                    'B': 11,
                  }[m[1]!.toUpperCase()]!;
                  parsed.add(
                    (int.parse(m[3]!) + 1) * 12 +
                        base +
                        (m[2] == '#'
                            ? 1
                            : m[2] == 'b'
                            ? -1
                            : 0),
                  );
                }
                if (name.text.trim().isEmpty ||
                    parsed.isEmpty ||
                    parsed.length > 12) {
                  update(() => validation = '이름과 1~12개의 음정을 입력해 주세요');
                  return;
                }
                if (parsed.any((n) => n < 21 || n > 90)) {
                  update(() => validation = '지원 범위는 A0~F#6 (약 27~1500 Hz)예요');
                  return;
                }
                if (allTunings.any(
                  (t) =>
                      t.instrument == '사용자 정의' &&
                      t.name == name.text.trim() &&
                      t.name != existing?.name,
                )) {
                  update(() => validation = '이미 사용 중인 이름이에요');
                  return;
                }
                Navigator.pop(
                  ctx,
                  Tuning('사용자 정의', name.text.trim(), parsed, custom: true),
                );
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      final items =
          store.customTunings
              .where((t) => t.name != existing?.name)
              .map((t) => t.toJson())
              .toList()
            ..add(result.toJson());
      await store.set('customTunings', items);
      await selectTuning(result);
    }
  }
}
