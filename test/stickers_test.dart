import 'package:flutter_test/flutter_test.dart';
import 'package:sound_painter/models/phonics.dart';
import 'package:sound_painter/models/profile.dart';
import 'package:sound_painter/models/stickers.dart';

void main() {
  setUp(() => AssetCatalog.debugSet(null)); // every asset counts as bundled

  test('stickers come from saved progress, so earlier play counts', () {
    final p = Profile(id: 'x', avatar: Avatar.fox);
    expect(Stickers.earnedCount(p), 0);
    p
      ..paintings = 1
      ..pictureDone['ant'] = 1
      ..animalsWoken['lion'] = 3
      ..hillStars = 6
      ..balloons = 1;
    final earned = {for (final s in Stickers.all()) if (s.earned(p)) s.id};
    expect(earned, {'canvas', 'pic_ant', 'animal_lion', 'hill', 'balloon'});
    expect(Stickers.all().length, 1 + 15 + 7 + 3);
  });

  test('only bundled pictures appear in the book', () {
    AssetCatalog.debugSet({'assets/images/obj_apple.webp', 'assets/images/animal_cow.webp'});
    final ids = Stickers.all().map((s) => s.id).toSet();
    expect(ids.containsAll({'pic_apple', 'animal_cow'}), isTrue);
    expect(ids.contains('pic_ant'), isFalse);
    expect(ids.contains('animal_lion'), isFalse);
  });

  test("today's path: one sound game, one range game, then the canvas; changes daily", () {
    final days = [for (var d = 1; d <= 6; d++) TodayPath.forDay(DateTime(2026, 11, d))];
    for (final path in days) {
      expect(path, hasLength(3));
      expect([Activity.safari, Activity.animals], contains(path[0]));
      expect([Activity.hill, Activity.lanterns, Activity.balloon], contains(path[1]));
      expect(path[2], Activity.canvas);
    }
    expect(days.map((p) => p.join()).toSet().length, greaterThan(1));
    expect(TodayPath.forDay(DateTime(2026, 11, 7, 8)), TodayPath.forDay(DateTime(2026, 11, 7, 20)), reason: 'same all day');
  });

  test('done today resets on a new day and is saved', () {
    final p = Profile(id: 'x', avatar: Avatar.fox);
    final mon = DateTime(2026, 11, 9, 10), tue = DateTime(2026, 11, 10, 9);
    p.markDone('hill', mon);
    expect(p.doneToday('hill', mon), isTrue);
    expect(p.doneToday('hill', tue), isFalse, reason: 'a new day starts fresh');
    final back = Profile.fromJson(p.toJson());
    expect(back.doneToday('hill', mon), isTrue);
    p.markDone('safari', tue);
    expect(p.todayDone, {'safari'});
  });
}
