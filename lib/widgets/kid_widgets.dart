import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/audio/sound_player.dart';
import '../core/audio/voice_engine.dart';
import '../core/theme.dart';
import '../services/services.dart';

/// Full-bleed background picture with content kept inside the safe area.
class Scene extends StatelessWidget {
  const Scene({super.key, required this.background, required this.child, this.dim = 0});

  final String background;
  final Widget child;

  /// 0..1 darkening over the picture, to make foreground art stand out.
  final double dim;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SP.night,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/$background.webp', fit: BoxFit.cover, gaplessPlayback: true),
        if (dim > 0) ColoredBox(color: SP.night.withValues(alpha: dim)),
        SafeArea(child: child),
      ]),
    );
  }
}

/// Squishy tap target for children: shrinks while pressed, springs back,
/// plays a soft pop. No double-tap or long-press required.
class BouncyButton extends StatefulWidget {
  const BouncyButton({super.key, required this.child, required this.onTap, required this.label, this.sound = true});

  final Widget child;
  final VoidCallback? onTap;

  /// Spoken by TalkBack; children never see it.
  final String label;
  final bool sound;

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.sound) Services.of(context).sound.sfx(Sfx.pop, volume: 0.5);
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down ? 0.9 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Round glowing icon button (home, trash, replay...).
class GlowIconButton extends StatelessWidget {
  const GlowIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.size = SP.kidTarget,
    this.color = SP.teal,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String label;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      label: label,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SP.dusk.withValues(alpha: 0.85),
          border: Border.all(color: color.withValues(alpha: 0.9), width: 3),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 1)],
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}

/// Clearing the canvas needs a one-second press so a stray tap never wipes a
/// child's work. A ring fills while held.
class HoldButton extends StatefulWidget {
  const HoldButton({super.key, required this.icon, required this.onHeld, required this.label, this.color = SP.pink});

  final IconData icon;
  final VoidCallback onHeld;
  final String label;
  final Color color;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        widget.onHeld();
        _c.reset();
      }
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = SP.kidTarget;
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onHeld,
      child: GestureDetector(
        onTapDown: (_) => _c.forward(),
        onTapUp: (_) => _c.reverse(),
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: size + 10,
              height: size + 10,
              child: CircularProgressIndicator(
                value: _c.value,
                strokeWidth: 6,
                color: widget.color,
                backgroundColor: Colors.transparent,
              ),
            ),
            Transform.scale(
              scale: 1 - 0.1 * _c.value,
              child: GlowIconButton(icon: widget.icon, onTap: null, label: widget.label, color: widget.color),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Gentle floating up-and-down motion.
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child, this.amount = 8, this.period = 2.6, this.phase = 0});

  final Widget child;
  final double amount;
  final double period;
  final double phase;

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => setState(() => _t = e.inMicroseconds / 1e6))..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final dy = reduce ? 0.0 : math.sin((_t / widget.period + widget.phase) * 2 * math.pi) * widget.amount;
    return Transform.translate(offset: Offset(0, dy), child: widget.child);
  }
}

enum Character { pip, ollie, aria }

/// A guide character that cross-fades between pose images and can pulse
/// with the child's voice.
class CharacterView extends StatelessWidget {
  const CharacterView({
    super.key,
    required this.character,
    required this.pose,
    required this.height,
    this.scale = 1,
    this.aura,
    this.flip = false,
  });

  final Character character;

  /// Pose image suffix: pip idle/low/high/wave, ollie idle/quiet/loud,
  /// aria idle/happy.
  final String pose;
  final double height;
  final double scale;

  /// Optional coloured glow behind the character (Pip's pitch aura).
  final Color? aura;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      'assets/images/${character.name}_$pose.webp',
      key: ValueKey(pose),
      height: height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
    return Semantics(
      image: true,
      label: const {Character.pip: 'Pip the penguin', Character.ollie: 'Ollie the owl', Character.aria: 'Aria the turtle'}[character],
      child: SizedBox(
        height: height * 1.12,
        child: Stack(alignment: Alignment.bottomCenter, clipBehavior: Clip.none, children: [
          if (aura != null)
            Positioned(
              bottom: height * 0.12,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: height * 0.8 * scale,
                height: height * 0.8 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: aura!.withValues(alpha: 0.55), blurRadius: height * 0.35, spreadRadius: height * 0.04)],
                ),
              ),
            ),
          AnimatedScale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            duration: const Duration(milliseconds: 120),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: flip ? Transform.flip(flipX: true, key: ValueKey('f$pose'), child: img) : img,
            ),
          ),
        ]),
      ),
    );
  }
}

/// Live sound meter: a row of bars showing the last second of voice, each
/// coloured by its pitch. Shows a hand when there is no microphone.
class AudioHud extends StatefulWidget {
  const AudioHud({super.key, required this.engine, required this.micOn});

  final VoiceEngine engine;
  final bool micOn;

  @override
  State<AudioHud> createState() => _AudioHudState();
}

class _AudioHudState extends State<AudioHud> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => setState(() {}))..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.micOn ? 'Sound meter' : 'Finger painting',
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: SP.night.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: SP.cardLine, width: 1.5),
        ),
        child: widget.micOn
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.mic_rounded, color: SP.teal, size: 28),
                const SizedBox(width: 10),
                for (var i = 0; i < VoiceEngine.historyLength; i++) _bar(i),
              ])
            : const Icon(Icons.pan_tool_alt_rounded, color: SP.amber, size: 36),
      ),
    );
  }

  Widget _bar(int i) {
    final h = widget.engine.history;
    final idx = h.length - VoiceEngine.historyLength + i;
    final (level, hue) = idx >= 0 ? h[idx] : (0.0, 200.0);
    return Container(
      width: 6,
      height: 6 + 34 * level,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: level > 0 ? HSVColor.fromAHSV(1, hue, 0.7, 1).toColor() : SP.cardLine,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// Fades one screen into the next; children lose track with sliding pages.
Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    );
