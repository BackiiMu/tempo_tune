part of '../../../app/app.dart';

extension _SettingsPage on _PracticeHomeState {
  List<Widget> settingsPage() => [
    heading('PREFERENCES', '연습에 맞게, 편하게.', '모든 설정은 이 기기에 저장됩니다.'),
    label('메트로놈'),
    panel(
      Column(
        children: [
          dropdown(
            store.get('sound', 'wood'),
            ['wood', 'sine', 'bright'],
            (v) => {'wood': '우드 클릭', 'sine': '소프트 톤', 'bright': '브라이트 클릭'}[v]!,
            (v) async {
              await store.set('sound', v);
              if (playing) await safe(configure);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('강박 강조'),
            value: store.get('accent', true),
            onChanged: (v) async {
              await store.set('accent', v);
              if (playing) await safe(configure);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('진동 보조'),
            subtitle: const Text('정확한 타이밍은 오디오를 기준으로 해요'),
            value: store.get('vibration', false),
            onChanged: (v) => store.set('vibration', v),
          ),
          const Text(
            'BPM·박자·볼륨은 메트로놈 화면에서 변경하며 마지막 값이 유지됩니다.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    ),
    label('탭 템포'),
    panel(
      Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('BPM 소수점 표시'),
            value: store.get('decimals', false),
            onChanged: (v) => store.set('decimals', v),
          ),
          settingSlider('초기화 대기시간', 'tapTimeout', 3, 2, 6, '초'),
          settingSlider('계산할 최근 간격', 'tapWindow', 6, 4, 8, '개'),
        ],
      ),
    ),
    label('튜너'),
    panel(
      Column(
        children: [
          settingSlider('기준 주파수 A4', 'a4', 440, 430, 450, 'Hz'),
          settingSlider('튜닝 허용 오차', 'tolerance', 5, 1, 15, 'cents'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('플랫(♭)으로 표시'),
            value: store.get('flats', false),
            onChanged: (v) => store.set('flats', v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('마지막 악기와 튜닝 기억'),
            value: store.get('rememberTuning', true),
            onChanged: (v) => store.set('rememberTuning', v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(mic ? Icons.mic : Icons.mic_off_outlined),
            title: Text(mic ? '마이크 입력 중' : '마이크 꺼짐'),
            subtitle: const Text('튜너에서 켤 때만 권한을 요청합니다'),
          ),
        ],
      ),
    ),
    label('TempoTune'),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '음악에 집중할 수 있도록.',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            '버전 1.0.0 · 오프라인 악기 연습 도구',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('설정을 초기화할까요?'),
                  content: const Text('저장한 템포와 커스텀 튜닝도 삭제됩니다.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('초기화'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await audio.stop();
                await audio.stopMic();
                await store.reset();
                update(() {
                  playing = false;
                  mic = false;
                  beat = -1;
                  manualString = -1;
                  tuned.clear();
                  tracker.reset();
                });
              }
            },
            child: const Text('모든 설정 초기화'),
          ),
        ],
      ),
    ),
  ];
  Widget settingSlider(
    String title,
    String key,
    double fallback,
    double min,
    double max,
    String unit,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      Text('$title · ${store.number(key, fallback).round()} $unit'),
      Slider(
        value: store.number(key, fallback),
        min: min,
        max: max,
        divisions: (max - min).round(),
        onChanged: (v) => store.set(key, v),
      ),
    ],
  );
}
