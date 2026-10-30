part of '../../../app/app.dart';

extension _TapTempoPage on _PracticeHomeState {
  List<Widget> tapPage() => [
    heading('02 / FEEL THE TEMPO', '들리는 리듬, 그대로.', '음악에 맞춰 가볍게 탭하면 템포를 알려드려요.'),
    panel(
      Column(
        children: [
          eyebrow('MEASURED TEMPO'),
          const SizedBox(height: 16),
          Text(
            tracker.bpm == null
                ? '—'
                : tracker.bpm!.toStringAsFixed(
                    store.get('decimals', false) ? 1 : 0,
                  ),
            style: const TextStyle(
              fontSize: 76,
              fontWeight: FontWeight.w700,
              letterSpacing: -3,
            ),
          ),
          const Text('BPM', style: TextStyle(color: muted)),
          const SizedBox(height: 28),
          SizedBox(
            width: 220,
            height: 220,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => tap(),
              child: Semantics(
                button: true,
                label: '탭하여 템포 측정',
                onTap: tap,
                child: Container(
                  decoration: BoxDecoration(
                    color: paper,
                    shape: BoxShape.circle,
                    border: Border.all(color: line, width: 2),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_outlined, size: 32),
                      SizedBox(height: 12),
                      Text(
                        'TAP',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '박자에 맞춰 탭하세요',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              metric('${tracker.count}', '탭 횟수'),
              Container(width: 1, height: 36, color: line),
              metric(
                tracker.lastInterval == null
                    ? '—'
                    : '${tracker.lastInterval} ms',
                '최근 간격',
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: tracker.bpm == null
                  ? null
                  : () async {
                      await setBpm(tracker.bpm!);
                      await store.set('lastTap', tracker.bpm);
                      update(() => tab = 0);
                    },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('메트로놈에 적용'),
            ),
          ),
          TextButton.icon(
            onPressed: () => update(tracker.reset),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('측정 초기화'),
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    panel(
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✦', style: TextStyle(color: Color(0xffdd5b00), fontSize: 24)),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              '최소 두 번 탭해 주세요. 최근 탭 간격을 바탕으로 작은 입력 오차를 보정합니다. 잠시 쉬었다 탭하면 새로 측정해요.',
              style: TextStyle(color: muted, height: 1.7, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
    if (store.data['lastTap'] != null)
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          '마지막 측정  ${store.number('lastTap', 120).toStringAsFixed(1)} BPM',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ),
  ];
  Widget metric(String value, String caption) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      Text(caption, style: const TextStyle(color: muted, fontSize: 12)),
    ],
  );
  void tap() {
    tracker.window = store.number('tapWindow', 6).round();
    tracker.timeoutMs = (store.number('tapTimeout', 3) * 1000).round();
    update(() => tracker.tap(clock.elapsedMilliseconds));
    if (tracker.bpm != null) store.set('lastTap', tracker.bpm);
  }
}
