import 'dart:math';

class Pitch {
  final double frequency, confidence;
  const Pitch(this.frequency, this.confidence);
}

// YIN cumulative mean normalized difference, with parabolic lag refinement.
// The caller runs this on a worker isolate; input is 12 kHz mono PCM.
Pitch? detectPitch(List<double> input, {double sampleRate = 12000}) {
  if (input.length < 2048) return null;
  final mean = input.reduce((a, b) => a + b) / input.length;
  final x = input.map((v) => v - mean).toList();
  final rms = sqrt(x.fold<double>(0, (s, v) => s + v * v) / x.length);
  if (rms < .006) return null;
  final maxLag = min((sampleRate / 27).ceil(), x.length ~/ 2 - 1);
  final minLag = (sampleRate / 1500).floor();
  final size = x.length - maxLag;
  final difference = List<double>.filled(maxLag + 1, 0);
  for (var lag = 1; lag <= maxLag; lag++) {
    var sum = 0.0;
    for (var i = 0; i < size; i++) {
      final d = x[i] - x[i + lag];
      sum += d * d;
    }
    difference[lag] = sum;
  }
  var running = 0.0;
  final normalized = List<double>.filled(maxLag + 1, 1);
  for (var lag = 1; lag <= maxLag; lag++) {
    running += difference[lag];
    normalized[lag] = running == 0 ? 1 : difference[lag] * lag / running;
  }
  for (var lag = minLag; lag < maxLag - 1; lag++) {
    if (normalized[lag] < .15) {
      while (lag + 1 < maxLag && normalized[lag + 1] < normalized[lag]) {
        lag++;
      }
      final a = difference[lag - 1],
          b = difference[lag],
          c = difference[lag + 1];
      final divisor = 2 * (2 * b - a - c);
      final refined = lag + (divisor.abs() < 1e-12 ? 0 : (c - a) / divisor);
      return Pitch(sampleRate / refined, 1 - normalized[lag]);
    }
  }
  return null;
}

double midiFrequency(int midi, double a4) => a4 * pow(2, (midi - 69) / 12);
double centsBetween(double actual, double target) =>
    1200 * log(actual / target) / ln2;
int nearestMidi(double frequency, double a4) =>
    (69 + 12 * log(frequency / a4) / ln2).round();
String noteName(int midi, {bool flats = false}) {
  final names = flats
      ? ['C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B']
      : ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'];
  return '${names[midi % 12]}${midi ~/ 12 - 1}';
}
