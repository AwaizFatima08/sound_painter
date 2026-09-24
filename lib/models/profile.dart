import '../core/audio/dsp.dart';
import '../core/audio/voice_analyzer.dart';

/// Animal friends a child picks as their profile picture. The app never asks
/// for a child's real name or photo.
enum Avatar { fox, bunny, bear, frog, elephant, cat }

/// How much structure the activities give. Chosen by the parent, not by age.
enum PlayLevel {
  /// Any sound counts fully. Suits early and younger learners.
  explore,

  /// The matching vowel colours pictures faster; letters are shown.
  practise,
}

class VowelStats {
  VowelStats({this.practiceSeconds = 0, this.matchSeconds = 0, this.pictures = 0});

  /// Seconds of voice while this vowel's picture was open.
  double practiceSeconds;

  /// Of those, seconds that sounded like the target vowel.
  double matchSeconds;

  /// Pictures fully coloured in.
  int pictures;

  Map<String, dynamic> toJson() =>
      {'practice': practiceSeconds, 'match': matchSeconds, 'pictures': pictures};

  factory VowelStats.fromJson(Map<String, dynamic>? j) => VowelStats(
        practiceSeconds: (j?['practice'] as num?)?.toDouble() ?? 0,
        matchSeconds: (j?['match'] as num?)?.toDouble() ?? 0,
        pictures: (j?['pictures'] as num?)?.toInt() ?? 0,
      );
}

/// One play session: from picking a profile until the app goes to the
/// background, the session timer ends it, or another child takes over.
class SessionRecord {
  SessionRecord({
    required this.start,
    this.seconds = 0,
    this.voiceSeconds = 0,
    this.lowHz = 0,
    this.highHz = 0,
  });

  final DateTime start;
  double seconds;

  /// Seconds the child was actually making sound.
  double voiceSeconds;

  /// 10th and 90th percentile of the child's pitch this session (0 = none).
  double lowHz;
  double highHz;

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'seconds': seconds,
        'voice': voiceSeconds,
        'low': lowHz,
        'high': highHz,
      };

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
        start: DateTime.tryParse(j['start'] as String? ?? '') ?? DateTime.now(),
        seconds: (j['seconds'] as num?)?.toDouble() ?? 0,
        voiceSeconds: (j['voice'] as num?)?.toDouble() ?? 0,
        lowHz: (j['low'] as num?)?.toDouble() ?? 0,
        highHz: (j['high'] as num?)?.toDouble() ?? 0,
      );
}

class Profile {
  Profile({
    required this.id,
    required this.avatar,
    this.nickname = '',
    this.level = PlayLevel.explore,
    this.calibration = const Calibration(),
    this.warmedUp = false,
    this.calmMode = false,
    this.sessionMinutes = 0,
    Map<Vowel, VowelStats>? vowels,
    List<SessionRecord>? sessions,
    this.paintings = 0,
  })  : vowels = vowels ?? {for (final v in Vowel.values) v: VowelStats()},
        sessions = sessions ?? [];

  final String id;
  Avatar avatar;
  String nickname;
  PlayLevel level;
  Calibration calibration;

  /// Whether Pip's warm-up has measured this child's voice yet.
  bool warmedUp;

  /// Fewer particles, softer colours, slower motion.
  bool calmMode;

  /// Gentle stop after this many minutes; 0 = no limit.
  int sessionMinutes;

  final Map<Vowel, VowelStats> vowels;
  final List<SessionRecord> sessions;
  int paintings;

  /// Keep a year of daily play at most.
  static const maxSessions = 400;

  String get displayName => nickname.trim().isEmpty ? _avatarName : nickname.trim();

  String get _avatarName => const {
        Avatar.fox: 'Fox',
        Avatar.bunny: 'Bunny',
        Avatar.bear: 'Bear',
        Avatar.frog: 'Frog',
        Avatar.elephant: 'Elephant',
        Avatar.cat: 'Kitten',
      }[avatar]!;

  Map<String, dynamic> toJson() => {
        'id': id,
        'avatar': avatar.name,
        'nickname': nickname,
        'level': level.name,
        'calibration': calibration.toJson(),
        'warmedUp': warmedUp,
        'calm': calmMode,
        'sessionMinutes': sessionMinutes,
        'vowels': {for (final e in vowels.entries) e.key.name: e.value.toJson()},
        'sessions': [for (final s in sessions) s.toJson()],
        'paintings': paintings,
      };

  factory Profile.fromJson(Map<String, dynamic> j) {
    final vj = (j['vowels'] as Map?)?.cast<String, dynamic>() ?? {};
    return Profile(
      id: j['id'] as String,
      avatar: Avatar.values.asNameMap()[j['avatar']] ?? Avatar.fox,
      nickname: j['nickname'] as String? ?? '',
      level: PlayLevel.values.asNameMap()[j['level']] ?? PlayLevel.explore,
      calibration: Calibration.fromJson((j['calibration'] as Map?)?.cast<String, dynamic>() ?? {}),
      warmedUp: j['warmedUp'] as bool? ?? false,
      calmMode: j['calm'] as bool? ?? false,
      sessionMinutes: (j['sessionMinutes'] as num?)?.toInt() ?? 0,
      vowels: {
        for (final v in Vowel.values) v: VowelStats.fromJson((vj[v.name] as Map?)?.cast<String, dynamic>()),
      },
      sessions: [
        for (final s in (j['sessions'] as List?) ?? const [])
          SessionRecord.fromJson((s as Map).cast<String, dynamic>()),
      ],
      paintings: (j['paintings'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Device-wide settings (not per child).
class AppSettings {
  AppSettings({this.voiceVolume = 1.0, this.musicVolume = 0.35, this.musicOn = true});

  double voiceVolume;
  double musicVolume;
  bool musicOn;

  Map<String, dynamic> toJson() => {'voice': voiceVolume, 'music': musicVolume, 'musicOn': musicOn};

  factory AppSettings.fromJson(Map<String, dynamic>? j) => AppSettings(
        voiceVolume: (j?['voice'] as num?)?.toDouble() ?? 1.0,
        musicVolume: (j?['music'] as num?)?.toDouble() ?? 0.35,
        musicOn: j?['musicOn'] as bool? ?? true,
      );
}
