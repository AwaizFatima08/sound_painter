import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/audio/audio_input.dart';
import '../../core/audio/voice_analyzer.dart';
import '../../core/theme.dart';

/// Turns voice (and fingers) into paint.
///
/// - Height on screen follows pitch; colour follows pitch (violet low, warm
///   red high, as in the GDD); brush size and flow follow loudness.
/// - With no finger down, a "brush comet" sweeps across the page by itself,
///   so singing alone paints flowing ribbons.
/// - A finger moves the brush; voice still sets colour and size. With no
///   voice (or no mic) a finger paints rainbow colours on its own.
///
/// Paint accumulates in a baked image, so drawing cost stays flat however
/// long a child paints. Soft glow comes from one pre-rendered sprite drawn
/// with drawAtlas, not a blur per particle.
class PaintEngine {
  PaintEngine({this.calm = false});

  bool calm;
  final _rand = math.Random();

  Size _size = Size.zero;
  double _pixelRatio = 1;

  ui.Image? _sprite;
  ui.Image? _baked;

  /// Replaced images are freed a couple of bakes later, never while a frame
  /// that still draws them may be in flight on the raster thread.
  final _retired = <ui.Image>[];
  final _pending = <_Dot>[];
  final _sparkles = <_Sparkle>[];
  double _sinceBake = 0;
  double _time = 0;

  /// How much has been painted (dots); used to decide whether to save.
  int painted = 0;

  // Brush comet.
  Offset _brush = Offset.zero;
  double _dir = 1;
  double _emitDebt = 0;
  Offset? _finger;
  double _hue = 280;

  /// Last computed brush position and colour (for the glowing cursor).
  Offset get brush => _brush;
  Color get brushColor => HSVColor.fromAHSV(1, _hue % 360, calm ? 0.55 : 0.8, 1).toColor();
  bool active = false;

  void resize(Size size, double pixelRatio) {
    if (size == _size) return;
    final old = _size;
    _size = size;
    _pixelRatio = pixelRatio.clamp(1.0, 2.0);
    if (old == Size.zero) {
      _brush = Offset(size.width * 0.1, size.height * 0.5);
    } else {
      // Keep existing paint, scaled to the new size (rotation, split screen).
      _bake(resizeFrom: old);
    }
  }

  void fingerDown(Offset p) => _finger = p;
  void fingerMove(Offset p) => _finger = p;
  void fingerUp() => _finger = null;

