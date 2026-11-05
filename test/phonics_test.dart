import 'package:flutter_test/flutter_test.dart';
import 'package:sound_painter/core/audio/dsp.dart';
import 'package:sound_painter/core/audio/sound_player.dart';
import 'package:sound_painter/models/phonics.dart';
import 'package:sound_painter/models/profile.dart';

void main() {
  tearDown(() => AssetCatalog.debugSet(null));

  test('15 pictures, three per vowel, v1 picture first on each island', () {
    expect(Phonics.pictures, hasLength(15));
    for (final v in Vowel.values) {
      final island = Phonics.pictures.where((p) => p.vowel == v).toList();
      expect(island, hasLength(3), reason: '$v');
      expect(island.first.id, v.word, reason: 'v1 picture stays first');
      expect(island.every((p) => p.id.startsWith(v.letter)), isTrue);
    }
  });

  test('islands only offer pictures whose images are bundled', () {
    AssetCatalog.debugSet({'assets/images/obj_apple.webp', 'assets/images/obj_ant.webp'});
    expect(Phonics.island(Vowel.a).map((p) => p.id), ['apple', 'ant']);
    expect(Phonics.island(Vowel.e), isEmpty);
  });

  test('a picture uses its own voice line once bundled, else the v1 line', () {
    final ant = Phonics.byId('ant');
    AssetCatalog.debugSet({});
    expect(AssetCatalog.voice(ant.voiceLine, ant.fallbackVoiceLine), 'aria_a');
    AssetCatalog.debugSet({voiceAsset('aria_ant')});
    expect(AssetCatalog.voice(ant.voiceLine, ant.fallbackVoiceLine), 'aria_ant');
    expect(voiceAsset('aria_ant'), startsWith('assets/audio/homidev/'), reason: 'approved Kokoro line');
    expect(voiceAsset('no_such_line'), 'assets/audio/voice/no_such_line.mp3', reason: 'v1 line until re-voiced');
  });

  test('v1 progress (per vowel) moves to that vowel\'s first picture', () {
    final v1 = Profile(id: 'x', avatar: Avatar.fox).toJson()
      ..remove('pictureDone')
      ..['vowels'] = {'a': {'practice': 12.0, 'match': 5.0, 'pictures': 2}, 'o': {'pictures': 1}};
    final p = Profile.fromJson(v1);
    expect(p.pictureDone, {'apple': 2, 'octopus': 1});
    expect(Profile.fromJson(p.toJson()).pictureDone, {'apple': 2, 'octopus': 1});
  });
}
