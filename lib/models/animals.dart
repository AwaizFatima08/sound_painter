import '../core/audio/dsp.dart';
import '../core/audio/voice_analyzer.dart';

/// How a close copy of an animal's sound is recognised. Any voice still
/// wakes the animal; a close copy only wakes it faster (Practise level).
sealed class AnimalSound {
  const AnimalSound();

  bool matches(VoiceFrame f);
}

/// A vowel-like call ("moo", "baa", "roar"): the vowel recogniser.
class VowelSound extends AnimalSound {
  const VowelSound(this.vowel);
  final Vowel vowel;

  @override
  bool matches(VoiceFrame f) {
    final scores = f.vowelScores;
    return f.voiced && scores != null && VowelClassifier.matches(scores, vowel);
  }
}

/// A hiss: sound with no pitch.
class HissSound extends AnimalSound {
  const HissSound();

  @override
  bool matches(VoiceFrame f) => f.voiced && f.pitchHz == 0;
}

/// One sleeping animal in Animal Sounds.
class FarmAnimal {
  const FarmAnimal(this.id, this.sound);

  /// Also the asset names: `assets/images/animal_<id>.webp`, voice line
  /// `animal_<id>`.
  final String id;
  final AnimalSound sound;

  String get image => 'assets/images/animal_$id.webp';
  String get voiceLine => 'animal_$id';

  /// TalkBack name; the dog is called a puppy in Aria's line.
  String get label => id == 'dog' ? 'puppy' : id;
}

abstract final class Animals {
  // Closest of the five vowels to each call (the recogniser has no "oo").
  static const all = <FarmAnimal>[
    FarmAnimal('cow', VowelSound(Vowel.u)),
    FarmAnimal('sheep', VowelSound(Vowel.a)),
    FarmAnimal('cat', VowelSound(Vowel.e)),
    FarmAnimal('dog', VowelSound(Vowel.u)),
    FarmAnimal('duck', VowelSound(Vowel.a)),
    FarmAnimal('snake', HissSound()),
    FarmAnimal('lion', VowelSound(Vowel.o)),
  ];
}
