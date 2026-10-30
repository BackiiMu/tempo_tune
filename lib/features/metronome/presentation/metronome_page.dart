part of '../../../app/app.dart';

extension _MetronomePage on _PracticeHomeState {
  List<Widget> metronomePage() => [
    heading(
      '01 / KEEP THE RHYTHM',
      '나만의 리듬을 찾아요.',
      '한 박자씩, 더 단단한 연습을 위한 메트로놈.',
    ),
    panel(
      Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              eyebrow('TEMPO'),
              Text(store.meter, style: const TextStyle(color: muted)),
            ],
          ),
          Semantics(
            button: true,
            label: 'BPM 직접 입력 ${store.bpm.round()}',
            child: InkWell(
              onTap: editBpm,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${store.bpm.round()}',
                      style: const TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'BPM',
                      style: TextStyle(color: muted, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            tempoName(store.bpm),
            style: const TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final delta in [-5, -1, 1, 5])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: OutlinedButton(
                      onPressed: () => setBpm(store.bpm + delta),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: line),
                        minimumSize: const Size(0, 46),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        delta > 0 ? '+$delta' : '$delta',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Slider(
            value: store.bpm,
            min: 30,
            max: 300,
            divisions: 270,
            onChanged: setBpm,
            semanticFormatterCallback: (v) => '${v.round()} BPM',
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('30', style: TextStyle(color: muted, fontSize: 12)),
              Text('300', style: TextStyle(color: muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: List.generate(
              beats,
              (i) => Semantics(
                label: '${i + 1}박 ${mutedBeats.contains(i) ? '무음' : '소리 켜짐'}',
                button: true,
                child: InkWell(
                  onTap: () async {
                    final m = mutedBeats;
                    m.contains(i) ? m.remove(i) : m.add(i);
                    await store.set('muted', m);
                    if (playing) await safe(configure);
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: beat == i ? blue : paper,
                      shape: BoxShape.circle,
                      border: Border.all(color: beat == i ? blue : line),
                    ),
                    child: Center(
                      child: Icon(
                        mutedBeats.contains(i)
                            ? Icons.volume_off_rounded
                            : (strongBeat(i)
                                  ? Icons.circle
                                  : Icons.circle_outlined),
                        size: 16,
                        color: beat == i ? Colors.white : muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            playing ? '${beat + 1} / $beats 박' : '박자를 눌러 무음으로 바꿀 수 있어요',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: togglePlay,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(playing ? '일시정지' : '연습 시작'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: '첫 박부터 다시 시작',
                onPressed: () async {
                  await audio.stop();
                  if (playing) {
                    await configure();
                    await audio.start();
                  }
                  update(() => beat = -1);
                },
                icon: const Icon(Icons.replay_rounded),
              ),
            ],
          ),
        ],
      ),
    ),
    label('연습 설정'),
    panel(
      Column(
        children: [
          dropdown(store.meter, meters, (v) => v, (v) async {
            if (v == null) return;
            await store.set('meter', v);
            await store.set('muted', <int>[]);
            if (playing) await safe(configure);
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.volume_down_outlined, color: muted),
              Expanded(
                child: Slider(
                  value: store.number('volume', .7),
                  onChanged: (v) async {
                    await store.set('volume', v);
                    if (playing) await safe(configure);
                  },
                ),
              ),
              Text(
                '${(store.number('volume', .7) * 100).round()}%',
                style: const TextStyle(color: muted),
              ),
            ],
          ),
        ],
      ),
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        label('내 템포 프리셋'),
        TextButton.icon(
          onPressed: () => editPreset(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('저장'),
        ),
      ],
    ),
    if (store.presets.isEmpty)
      panel(
        const Row(
          children: [
            Icon(Icons.bookmark_border, color: muted),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '자주 연습하는 템포를 저장해 보세요.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ),
          ],
        ),
      )
    else
      ...store.presets.asMap().entries.map(
        (entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: panel(
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      await store.set('meter', entry.value['meter']);
                      await store.set('muted', <int>[]);
                      await setBpm((entry.value['bpm'] as num).toDouble());
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${entry.value['bpm']} BPM · ${entry.value['meter']}',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '프리셋 수정',
                  onPressed: () => editPreset(index: entry.key),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  tooltip: '프리셋 삭제',
                  onPressed: () {
                    final p = store.presets..removeAt(entry.key);
                    store.set('presets', p);
                  },
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
          ),
        ),
      ),
    const SizedBox(height: 20),
    const Text(
      '앱이 백그라운드로 이동하면 재생이 정지됩니다.\n블루투스 출력에서는 소리와 화면 사이에 지연이 생길 수 있어요.',
      style: TextStyle(color: muted, fontSize: 12, height: 1.7),
    ),
  ];
  String tempoName(double b) => b < 60
      ? 'Largo · 느리고 여유롭게'
      : b < 90
      ? 'Andante · 걷는 빠르기로'
      : b < 120
      ? 'Moderato · 차분하고 적당하게'
      : b < 168
      ? 'Allegro · 경쾌하고 빠르게'
      : 'Presto · 아주 빠르게';
  Future<void> editBpm() async {
    final c = TextEditingController(text: store.bpm.round().toString());
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('BPM 입력'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(helperText: '30–300 BPM'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final n = double.tryParse(c.text);
              if (n != null && n >= 30 && n <= 300) Navigator.pop(ctx, n);
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
    if (v != null) await setBpm(v);
  }

  Future<void> editPreset({int? index}) async {
    final old = index == null ? null : store.presets[index];
    final name = TextEditingController(text: old?['name'] ?? '');
    final bpm = TextEditingController(
      text: '${old?['bpm'] ?? store.bpm.round()}',
    );
    String meter = old?['meter'] ?? store.meter;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(index == null ? '템포 저장' : '프리셋 수정'),
        content: StatefulBuilder(
          builder: (ctx, update) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 40,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bpm,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'BPM (30–300)'),
              ),
              const SizedBox(height: 12),
              dropdown(
                meter,
                meters,
                (v) => v,
                (v) => update(() => meter = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final n = double.tryParse(bpm.text);
              if (name.text.trim().isNotEmpty &&
                  n != null &&
                  n >= 30 &&
                  n <= 300) {
                Navigator.pop(ctx, {
                  'name': name.text.trim(),
                  'bpm': n,
                  'meter': meter,
                });
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result != null) {
      final p = store.presets;
      if (index == null) {
        p.add(result);
      } else {
        p[index] = result;
      }
      await store.set('presets', p);
    }
  }
}
