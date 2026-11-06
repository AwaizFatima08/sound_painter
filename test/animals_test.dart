import 'package:flutter_test/flutter_test.dart';
import 'package:sound_painter/core/audio/dsp.dart';
import 'package:sound_painter/core/audio/voice_analyzer.dart';
import 'package:sound_painter/models/animals.dart';
import 'package:sound_painter/models/profile.dart';

VoiceFrame frame({bool voiced = true, double pitchHz = 300, Map<Vowel, double>? scores}) => VoiceFrame(
      rms: 0.1,
      level: 0.5,
      voiced: voiced,
      pitchHz: pitchHz,
      pitchNorm: 0.5,
      vowelScores: scores,
    );

void main() {
  test('seven animals, each with its picture and voice line', () {
    expect(Animals.all.map((a) => a.id), ['cow', 'sheep', 'cat', 'dog', 'duck', 'snake', 'lion']);
    expect(Animals.all.first.image, 'assets/images/animal_cow.webp');
    expect(Animals.all.first.voiceLine, 'animal_cow');
    expect(Animals.all[3].label, 'puppy');
  });

  test('the snake matches a hiss (sound without pitch), not a sung note', () {
    const hiss = HissSound();
    expect(hiss.matches(frame(pitchHz: 0)), isTrue);
    expect(hiss.matches(frame(pitchHz: 280)), isFalse);
    expect(hiss.matches(frame(voiced: false, pitchHz: 0)), isFalse);
  });

  test('a vowel call matches only its vowel', () {
    const baa = VowelSound(Vowel.a);
    final aScores = {Vowel.a: 1.0, Vowel.e: 6.0, Vowel.i: 9.0, Vowel.o: 5.0, Vowel.u: 4.0};
    final iScores = {Vowel.a: 8.0, Vowel.e: 4.0, Vowel.i: 1.0, Vowel.o: 9.0, Vowel.u: 7.0};
    expect(baa.matches(frame(scores: aScores)), isTrue);
    expect(baa.matches(frame(scores: iScores)), isFalse);
    expect(baa.matches(frame()), isFalse, reason: 'no scores: too unclear to judge');
  });

  test('animal progress is saved and read back; old profiles start empty', () {
    final p = Profile(id: 'x', avatar: Avatar.fox)
      ..animalsWoken['cow'] = 2
      ..animalSeconds = 12.5;
    final back = Profile.fromJson(p.toJson());
    expect(back.animalsWoken, {'cow': 2});
    expect(back.animalSeconds, 12.5);

    final old = Profile.fromJson(p.toJson()..remove('animalsWoken')..remove('animalSeconds'));
    expect(old.animalsWoken, isEmpty);
    expect(old.animalSeconds, 0);
  });
}
