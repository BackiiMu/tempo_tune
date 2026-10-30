class Tuning {
  final String instrument, name;
  final List<int> notes;
  final bool custom;
  const Tuning(this.instrument, this.name, this.notes, {this.custom = false});
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
