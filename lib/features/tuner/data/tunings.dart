class Tuning {
  final String instrument, name;
  final List<int> notes;
  final bool custom;
  const Tuning(this.instrument, this.name, this.notes, {this.custom = false});
  // Keep stable English names for saved selections; localize presentation only.
  String get displayName => custom
      ? name
      : switch (name) {
          'Standard' => '기본 튜닝 (Standard)',
          'Half Step Down' => '하프다운 (Half Step Down)',
          'D Standard' => '한 음 낮추기 (D Standard)',
          'Drop D' => '드롭 D (Drop D)',
          'Drop C' => '드롭 C (Drop C)',
          'Drop A' => '드롭 A (Drop A)',
          'Open D' => '오픈 D (Open D)',
          'Open G' => '오픈 G (Open G)',
          'DADGAD' => '다드가드 (DADGAD)',
          'Standard High G' => '기본 튜닝 · 높은 G (High G)',
          'Low G' => '낮은 G 튜닝 (Low G)',
          'Baritone' => '바리톤 튜닝 (Baritone)',
          _ => name,
        };
  String get explanation => custom
      ? '직접 저장한 음정으로 맞춰요.'
      : switch (name) {
          'Standard' => '가장 일반적으로 사용하는 기본 음정이에요.',
          'Half Step Down' => '모든 줄을 기본 튜닝보다 반음씩 낮춰요.',
          'D Standard' => '모든 줄을 기본 튜닝보다 한 음씩 낮춰요.',
          'Drop D' => '기본 튜닝에서 가장 두꺼운 줄만 한 음 낮춰 D로 맞춰요.',
          'Drop C' => '모든 줄을 한 음 낮춘 뒤, 가장 두꺼운 줄을 한 음 더 낮춰 C로 맞춰요.',
          'Drop A' => '7현 기타의 가장 두꺼운 줄만 한 음 낮춰 A로 맞춰요.',
          'Open D' => '줄을 누르지 않고 연주하면 D 장화음이 나요.',
          'Open G' => '줄을 누르지 않고 연주하면 G 장화음이 나요.',
          'DADGAD' => '두꺼운 줄부터 D–A–D–G–A–D로 맞추는 튜닝이에요.',
          'Standard High G' => '일반적인 우쿨렐레 튜닝이에요. 4번 G줄은 높은 음이에요.',
          'Low G' => '기본 우쿨렐레 튜닝에서 4번 G줄을 한 옥타브 낮춰요.',
          'Baritone' => '바리톤 우쿨렐레용 D–G–B–E 튜닝이에요.',
          _ => '',
        };
  int stringNumber(int index) => notes.length - index;

  Map<String, dynamic> toJson() => {
    'instrument': instrument,
    'name': name,
    'notes': notes,
  };
  factory Tuning.fromJson(Map<String, dynamic> j) => Tuning(
    j['instrument'],
    j['name'],
    List<int>.from(j['notes']),
    custom: true,
  );
}

const tunings = [
  Tuning('6현 기타', 'Standard', [40, 45, 50, 55, 59, 64]),
  Tuning('6현 기타', 'Half Step Down', [39, 44, 49, 54, 58, 63]),
  Tuning('6현 기타', 'D Standard', [38, 43, 48, 53, 57, 62]),
  Tuning('6현 기타', 'Drop D', [38, 45, 50, 55, 59, 64]),
  Tuning('6현 기타', 'Drop C', [36, 43, 48, 53, 57, 62]),
  Tuning('6현 기타', 'Open D', [38, 45, 50, 54, 57, 62]),
  Tuning('6현 기타', 'Open G', [38, 43, 50, 55, 59, 62]),
  Tuning('6현 기타', 'DADGAD', [38, 45, 50, 55, 57, 62]),
  Tuning('7현 기타', 'Standard', [35, 40, 45, 50, 55, 59, 64]),
  Tuning('7현 기타', 'Drop A', [33, 40, 45, 50, 55, 59, 64]),
  Tuning('4현 베이스', 'Standard', [28, 33, 38, 43]),
  Tuning('4현 베이스', 'Half Step Down', [27, 32, 37, 42]),
  Tuning('4현 베이스', 'Drop D', [26, 33, 38, 43]),
  Tuning('4현 베이스', 'D Standard', [26, 31, 36, 41]),
  Tuning('5현 베이스', 'Standard', [23, 28, 33, 38, 43]),
  Tuning('우쿨렐레', 'Standard High G', [67, 60, 64, 69]),
  Tuning('우쿨렐레', 'Low G', [55, 60, 64, 69]),
  Tuning('우쿨렐레', 'Baritone', [50, 55, 59, 64]),
];
