import 'dart:math' as math;
import 'dart:typed_data';

import 'dsp.dart';

/// Per-child voice range, measured by Pip's warm-up and fine-tuned by the
/// parent's sensitivity slider. Defaults suit a typical young child.
class Calibration {
  const Calibration({
    this.noiseRms = 0.004,
    this.loudRms = 0.18,
    this.lowHz = 190,
    this.highHz = 520,
    this.sensitivity = 1.0,
  });

  final double noiseRms;
  final double loudRms;
  final double lowHz;
  final double highHz;

  /// 0.5 (needs louder voice) .. 2.0 (reacts to very soft voices).
  final double sensitivity;

  /// Level below which input is treated as silence.
  double get gateRms => math.max(noiseRms * 2.2, 0.0025) / sensitivity.clamp(0.5, 2.0);

  double get _topRms => math.max(loudRms / sensitivity.clamp(0.5, 2.0), gateRms * 3);

  /// Maps RMS to 0..1 on a log scale between the gate and the child's loud.
  double level(double r) {
    if (r <= gateRms) return 0;
    final v = (math.log(r) - math.log(gateRms)) / (math.log(_topRms) - math.log(gateRms));
    return v.clamp(0.0, 1.0);
  }

  /// Maps pitch to 0 (child's lowest) .. 1 (child's highest), log scale,
  /// with a little headroom at both ends.
  double pitchNorm(double hz) {
    if (hz <= 0) return 0.5;
    final lo = math.log(lowHz * 0.9), hi = math.log(highHz * 1.1);
    return ((math.log(hz) - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  /// Makes a sane calibration from warm-up measurements; any value the child
  /// didn't produce keeps its default.
  Calibration withMeasured({double? noise, double? loud, double? low, double? high}) {
    var n = noise ?? noiseRms;
    var l = loud ?? loudRms;
    if (l < n * 5) l = n * 5;
    var lo = low ?? lowHz;
    var hi = high ?? highHz;
    if (lo > hi) {
      final t = lo;
      lo = hi;
      hi = t;
    }
    // Keep at least half an octave so colour still varies for children with a
    // narrow range.
    if (hi / lo < 1.5) {
      final mid = math.sqrt(hi * lo);
      lo = mid / math.sqrt(1.5);
      hi = mid * math.sqrt(1.5);
    }
    return copyWith(noiseRms: n, loudRms: l, lowHz: lo, highHz: hi);
  }

  Calibration copyWith({
    double? noiseRms,
    double? loudRms,
    double? lowHz,
    double? highHz,
    double? sensitivity,
  }) =>
      Calibration(
        noiseRms: noiseRms ?? this.noiseRms,
        loudRms: loudRms ?? this.loudRms,
        lowHz: lowHz ?? this.lowHz,
        highHz: highHz ?? this.highHz,
        sensitivity: sensitivity ?? this.sensitivity,
      );

  Map<String, dynamic> toJson() => {
        'noiseRms': noiseRms,
        'loudRms': loudRms,
        'lowHz': lowHz,
        'highHz': highHz,
        'sensitivity': sensitivity,
      };

  factory Calibration.fromJson(Map<String, dynamic> j) {
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    const c = Calibration();
    return Calibration(
      noiseRms: d('noiseRms', c.noiseRms),
      loudRms: d('loudRms', c.loudRms),
      lowHz: d('lowHz', c.lowHz),
      highHz: d('highHz', c.highHz),
      sensitivity: d('sensitivity', c.sensitivity),
    );
  }
}

/// One analysis result, produced every hop (32 ms).
class VoiceFrame {
  const VoiceFrame({
    required this.rms,
    required this.level,
    required this.voiced,
    required this.pitchHz,
    required this.pitchNorm,
    this.vowelScores,
    this.vowel,
  });

  static const silent = VoiceFrame(rms: 0, level: 0, voiced: false, pitchHz: 0, pitchNorm: 0.5);

  final double rms;

  /// 0..1 loudness relative to this child's range.
  final double level;

  /// True when the child is making sound above the noise gate.
  final bool voiced;

  /// Smoothed fundamental frequency, 0 when unpitched (whisper, clap, blow).
  final double pitchHz;

  /// 0..1 pitch relative to this child's range (0.5 when unpitched).
  final double pitchNorm;

  /// Fit error per vowel (smaller is closer), when the frame was clear
  /// enough to judge.
  final Map<Vowel, double>? vowelScores;

  /// Best-fitting vowel, when [vowelScores] is present.
  final Vowel? vowel;

  bool get pitched => pitchHz > 0;
}

/// Streams PCM16 chunks of any size into overlapping analysis windows.
class VoiceAnalyzer {
  VoiceAnalyzer({this.calibration = const Calibration()});

  static const int window = 1024; // 64 ms at 16 kHz
  static const int hop = 512; // 32 ms

  Calibration calibration;

  /// Vowel matching is the costliest step; only screens that use it (Phonics
  /// Safari, Sound check) turn it on.
  bool scoreVowels = false;

  final classifier = VowelClassifier();
  final _yin = YinPitchDetector();
  final _smooth = MedianSmoother(5);
  Float32List _buf = Float32List(window * 4);
  int _len = 0;
  int _unpitched = 0;
  double _lastPitch = 0;

  /// Adds samples and returns the frames completed by them (usually 0–2).
  List<VoiceFrame> add(Float32List samples) {
    if (_len + samples.length > _buf.length) {
      final bigger = Float32List(math.max(_buf.length * 2, _len + samples.length));
      bigger.setRange(0, _len, _buf);
      _buf = bigger;
    }
    _buf.setRange(_len, _len + samples.length, samples);
    _len += samples.length;
    final out = <VoiceFrame>[];
    var start = 0;
    while (_len - start >= window) {
      out.add(analyze(Float32List.sublistView(_buf, start, start + window)));
      start += hop;
    }
    if (start > 0) {
      _buf.setRange(0, _len - start, _buf, start);
      _len -= start;
    }
    return out;
  }

  VoiceFrame analyze(Float32List w) {
    final r = rms(w);
    final level = calibration.level(r);
    if (level <= 0) {
      _smooth.reset();
      _lastPitch = 0;
      return VoiceFrame(rms: r, level: 0, voiced: false, pitchHz: 0, pitchNorm: 0.5);
    }
    final p = _yin.detect(w);
    var hz = 0.0;
    if (p.voiced) {
      hz = _smooth.add(p.hz);
      _unpitched = 0;
      _lastPitch = hz;
    } else if (++_unpitched <= 2) {
      hz = _lastPitch; // bridge short dropouts so colour doesn't flicker
    }
    Map<Vowel, double>? scores;
    if (p.voiced && p.clarity > 0.6) {
      classifier.observePitch(p.hz);
      if (scoreVowels) scores = classifier.score(w, p.hz);
    }
    return VoiceFrame(
      rms: r,
      level: level,
      voiced: true,
      pitchHz: hz,
      pitchNorm: hz > 0 ? calibration.pitchNorm(hz) : 0.5,
      vowelScores: scores,
      vowel: scores == null ? null : VowelClassifier.best(scores),
    );
  }
}
