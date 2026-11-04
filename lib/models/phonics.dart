import 'package:flutter/services.dart';

import '../core/audio/dsp.dart';

/// One Phonics Safari picture: an object whose word starts with a vowel sound.
class PhonicsPicture {
  const PhonicsPicture(this.id, this.vowel);

  /// The word, also the asset name: `assets/images/obj_<id>.webp`.
  final String id;
  final Vowel vowel;

  String get image => 'assets/images/obj_$id.webp';

  /// Aria models the sound with this word ("Ant! Listen. aaa...").
  String get voiceLine => 'aria_$id';

  /// v1 line for the vowel, used until the picture's own line exists.
  String get fallbackVoiceLine => 'aria_${vowel.name}';
}

/// Phonics Safari chapters: one island per vowel, three pictures each.
/// The first picture of each island is the v1 picture.
abstract final class Phonics {
  static const pictures = <PhonicsPicture>[
    PhonicsPicture('apple', Vowel.a),
    PhonicsPicture('ant', Vowel.a),
    PhonicsPicture('alligator', Vowel.a),
    PhonicsPicture('egg', Vowel.e),
    PhonicsPicture('elephant', Vowel.e),
    PhonicsPicture('elf', Vowel.e),
    PhonicsPicture('igloo', Vowel.i),
    PhonicsPicture('insect', Vowel.i),
    PhonicsPicture('ink', Vowel.i),
    PhonicsPicture('octopus', Vowel.o),
    PhonicsPicture('ostrich', Vowel.o),
    PhonicsPicture('ox', Vowel.o),
    PhonicsPicture('umbrella', Vowel.u),
    PhonicsPicture('up', Vowel.u),
    PhonicsPicture('under', Vowel.u),
  ];

  /// Pictures on an island that are actually bundled with this build.
  static List<PhonicsPicture> island(Vowel v) =>
      [for (final p in pictures) if (p.vowel == v && AssetCatalog.has(p.image)) p];

  static PhonicsPicture byId(String id) => pictures.firstWhere((p) => p.id == id);
}

/// Which asset files this build contains. New chapters and voice lines are
/// added as their (owner-approved) assets arrive, so code checks presence
/// instead of assuming every file exists.
abstract final class AssetCatalog {
  static Set<String>? _assets;

  static Future<void> load() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _assets = manifest.listAssets().toSet();
    } catch (_) {
      _assets = null; // unknown: treat everything as present
    }
  }

  /// For tests: declare exactly which assets exist.
  static void debugSet(Set<String>? assets) => _assets = assets;

  static bool has(String path) => _assets?.contains(path) ?? true;

  /// Voice line [id] if bundled, else [fallback].
  static String voice(String id, String fallback) =>
      has('assets/audio/voice/$id.mp3') ? id : fallback;
}
