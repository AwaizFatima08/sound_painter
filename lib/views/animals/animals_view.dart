import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/audio_input.dart';
import '../../core/audio/sound_player.dart';
import '../../core/audio/voice_analyzer.dart';
import '../../core/theme.dart';
import '../../models/animals.dart';
import '../../models/profile.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/listening.dart';

/// Animal Sounds: seven animals sleep on the farm. The child taps one, Aria
/// models its call, and the child's voice wakes it up.
///
/// Errorless: any voice wakes the animal. In Practise level a close copy of
/// the call (the right vowel, or a hiss for the snake) wakes it faster.
class AnimalsView extends StatefulWidget {
  const AnimalsView({super.key});

  @override
  State<AnimalsView> createState() => _AnimalsViewState();
}

class _AnimalsViewState extends ListeningState<AnimalsView> {
  /// Woken during this visit; every visit starts with the farm asleep.
  final _awake = <String>{};
  FarmAnimal? _focus;
  double _wake = 0;
  bool _woken = false;
  double _level = 0;
  bool _matching = false;
  double _silence = 0;
  int _modelRepeats = 0;
  double _since = 0;
  int _wokeLine = 0;

  bool get practise => profile.level == PlayLevel.practise;

  @override
  void onStarted() {
    services.voice.scoreVowels = true;
    services.sound.say('animals_intro');
  }

  Future<void> _open(FarmAnimal a) async {
    await services.sound.hush();
    if (!mounted) return;
    setState(() {
      _focus = a;
      _wake = 0;
      _woken = false;
      _since = 0;
      _modelRepeats = 0;
    });
    _model();
  }

  Future<void> _model() async {
    _silence = 0;
    final a = _focus;
    if (a != null) await services.sound.say(a.voiceLine);
  }

  Future<void> _backToFarm() async {
    await services.sound.hush();
    if (!mounted) return;
    setState(() => _focus = null);
    if (_awake.length == Animals.all.length) services.sound.say('animals_all');
  }

  @override
  void onVoice(VoiceFrame f, double dt) {
    final speaking = services.sound.speaking.value;
    _level = smoothTo(_level, f.voiced ? f.level : 0, 8, dt);
    _since += dt;
    final a = _focus;
    if (a == null) {
      setState(() {});
      return;
    }
    if (_woken) {
      // Celebrate a moment, then go back to the farm by itself.
      if (_since > 3.2) _backToFarm();
      setState(() {});
      return;
    }
    var match = false;
    if (f.voiced) {
      _silence = 0;
      match = a.sound.matches(f);
      profile.animalSeconds += dt;
      final rate = practise ? 0.05 + (match ? 0.1 : 0) : 0.12;
      _wake = math.min(1, _wake + rate * dt);
    } else if (!speaking) {
      _silence += dt;
    }
    _matching = match;

    if (_wake >= 1) {
      _wakeUp(a);
    } else if (!speaking && _silence > 9) {
      // Model the call again (repetition helps), then just wait kindly.
      if (_modelRepeats < 2) {
        _modelRepeats++;
        _model();
      } else if (_silence > 25) {
        _silence = 0;
        services.sound.say('aria_again');
      }
    }
    setState(() {});
  }