  ui.Image _makeSprite() {
    const s = 64.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(s / 2, s / 2),
        s / 2,
        [Colors.white, Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)],
        [0, 0.5, 0.78, 1],
      );
    c.drawCircle(const Offset(s / 2, s / 2), s / 2, paint);
    return rec.endRecording().toImageSync(s.toInt(), s.toInt());
  }

  void update(double dt, VoiceFrame f) {
    if (_size == Size.zero) return;
    _sprite ??= _makeSprite();
    _time += dt;
    final w = _size.width, h = _size.height;
    final voiced = f.voiced && f.level > 0;

    // Colour: pitched voice sets it; hums without pitch, blowing, clapping or
    // a finger alone cycle gently through the rainbow.
    if (voiced && f.pitched) {
      _hue = hueForPitch(f.pitchNorm) + (_rand.nextDouble() - 0.5) * 10;
    } else {
      _hue = (_hue + dt * 45) % 360;
    }

    if (_finger != null) {
      _brush = _finger!;
    } else if (voiced) {
      final speed = (calm ? 0.07 : 0.1) + 0.22 * f.level;
      var x = _brush.dx + _dir * speed * w * dt;
      if (x > w * 0.93) {
        x = w * 0.93;
        _dir = -1;
      } else if (x < w * 0.07) {
        x = w * 0.07;
        _dir = 1;
      }
      final targetY = f.pitched ? lerpD(h * 0.86, h * 0.12, f.pitchNorm) : _brush.dy;
      var y = smoothTo(_brush.dy, targetY, 5, dt);
      y += math.sin(_time * 3.1) * 14 * f.level * dt * 8;
      _brush = Offset(x, y.clamp(h * 0.06, h * 0.94));
    }

    active = voiced || _finger != null;
    if (active) {
      final level = voiced ? f.level : 0.35;
      final rate = (calm ? 45.0 : 110.0) * (0.35 + level);
      final radius = (voiced ? 6 + 38 * f.level : 14) * (calm ? 0.85 : 1);
      _emitDebt += rate * dt;
      final color = HSVColor.fromAHSV(1, _hue % 360, calm ? 0.55 : 0.82, 1).toColor();
      while (_emitDebt >= 1) {
        _emitDebt -= 1;
        final j = radius * 0.4;
        _pending.add(_Dot(
          _brush + Offset((_rand.nextDouble() - 0.5) * 2 * j, (_rand.nextDouble() - 0.5) * 2 * j),
          radius * (0.75 + _rand.nextDouble() * 0.5),
          color.withValues(alpha: 0.5),
        ));
        painted++;
        if (!calm && voiced && _rand.nextDouble() < 0.25) {
          final a = _rand.nextDouble() * math.pi * 2;
          final sp = 30 + _rand.nextDouble() * 70;
          _sparkles.add(_Sparkle(_brush, Offset(math.cos(a) * sp, math.sin(a) * sp - 30),
              3 + _rand.nextDouble() * 5, color, 0.6 + _rand.nextDouble() * 0.6));
        }
      }
    } else {
      _emitDebt = 0;
    }

    for (final s in _sparkles) {
      s.pos += s.vel * dt;
      s.vel = s.vel * math.pow(0.4, dt).toDouble() + const Offset(0, -20) * dt;
      s.life -= dt;
    }
    _sparkles.removeWhere((s) => s.life <= 0);
    if (_sparkles.length > 400) _sparkles.removeRange(0, _sparkles.length - 400);

    _sinceBake += dt;
    // Pending dots are cheap to draw live (one drawAtlas call), so bake
    // rarely: fewer GPU texture allocations.
    if (_pending.length > 1500 || (_sinceBake > 2.5 && _pending.isNotEmpty)) _bake();
  }

  void _drawDots(Canvas c, List<_Dot> dots) {
    final sprite = _sprite;
    if (sprite == null || dots.isEmpty) return;
    const src = Rect.fromLTWH(0, 0, 64, 64);
    c.drawAtlas(
      sprite,
      [for (final d in dots) RSTransform.fromComponents(
          rotation: 0, scale: d.r / 32, anchorX: 32, anchorY: 32, translateX: d.p.dx, translateY: d.p.dy)],
      [for (var i = 0; i < dots.length; i++) src],
      [for (final d in dots) d.c],
      BlendMode.modulate,
      null,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  void _bake({Size? resizeFrom}) {
    _sinceBake = 0;
    final pw = (_size.width * _pixelRatio).round(), ph = (_size.height * _pixelRatio).round();
    if (pw <= 0 || ph <= 0) return;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final prev = _baked;
    if (prev != null) {
      c.drawImageRect(prev, Rect.fromLTWH(0, 0, prev.width.toDouble(), prev.height.toDouble()),
          Rect.fromLTWH(0, 0, pw.toDouble(), ph.toDouble()), Paint()..filterQuality = FilterQuality.medium);
    }
    if (resizeFrom == null) {
      c.scale(_pixelRatio);
      _drawDots(c, _pending);
      _pending.clear();
    }
    _baked = rec.endRecording().toImageSync(pw, ph);
    _retire(prev);
  }

  void _retire(ui.Image? img) {
    if (img == null) return;
    _retired.add(img);
    while (_retired.length > 2) {
      _retired.removeAt(0).dispose();
    }
  }

  void clear() {
    _pending.clear();
    _sparkles.clear();
    _retire(_baked);
    _baked = null;
    painted = 0;
  }

  void paint(Canvas canvas) {
    final baked = _baked;
    if (baked != null) {
      canvas.drawImageRect(baked, Rect.fromLTWH(0, 0, baked.width.toDouble(), baked.height.toDouble()),
          Offset.zero & _size, Paint()..filterQuality = FilterQuality.medium);
    }
    _drawDots(canvas, _pending);

    final sprite = _sprite;
    if (sprite != null && _sparkles.isNotEmpty) {
      const src = Rect.fromLTWH(0, 0, 64, 64);
      canvas.drawAtlas(
        sprite,
        [for (final s in _sparkles) RSTransform.fromComponents(
            rotation: 0, scale: s.size / 32, anchorX: 32, anchorY: 32, translateX: s.pos.dx, translateY: s.pos.dy)],
        [for (var i = 0; i < _sparkles.length; i++) src],
        [for (final s in _sparkles) s.color.withValues(alpha: (s.life / s.maxLife).clamp(0.0, 1.0))],
        BlendMode.modulate,
        null,
        Paint()..blendMode = BlendMode.plus,
      );
    }

    // Brush cursor: a soft glowing ring where the paint comes out.
    if (active || _finger == null) {
      final pulse = 1 + 0.08 * math.sin(_time * 5);
      canvas.drawCircle(
        _brush,
        14 * pulse,
        Paint()
          ..color = brushColor.withValues(alpha: active ? 0.9 : 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  /// The painting on the canvas background colour, as PNG bytes.
  Future<Uint8List?> exportPng() async {
    _bake();
    final baked = _baked;
    if (baked == null) return null;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final r = Rect.fromLTWH(0, 0, baked.width.toDouble(), baked.height.toDouble());
    c.drawRect(r, Paint()..color = SP.night);
    c.drawImage(baked, Offset.zero, Paint());
    final img = await rec.endRecording().toImage(baked.width, baked.height);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  /// Images still referenced by the last frames are left to the garbage
  /// collector rather than freed here.
  void dispose() {
    _retired.clear();
    _baked = null;
    _sprite = null;
  }
}

class _Dot {
  _Dot(this.p, this.r, this.c);
  final Offset p;
  final double r;
  final Color c;
}

class _Sparkle {
  _Sparkle(this.pos, this.vel, this.size, this.color, this.maxLife) : life = maxLife;
  Offset pos;
  Offset vel;
  final double size;
  final Color color;
  final double maxLife;
  double life;
}
