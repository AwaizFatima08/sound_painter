import 'package:flutter_test/flutter_test.dart';
import 'package:sound_painter/core/audio/voice_analyzer.dart';
import 'package:sound_painter/models/profile.dart';
import 'package:sound_painter/views/balloon/balloon_view.dart';
import 'package:sound_painter/views/hill/ice_hill_view.dart';

void main() {
  test('balloon needs a little more than the longest hold, within limits', () {
    expect(balloonSeconds(0), 3.0, reason: 'a new child starts easy');
    expect(balloonSeconds(4), closeTo(4.4, 1e-9));
    expect(balloonSeconds(30), 8.0);
  });

  test('hill stars use the whole range without its very edges', () {
    expect(hillStarHeights.every((h) => h >= 0.1 && h <= 0.9), isTrue);
    expect(hillStarHeights.reduce((a, b) => a < b ? a : b), lessThan(0.3));
    expect(hillStarHeights.reduce((a, b) => a > b ? a : b), greaterThan(0.7));
  });

  test('game progress is saved, read back, and starts at zero for old profiles', () {
    final p = Profile(id: 'x', avatar: Avatar.fox)
      ..hillStars = 6
      ..hillLowHz = 240
      ..hillHighHz = 470
      ..lanternsQuiet = 3
      ..lanternsLoud = 5
      ..balloons = 2
      ..longestHold = 4.5;
    final back = Profile.fromJson(p.toJson());
    expect([back.hillStars, back.hillLowHz, back.hillHighHz], [6, 240, 470]);
    expect([back.lanternsQuiet, back.lanternsLoud, back.balloons, back.longestHold], [3, 5, 2, 4.5]);

    final j = p.toJson();
    for (final k in ['hillStars', 'hillLowHz', 'hillHighHz', 'lanternsQuiet', 'lanternsLoud', 'balloons', 'longestHold']) {
      j.remove(k);
    }
    final old = Profile.fromJson(j);
    expect([old.hillStars, old.lanternsLoud, old.balloons, old.longestHold], [0, 0, 0, 0]);
  });

  test('lanterns: a voice a third as strong as the child\'s loud is quiet, near their loud is big', () {
    for (final c in const [Calibration(), Calibration(noiseRms: 0.0006, loudRms: 0.17)]) {
      final split = c.loudSplit;
      expect(c.level(c.loudRms * 0.2), lessThan(split));
      expect(c.level(c.loudRms * 0.8), greaterThan(split));
    }
  });
}
