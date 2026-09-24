import 'package:flutter_test/flutter_test.dart';
import 'package:sound_painter/core/audio/voice_analyzer.dart';
import 'package:sound_painter/views/onboarding/warmup_view.dart';

void main() {
  test('a quiet room gives a low noise floor', () {
    expect(warmupNoiseFloor(firstWindow: 0.003, allLevels: List.filled(50, 0.004)), closeTo(0.003, 1e-9));
  });

  test('a child singing during the first second does not make the app deaf', () {
    // First window measured while the child was already loud (0.2 RMS);
    // the rest of the warm-up had quiet gaps around 0.004.
    final levels = [...List.filled(30, 0.004), ...List.filled(70, 0.15)];
    final n = warmupNoiseFloor(firstWindow: 0.2, allLevels: levels, loud: 0.25, quiet: 0.03)!;
    expect(n, lessThan(0.011));
    // And ordinary speech (~0.05 RMS) still registers afterwards.
    final cal = const Calibration().withMeasured(noise: n, loud: 0.25);
    expect(cal.level(0.05), greaterThan(0.3));
  });

  test('a noisy room is capped so voices still get through', () {
    final n = warmupNoiseFloor(firstWindow: 0.08, allLevels: List.filled(40, 0.07))!;
    expect(n, 0.012);
  });

  test('nothing measured keeps the default', () {
    expect(warmupNoiseFloor(), isNull);
  });
}
