class TapTracker {
  final List<int> _intervals = [];
  int? _last;
  int count = 0;
  int window = 6;
  int timeoutMs = 3000;
  double? bpm;
  int? get lastInterval => _intervals.isEmpty ? null : _intervals.last;
  void reset() {
    _intervals.clear();
    _last = null;
    count = 0;
    bpm = null;
  }

  bool expire(int milliseconds) {
    if (_last != null && milliseconds - _last! > timeoutMs) {
      reset();
      return true;
    }
    return false;
  }

  bool tap(int milliseconds) {
    if (_last != null && milliseconds - _last! > timeoutMs) reset();
    if (_last != null) {
      final delta = milliseconds - _last!;
      if (delta < 150) return false;
      _intervals.add(delta);
      while (_intervals.length > window) {
        _intervals.removeAt(0);
      }
      final sorted = [..._intervals]..sort();
      // Trim isolated timing slips, but let a sustained tempo change take over.
      final median = sorted[sorted.length ~/ 2];
      final valid = _intervals
          .where((v) => (v - median).abs() < median * .35)
          .toList();
      bpm = 60000 * valid.length / valid.reduce((a, b) => a + b);
    }
    _last = milliseconds;
    count++;
    return true;
  }
}