  void _wakeUp(FarmAnimal a) {
    _woken = true;
    _wake = 1;
    _since = 0;
    _awake.add(a.id);
    profile.animalsWoken.update(a.id, (n) => n + 1, ifAbsent: () => 1);
    profile.markDone('animals');
    services.store.save();
    services.sound.sfx(Sfx.tada);
    final line = _wokeLine.isEven ? 'animals_woke1' : 'animals_woke2';
    _wokeLine++;
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (mounted) services.sound.say(line);
    });
  }

  @override
  void dispose() {
    services.store.save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final focus = _focus;
    return ColoredBox(
      color: SP.night,
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: FarmPainter(dim: focus == null ? 0 : 0.35)),
        SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: focus == null ? _farm(size) : _waking(size, focus),
          ),
        ),
      ]),
    );
  }

  Widget _farm(Size size) {
    final cell = math.min(size.height * 0.34, size.width * 0.16);
    Widget animal(FarmAnimal a, double phase) {
      final awake = _awake.contains(a.id);
      final ever = (profile.animalsWoken[a.id] ?? 0) > 0;
      return Bob(
        phase: phase,
        amount: awake ? 8 : 3,
        child: BouncyButton(
          label: awake ? 'The ${a.label} is awake' : 'The sleeping ${a.label}',
          onTap: () => _open(a),
          child: SizedBox(
            width: cell,
            height: cell * 1.12,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
              SleepyAnimal(image: a.image, size: cell, wake: awake ? 1 : 0, calm: profile.calmMode),
              Positioned(
                bottom: 0,
                child: Icon(ever ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: ever ? SP.amber : SP.cream.withValues(alpha: 0.7),
                    size: cell * 0.2,
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 6)]),
              ),
            ]),
          ),
        ),
      );
    }

    final top = Animals.all.sublist(0, 4), bottom = Animals.all.sublist(4);
    return Stack(children: [
      Align(
        alignment: const Alignment(0.1, 0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < top.length; i++) ...[
              if (i > 0) SizedBox(width: size.width * 0.03),
              animal(top[i], i * 0.17),
            ],
          ]),
          SizedBox(height: size.height * 0.02),
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < bottom.length; i++) ...[
              if (i > 0) SizedBox(width: size.width * 0.03),
              animal(bottom[i], 0.6 + i * 0.17),
            ],
          ]),
        ]),
      ),
      Positioned(
        left: 4,
        bottom: 0,
        child: IgnorePointer(child: CharacterView(character: Character.aria, pose: 'idle', height: size.height * 0.28)),
      ),
      Positioned(
        top: 12,
        left: 12,
        child: GlowIconButton(icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.pop(context)),
      ),
    ]);
  }

  Widget _waking(Size size, FarmAnimal a) {
    final big = size.height * 0.62;
    final hop = _woken && !profile.calmMode ? math.sin(math.min(_since, 1.2) / 1.2 * math.pi * 3).abs() * 26 : 0.0;
    return Stack(key: ValueKey(a.id), children: [
      Center(
        child: Transform.translate(
          offset: Offset(0, -hop),
          child: Transform.scale(
            scale: 1 + (_woken ? 0 : 0.06 * _level),
            child: SleepyAnimal(image: a.image, size: big, wake: _wake, calm: profile.calmMode, glow: _matching),
          ),
        ),
      ),
      Positioned(
        left: 8,
        bottom: 0,
        child: IgnorePointer(
          child: CharacterView(
            character: Character.aria,
            pose: _woken ? 'happy' : 'idle',
            height: size.height * 0.3,
            scale: 1 + 0.1 * _level,
          ),
        ),
      ),
      Positioned(
        top: 12,
        left: 12,
        child: GlowIconButton(icon: Icons.agriculture_rounded, label: 'Back to the farm', onTap: _backToFarm),
      ),
      Positioned(
        top: 12,
        right: 12,
        child: GlowIconButton(icon: Icons.hearing_rounded, label: 'Hear Aria again', color: SP.amber, onTap: _model),
      ),
      Positioned(
        bottom: 16,
        right: 16,
        child: IgnorePointer(child: WakeRing(progress: _wake, size: 72)),
      ),
    ]);
  }
}

/// An animal picture that is asleep at [wake] 0 (grey, dim, tilted, snoring
/// Zs) and fully awake at 1. Drawn in code from the one awake picture.
class SleepyAnimal extends StatelessWidget {
  const SleepyAnimal({super.key, required this.image, required this.size, required this.wake, this.calm = false, this.glow = false});

  final String image;
  final double size;
  final double wake;
  final bool calm;
  final bool glow;

