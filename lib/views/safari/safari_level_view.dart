import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/audio_input.dart';
import '../../core/audio/dsp.dart';
import '../../core/audio/sound_player.dart';
import '../../core/audio/voice_analyzer.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/listening.dart';

/// One Phonics Safari picture: Aria models the vowel, the child holds the
/// sound, and the picture colours itself in.
///
/// Errorless: any voice keeps colouring. In Practise level the target vowel
/// colours faster; in Explore level every sound counts the same.
class SafariLevelView extends StatefulWidget {
  const SafariLevelView({super.key, required this.vowel});

  final Vowel vowel;

  @override
  State<SafariLevelView> createState() => _SafariLevelViewState();
}

class _SafariLevelViewState extends ListeningState<SafariLevelView> {
  ui.Image? _color;
  double _progress = 0;
  bool _done = false;
  bool _showNext = false;
  double _level = 0;
  bool _matching = false;
  double _silence = 0;
  int _modelRepeats = 0;
  bool _saidHalf = false, _saidAlmost = false;
  double _celebrate = 0;
  List<_Spot> _spots = const [];

  Vowel get v => widget.vowel;
  bool get practise => profile.level == PlayLevel.practise;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load('assets/images/obj_${v.word}.webp');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final spots = await _spotsFor(frame.image);
    if (mounted) {
      setState(() {
        _color = frame.image;
        _spots = spots;
      });
    }
  }

  /// Reveal dabs cover only the picture's painted pixels (not its
  /// transparent surround), ordered from the centre outward with a little
  /// jitter, so the visible colouring matches the progress ring.
  static Future<List<_Spot>> _spotsFor(ui.Image img) async {
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return const [];
    const grid = 16;
    final w = img.width, h = img.height;
    final rand = math.Random(11);
    final cells = <(_Spot, double)>[];
    for (var gy = 0; gy < grid; gy++) {
      for (var gx = 0; gx < grid; gx++) {
        final x = ((gx + 0.5) / grid * w).floor(), y = ((gy + 0.5) / grid * h).floor();
        if (data.getUint8((y * w + x) * 4 + 3) < 60) continue;
        final c = Offset((gx + 0.5) / grid, (gy + 0.5) / grid);
        final d = (c - const Offset(0.5, 0.5)).distance + rand.nextDouble() * 0.12;
        cells.add((_Spot(c, 1.1 / grid), d));
      }
    }
    cells.sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final c in cells) c.$1];
  }

  @override
  void onStarted() => _model();

  Future<void> _model() async {
    _silence = 0;
    await services.sound.say('aria_${v.name}');
  }

  @override
  void onVoice(VoiceFrame f, double dt) {
    final speaking = services.sound.speaking.value;
    _level = smoothTo(_level, f.voiced ? f.level : 0, 8, dt);
    if (_done) {
      _celebrate += dt;
      setState(() {});
      return;
    }
    final stats = profile.vowels[v]!;
    var match = false;
    if (f.voiced) {
      _silence = 0;
      final scores = f.vowelScores;
      match = scores != null && VowelClassifier.matches(scores, v);
      stats.practiceSeconds += dt;
      if (match) stats.matchSeconds += dt;
      final rate = practise ? 0.045 + (match ? 0.095 : 0) : 0.11;
      _progress = math.min(1, _progress + rate * dt);
    } else if (!speaking) {
      _silence += dt;
    }
    _matching = match;

    if (_progress >= 1) {
      _finish();
    } else if (!speaking && _silence > 0.7) {
      if (_progress > 0.8 && !_saidAlmost) {
        _saidAlmost = true;
        services.sound.say('aria_almost');
      } else if (_progress > 0.4 && !_saidHalf) {
        _saidHalf = true;
        services.sound.say('aria_keep');
      } else if (_silence > 9) {
        // Model the sound again (repetition helps), then just wait kindly.
        if (_modelRepeats < 2) {
          _modelRepeats++;
          _model();
        } else if (_silence > 25) {
          _silence = 0;
          services.sound.say('aria_again');
        }
      }
    }
    setState(() {});
  }

  void _finish() {
    _done = true;
    _progress = 1;
    profile.vowels[v]!.pictures++;
    services.store.save();
    services.sound.sfx(Sfx.tada);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) services.sound.say('aria_yay');
    });
    Future<void>.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _showNext = true);
    });
  }

  void _again() {
    setState(() {
      _done = false;
      _showNext = false;
      _progress = 0;
      _celebrate = 0;
      _saidHalf = _saidAlmost = false;
      _modelRepeats = 0;
    });
    _model();
  }

  @override
  void dispose() {
    services.store.save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pic = size.height * 0.62;
    return Scene(
      background: 'bg_safari',
      dim: 0.45,
      child: Stack(children: [
        Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Semantics(
              label: 'Picture of ${v.word}',
              child: SizedBox(
                width: pic,
                height: pic,
                child: _color == null
                    ? null
                    : CustomPaint(
                        painter: _RevealPainter(_color!, _spots, _progress, _celebrate, profile.calmMode),
                      ),
              ),
            ),
            if (practise) ...[
              SizedBox(width: size.width * 0.03),
              _LetterBubble(letter: v.letter, glow: _matching, size: size.height * 0.3),
            ],
          ]),
        ),
        Positioned(
          left: 8,
          bottom: 0,
          child: IgnorePointer(
            child: CharacterView(
              character: Character.aria,
              pose: _done ? 'happy' : 'idle',
              height: size.height * 0.3,
              scale: 1 + 0.1 * _level,
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: GlowIconButton(icon: Icons.map_rounded, label: 'Back to the map', onTap: () => Navigator.pop(context)),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GlowIconButton(icon: Icons.hearing_rounded, label: 'Hear Aria again', color: SP.amber, onTap: _model),
        ),
        if (!_showNext)
          Positioned(
            bottom: 16,
            right: 16,
            child: IgnorePointer(child: _ProgressRing(progress: _progress, size: 72)),
          ),
        if (_showNext)
          Positioned(
            right: 24,
            top: 0,
            bottom: 0,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              GlowIconButton(icon: Icons.replay_rounded, label: 'Colour it again', size: 104, onTap: _again),
              const SizedBox(height: 28),
              GlowIconButton(
                icon: Icons.map_rounded,
                label: 'Back to the map',
                size: 104,
                color: SP.amber,
                onTap: () => Navigator.pop(context, true),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _Spot {
  const _Spot(this.c, this.r);
  final Offset c;
  final double r;
}

class _RevealPainter extends CustomPainter {
  _RevealPainter(this.img, this.spots, this.progress, this.celebrate, this.calm);

  final ui.Image img;
  final List<_Spot> spots;
  final double progress;
  final double celebrate;
  final bool calm;

  // Soft greyscale "not yet coloured" look. No offset column: offsets would
  // brighten fully transparent pixels in premultiplied colour and draw
  // ghostly edges around the picture.
  static const _grey = ColorFilter.matrix([
    0.3, 0.45, 0.15, 0, 0, //
    0.3, 0.45, 0.15, 0, 0,
    0.3, 0.45, 0.15, 0, 0,
    0, 0, 0, 0.55, 0,
  ]);

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final fit = applyBoxFit(BoxFit.contain, src.size, size);
    final dst = Alignment.center.inscribe(fit.destination, Offset.zero & size);

    // Faded outline version: shows what the child is colouring.
    canvas.drawImageRect(img, src, dst, Paint()..colorFilter = _grey);

    // Coloured version, painted through soft round dabs that grow as the
    // child keeps sounding (an image shader: no offscreen layer needed).
    if (progress >= 1) {
      canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.medium);
    } else if (progress > 0) {
      final sx = dst.width / src.width, sy = dst.height / src.height;
      final m = Matrix4.identity()
        ..translateByDouble(dst.left, dst.top, 0, 1)
        ..scaleByDouble(sx, sy, 1, 1);
      final dab = Paint()
        ..shader = ImageShader(img, TileMode.decal, TileMode.decal, m.storage, filterQuality: FilterQuality.medium)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      final n = spots.length * progress;
      for (var i = 0; i < spots.length && i < n.ceil(); i++) {
        final s = spots[i];
        final grow = (n - i).clamp(0.0, 1.0);
        final center = Offset(dst.left + s.c.dx * dst.width, dst.top + s.c.dy * dst.height);
        canvas.drawCircle(center, s.r * dst.width * (0.4 + 0.6 * grow), dab);
      }
    }

    // Celebration: a ring of stars bursting out once complete.
    if (celebrate > 0 && !calm) {
      final t = (celebrate / 1.6).clamp(0.0, 1.0);
      final c = dst.center;
      for (var i = 0; i < 14; i++) {
        final a = i / 14 * math.pi * 2;
        final d = dst.width * (0.3 + 0.45 * Curves.easeOut.transform(t));
        final p = c + Offset(math.cos(a), math.sin(a)) * d;
        final col = HSVColor.fromAHSV(1 - t, (i * 26.0) % 360, 0.7, 1).toColor();
        _star(canvas, p, 10 + 8 * (1 - t), col);
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RevealPainter old) =>
      old.progress != progress || old.celebrate != celebrate || old.img != img;
}

class _LetterBubble extends StatelessWidget {
  const _LetterBubble({required this.letter, required this.glow, required this.size});

  final String letter;
  final bool glow;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SP.cream,
        border: Border.all(color: glow ? SP.teal : SP.lilac, width: glow ? 8 : 4),
        boxShadow: [
          BoxShadow(color: (glow ? SP.teal : SP.lilac).withValues(alpha: glow ? 0.8 : 0.3), blurRadius: glow ? 36 : 16),
        ],
      ),
      child: Text(
        letter,
        style: TextStyle(fontFamily: SP.font, fontSize: size * 0.62, height: 1, color: SP.plum, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress, required this.size});

  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 10,
            color: SP.teal,
            backgroundColor: SP.night.withValues(alpha: 0.6),
            strokeCap: StrokeCap.round,
          ),
        ),
        Icon(progress >= 1 ? Icons.star_rounded : Icons.brush_rounded, color: progress >= 1 ? SP.amber : SP.teal, size: size * 0.45),
      ]),
    );
  }
}
