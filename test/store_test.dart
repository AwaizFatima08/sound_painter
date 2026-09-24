import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_painter/core/audio/dsp.dart';
import 'package:sound_painter/models/profile.dart';
import 'package:sound_painter/services/store.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('sp_store'));
  tearDown(() => dir.delete(recursive: true));

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 600));

  test('profiles, progress and settings survive a restart', () async {
    final s = await Store.open(dir);
    expect(s.isSetUp, isFalse);
    final p = s.addProfile(avatar: Avatar.frog, nickname: 'Zoya', level: PlayLevel.practise);
    p.vowels[Vowel.e]!.pictures = 3;
    p.calibration = p.calibration.copyWith(sensitivity: 1.5, lowHz: 210);
    p.sessions.add(SessionRecord(start: DateTime(2026, 9, 1), seconds: 300, lowHz: 200, highHz: 480));
    s.settings.musicOn = false;
    s.save();
    await settle();

    final again = await Store.open(dir);
    final q = again.active!;
    expect(q.nickname, 'Zoya');
    expect(q.avatar, Avatar.frog);
    expect(q.level, PlayLevel.practise);
    expect(q.vowels[Vowel.e]!.pictures, 3);
    expect(q.calibration.sensitivity, 1.5);
    expect(q.calibration.lowHz, 210);
    expect(q.sessions.single.highHz, 480);
    expect(again.settings.musicOn, isFalse);
  });

  test('a corrupt file never locks the child out', () async {
    await File('${dir.path}/sound_painter.json').writeAsString('{not json');
    final s = await Store.open(dir);
    expect(s.isSetUp, isFalse);
    expect(File('${dir.path}/sound_painter.json.corrupt').existsSync(), isTrue);
  });

  test('gallery keeps newest paintings and deletes with the profile', () async {
    final s = await Store.open(dir);
    final p = s.addProfile(avatar: Avatar.cat);
    for (var i = 0; i < Store.maxPaintings + 3; i++) {
      await s.addPainting(p, Uint8List.fromList([i]));
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect((await s.paintings(p)).length, Store.maxPaintings);
    expect(p.paintings, Store.maxPaintings + 3);
    await s.deleteProfile(p);
    expect(s.profiles, isEmpty);
    expect(await s.paintings(p), isEmpty);
  });

  test('rapid saves never overlap or lose the last change', () async {
    final s = await Store.open(dir);
    final p = s.addProfile(avatar: Avatar.bear);
    for (var i = 0; i < 50; i++) {
      p.paintings = i;
      s.save();
      await Future<void>.delayed(const Duration(milliseconds: 7));
    }
    await settle();
    expect((await Store.open(dir)).active!.paintings, 49);
  });
}