  static List<double> _matrix(double t) {
    // Lerp from a soft dim grey to the identity.
    const grey = [
      0.22, 0.33, 0.11, 0, 0, //
      0.22, 0.33, 0.11, 0, 0,
      0.25, 0.37, 0.12, 0, 0,
      0, 0, 0, 1, 0,
    ];
    const id = [
      1.0, 0, 0, 0, 0, //
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ];
    return [for (var i = 0; i < 20; i++) grey[i] + (id[i] - grey[i]) * t];
  }

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeIn.transform(wake.clamp(0.0, 1.0));
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        if (glow)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                BoxShadow(color: SP.teal.withValues(alpha: 0.45), blurRadius: size * 0.2, spreadRadius: -size * 0.1),
              ]),
            ),
          ),
        Positioned.fill(
          child: Transform.rotate(
            angle: -0.14 * (1 - t),
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(_matrix(t)),
              child: Image.asset(image, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
        ),
        if (t < 1) Positioned(right: size * 0.02, top: 0, child: _Snore(size: size * 0.16, opacity: 1 - t, calm: calm)),
      ]),
    );
  }
}

/// Three Zs drifting up from a sleeping animal.
class _Snore extends StatefulWidget {
  const _Snore({required this.size, required this.opacity, required this.calm});

  final double size;
  final double opacity;
  final bool calm;

  @override
  State<_Snore> createState() => _SnoreState();
}

class _SnoreState extends State<_Snore> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => SizedBox(
            width: widget.size * 1.6,
            height: widget.size * 2.2,
            child: Stack(children: [
              for (var i = 0; i < 3; i++)
                () {
                  final p = widget.calm ? i / 3 : (_c.value + i / 3) % 1;
                  return Positioned(
                    left: widget.size * (0.1 + 0.5 * p),
                    bottom: widget.size * 1.5 * p,
                    child: Opacity(
                      opacity: widget.opacity * math.sin(p * math.pi),
                      child: Text('z',
                          style: TextStyle(
                            fontFamily: SP.font,
                            fontWeight: FontWeight.w700,
                            fontSize: widget.size * (0.55 + 0.45 * p),
                            color: SP.cream,
                            height: 1,
                            shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                          )),
                    ),
                  );
                }(),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Progress ring with a sun that rises as the animal wakes.
class WakeRing extends StatelessWidget {
  const WakeRing({super.key, required this.progress, required this.size});

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
            color: SP.amber,
            backgroundColor: SP.night.withValues(alpha: 0.6),
            strokeCap: StrokeCap.round,
          ),
        ),
        Icon(progress >= 1 ? Icons.wb_sunny_rounded : Icons.bedtime_rounded,
            color: progress >= 1 ? SP.amber : SP.lilac, size: size * 0.45),
      ]),
    );
  }
}

/// The farm: evening sky, a low sun and rolling green hills. Drawn in code.
class FarmPainter extends CustomPainter {
  const FarmPainter({this.dim = 0});

  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6D8FE0), Color(0xFFB9C9F2), Color(0xFFFBD9B0)],
        ).createShader(r),
    );
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.3), size.height * 0.1, Paint()..color = const Color(0xFFFFE08A));
    void hill(double baseY, double amp, double phase, Color c) {
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += size.width / 40) {
        path.lineTo(x, size.height * baseY + math.sin(x / size.width * math.pi * 2 + phase) * size.height * amp);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = c);
    }

    hill(0.55, 0.05, 0.5, const Color(0xFF8CCB7A));
    hill(0.68, 0.04, 2.2, const Color(0xFF6DB65E));
    hill(0.82, 0.03, 4.0, const Color(0xFF55A04A));
    if (dim > 0) canvas.drawRect(r, Paint()..color = SP.night.withValues(alpha: dim));
  }

  @override
  bool shouldRepaint(covariant FarmPainter old) => old.dim != dim;
}
