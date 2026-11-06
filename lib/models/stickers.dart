import 'animals.dart';
import 'phonics.dart';
import 'profile.dart';

/// One sticker in the sticker book. Stickers are worked out from progress
/// the app already saves, so earlier play counts and nothing extra is stored.
class Sticker {
  const Sticker(this.id, this.image, this.label, this.earned);

  final String id;
  final String image;

  /// TalkBack name.
  final String label;
  final bool Function(Profile p) earned;
}

abstract final class Stickers {
  /// Every sticker this build can award, in book order.
  static List<Sticker> all() => [
        Sticker('canvas', 'assets/images/badge_canvas.webp', 'a painting', (p) => p.paintings > 0),
        for (final pic in Phonics.pictures)
          if (AssetCatalog.has(pic.image))
            Sticker('pic_${pic.id}', pic.image, pic.id, (p) => (p.pictureDone[pic.id] ?? 0) > 0),
        for (final a in Animals.all)
          if (AssetCatalog.has(a.image))
            Sticker('animal_${a.id}', a.image, 'the ${a.label}', (p) => (p.animalsWoken[a.id] ?? 0) > 0),
        Sticker('hill', 'assets/images/badge_hill.webp', 'the ice hill', (p) => p.hillStars >= 6),
        Sticker('lanterns', 'assets/images/badge_lanterns.webp', 'the lanterns', (p) => p.lanternsQuiet + p.lanternsLoud >= 8),
        Sticker('balloon', 'assets/images/badge_balloon.webp', 'the balloon', (p) => p.balloons > 0),
      ];

  static int earnedCount(Profile p) => all().where((s) => s.earned(p)).length;
}

/// Activities that can appear on today's path.
enum Activity {
  canvas('badge_canvas', 'Free Canvas'),
  safari('badge_safari', 'Phonics Safari'),
  animals('badge_animals', 'Animal Sounds'),
  hill('badge_hill', "Pip's Ice Hill"),
  lanterns('badge_lanterns', "Ollie's Lanterns"),
  balloon('badge_balloon', 'Breath Balloon');

  const Activity(this.badge, this.title);
  final String badge;
  final String title;
}

/// Today's path: three activities, the same all day so the routine is
/// predictable, and a different mix on the next day. Always one voice-range
/// game (hill, lanterns or balloon), one sound game (safari or animals) and
/// one free one (canvas).
abstract final class TodayPath {
  static const _range = [Activity.hill, Activity.lanterns, Activity.balloon];
  static const _sound = [Activity.safari, Activity.animals];

  static List<Activity> forDay(DateTime d) {
    final n = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2026)).inDays;
    return [_sound[n % _sound.length], _range[n % _range.length], Activity.canvas];
  }
}
