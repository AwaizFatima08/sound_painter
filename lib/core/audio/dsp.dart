import 'dart:math' as math;
import 'dart:typed_data';

/// Signal-processing building blocks. Pure Dart, no Flutter, so every piece
/// is unit-testable from WAV fixtures on a machine with no microphone.

const int kSampleRate = 16000;

/// Root-mean-square level of [x] (samples in -1..1).
double rms(Float32List x, [int start = 0, int? end]) {
  end ??= x.length;
  if (end <= start) return 0;
  var sum = 0.0;
  for (var i = start; i < end; i++) {
    sum += x[i] * x[i];
  }
  return math.sqrt(sum / (end - start));
}

/// Converts little-endian PCM16 bytes to floats in -1..1.
///
/// Respects the view's offset and length (the GDD version read the whole
/// underlying buffer, which returns garbage for sliced views).
Float32List pcm16ToFloat(Uint8List bytes) {
  final n = bytes.lengthInBytes ~/ 2;
  final data = ByteData.sublistView(bytes, 0, n * 2);
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

class PitchResult {
  const PitchResult(this.hz, this.clarity);

  /// Fundamental frequency, or 0 when the frame isn't clearly pitched.
  final double hz;

  /// 1 - aperiodicity (YIN's d'(tau)); near 1 for clean voiced sound.
  final double clarity;

  bool get voiced => hz > 0;
}

/// YIN pitch detector (de Cheveigné & Kawahara, 2002) with parabolic
/// interpolation. Unlike raw autocorrelation it doesn't favour small lags,
/// so it avoids the octave errors the GDD's detector would make.
class YinPitchDetector {
  YinPitchDetector({
    this.sampleRate = kSampleRate,
    this.minHz = 70,
    this.maxHz = 1100,
    this.threshold = 0.2,
  });

  final int sampleRate;
  final double minHz;
  final double maxHz;
  final double threshold;

  Float64List _d = Float64List(0);

  PitchResult detect(Float32List x) {
    final tauMin = (sampleRate / maxHz).floor().clamp(2, x.length);
    final tauMax = math.min((sampleRate / minHz).ceil(), x.length ~/ 2);
    if (tauMax <= tauMin + 2) return const PitchResult(0, 0);
    if (_d.length < tauMax + 1) _d = Float64List(tauMax + 1);
    final d = _d;
    final w = x.length - tauMax;

    // Difference function.
    for (var tau = 1; tau <= tauMax; tau++) {
      var sum = 0.0;
      for (var i = 0; i < w; i++) {
        final diff = x[i] - x[i + tau];
        sum += diff * diff;
      }
      d[tau] = sum;
    }
    // Cumulative mean normalised difference.
    d[0] = 1;
    var running = 0.0;
    for (var tau = 1; tau <= tauMax; tau++) {
      running += d[tau];
      d[tau] = running == 0 ? 1 : d[tau] * tau / running;
    }
    // First dip below threshold, then walk to its local minimum.
    var best = -1;
    for (var tau = tauMin; tau <= tauMax; tau++) {
      if (d[tau] < threshold) {
        while (tau + 1 <= tauMax && d[tau + 1] < d[tau]) {
          tau++;
        }
        best = tau;
        break;
      }
    }
    if (best == -1) {
      // No confident dip: report the global minimum's clarity but no pitch.
      var minV = double.infinity;
      for (var tau = tauMin; tau <= tauMax; tau++) {
        if (d[tau] < minV) minV = d[tau];
      }
      return PitchResult(0, (1 - minV).clamp(0.0, 1.0));
    }
    var refined = best.toDouble();
    if (best > 1 && best < tauMax) {
      final a = d[best - 1], b = d[best], c = d[best + 1];
      final denom = a - 2 * b + c;
      if (denom.abs() > 1e-12) refined = best + 0.5 * (a - c) / denom;
    }
    return PitchResult(sampleRate / refined, (1 - d[best]).clamp(0.0, 1.0));
  }
}

/// The five short phonics vowels Phonics Safari practises.
enum Vowel { a, e, i, o, u }

extension VowelInfo on Vowel {
  String get letter => name;
  String get word => const {
        Vowel.a: 'apple',
        Vowel.e: 'egg',
        Vowel.i: 'igloo',
        Vowel.o: 'octopus',
        Vowel.u: 'umbrella',
      }[this]!;
}

/// Recognises the five vowels from one analysis window.
///
/// Children's voices are high (250–400 Hz), so their harmonics are spaced
/// too widely for LPC formant tracking, which locks onto harmonics instead of
/// resonances. Instead this samples the spectrum exactly at each harmonic of
/// the known pitch and asks which vowel's resonance curve fits those points
/// best, allowing any overall level and spectral tilt (analysis by
/// synthesis). That works at any pitch.
///
/// Centroids are children's means from Peterson & Barney (1952); /o/ sits
/// between /ɑ/ and /ɔ/ because "octopus" is /ɒ/ in British English and /ɑ/ in
/// American. Adult vocal tracts are longer, so their formants sit ~20% lower;
/// [scale] compensates, set from the speaker's pitch (a steady cue that,
/// unlike adapting to the formants themselves, can't drift toward whichever
/// vowel a child keeps repeating).
class VowelClassifier {
  VowelClassifier({this.sampleRate = kSampleRate});

  final int sampleRate;

  /// Children's (F1, F2) in Hz.
  static const Map<Vowel, (double, double)> childCentroids = {
    Vowel.a: (1010, 2320), // æ  apple
    Vowel.e: (690, 2610), //  ɛ  egg
    Vowel.i: (530, 2730), //  ɪ  igloo
    Vowel.o: (900, 1250), //  ɒ/ɑ octopus
    Vowel.u: (850, 1590), //  ʌ  umbrella
  };
  static const double _f3 = 3500;
  static const double _maxHz = 4000;

  /// Divides the centroids' frequencies to match the speaker (child 1.0,
  /// adult up to 1.25).
  double scale = 1.0;
  double _f0Log = math.log(280);

  /// Tracks the speaker's typical pitch and derives [scale] from it.
  void observePitch(double hz) {
    if (hz <= 0) return;
    _f0Log += 0.05 * (math.log(hz) - _f0Log);
    final t = ((_f0Log - math.log(130)) / (math.log(250) - math.log(130))).clamp(0.0, 1.0);
    scale = 1.25 - 0.25 * t;
  }

  /// Fit error per vowel for window [x] voiced at [f0]; smaller is closer.
  /// Returns null when there are too few harmonics to judge.
  Map<Vowel, double>? score(Float32List x, double f0) {
    if (f0 <= 0) return null;
    final n = x.length;
    final harmonics = <double>[];
    final measured = <double>[];
    for (var k = 1; k * f0 <= _maxHz; k++) {
      final f = k * f0;
      final w = 2 * math.pi * f / sampleRate;
      var re = 0.0, im = 0.0;
      for (var i = 0; i < n; i++) {
        final v = x[i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1)));
        re += v * math.cos(w * i);
        im -= v * math.sin(w * i);
      }
      harmonics.add(f);
      measured.add(10 * math.log(re * re + im * im + 1e-12) / math.ln10);
    }
    if (harmonics.length < 5) return null;
    final logF = [for (final f in harmonics) math.log(f) / math.ln2];
    return {
      for (final e in childCentroids.entries)
        e.key: _fitError(measured, logF, [
          for (final f in harmonics) _modelDb(f, e.value.$1 / scale, e.value.$2 / scale, _f3 / scale)
        ]),
    };
  }

  /// Least-squares residual of measured − model after removing the best
  /// offset and tilt (in dB per octave).
  static double _fitError(List<double> m, List<double> x, List<double> model) {
    final n = m.length;
    var sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
    final y = List<double>.generate(n, (i) => m[i] - model[i]);
    for (var i = 0; i < n; i++) {
      sx += x[i];
      sy += y[i];
      sxx += x[i] * x[i];
      sxy += x[i] * y[i];
    }
    final den = n * sxx - sx * sx;
    final b = den.abs() < 1e-9 ? 0.0 : (n * sxy - sx * sy) / den;
    final a = (sy - b * sx) / n;
    var err = 0.0;
    for (var i = 0; i < n; i++) {
      final r = y[i] - a - b * x[i];
      err += r * r;
    }
    return math.sqrt(err / n);
  }

  /// Magnitude (dB) of a three-formant cascade at [f].
  double _modelDb(double f, double f1, double f2, double f3) {
    var db = 0.0;
    for (final (fc, bw) in [(f1, 110.0), (f2, 150.0), (f3, 220.0)]) {
      db += _resonatorDb(f, fc, bw);
    }
    return db;
  }

  double _resonatorDb(double f, double fc, double bw) {
    final r = math.exp(-math.pi * bw / sampleRate);
    final th = 2 * math.pi * fc / sampleRate;
    final w = 2 * math.pi * f / sampleRate;
    // |1 - 2r cos(th) e^-jw + r^2 e^-2jw|
    final re = 1 - 2 * r * math.cos(th) * math.cos(w) + r * r * math.cos(2 * w);
    final im = 2 * r * math.cos(th) * math.sin(w) - r * r * math.sin(2 * w);
    final re0 = 1 - 2 * r * math.cos(th) + r * r;
    return 10 * math.log(re0 * re0 / (re * re + im * im)) / math.ln10;
  }

  static Vowel best(Map<Vowel, double> scores) =>
      scores.entries.reduce((a, b) => a.value <= b.value ? a : b).key;

  /// Generous match used for the errorless Phonics Safari: the target counts
  /// when it's the best fit or within [toleranceDb] of it.
  static bool matches(Map<Vowel, double> scores, Vowel target, {double toleranceDb = 1.0}) {
    final top = scores.values.reduce(math.min);
    return scores[target]! <= top + toleranceDb;
  }
}

/// Median of the last [size] values; used to steady pitch readings.
class MedianSmoother {
  MedianSmoother([this.size = 5]);
  final int size;
  final List<double> _v = [];

  double add(double x) {
    _v.add(x);
    if (_v.length > size) _v.removeAt(0);
    final s = [..._v]..sort();
    return s[s.length ~/ 2];
  }

  void reset() => _v.clear();
}
