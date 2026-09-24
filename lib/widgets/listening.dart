import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/audio/voice_analyzer.dart';
import '../models/profile.dart';
import '../services/services.dart';
import 'rest_overlay.dart';

/// Base for screens that listen to the child: warm-up, Free Canvas and a
/// Phonics Safari picture.
///
/// Turns the mic on when the screen opens and off when it closes or the app
/// goes to the background, keeps the screen awake (a singing child isn't
/// touching it), and calls [onVoice] every frame with the time step.
abstract class ListeningState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final Services services = Services.of(context);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// Whether the microphone is live. False means finger-only mode.
  bool micOn = false;
  bool _started = false;

  Profile get profile => services.store.active!;

  /// Called every animation frame with the latest voice analysis.
  void onVoice(VoiceFrame f, double dt);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
    Services.of(context).session.timeUp.addListener(_onTimeUp);
  }

  Future<void> _startListening() async {
    if (!mounted || _started) return;
    _started = true;
    services.sound.music(false);
    services.voice.calibration = profile.calibration;
    final ok = await services.voice.start();
    if (!mounted) return;
    setState(() => micOn = ok);
    unawaited(WakelockPlus.enable().catchError((_) {}));
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
    onStarted();
  }

  /// Hook for screens that greet the child once listening starts.
  void onStarted() {}

  Future<void> _stopListening() async {
    if (!_started) return;
    _started = false;
    if (_ticker.isActive) _ticker.stop();
    await services.voice.stop();
    unawaited(WakelockPlus.disable().catchError((_) {}));
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero ? 1 / 60 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final f = services.voice.frame.value;
    // Real elapsed time (capped only against long stalls), so a slow frame
    // rate on a budget device can't stretch the warm-up or prompt timers.
    final step = dt.clamp(0.0, 0.5);
    services.session.onVoice(f, step);
    onVoice(f, step);
  }

  void _onTimeUp() {
    if (!mounted || !services.session.timeUp.value) return;
    _stopListening();
    services.sound.hush();
    Navigator.of(context).push(restRoute(context)).then((_) {
      if (mounted) _startListening();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopListening();
      services.sound.hush();
    } else if (state == AppLifecycleState.resumed && ModalRoute.of(context)?.isCurrent == true) {
      _startListening();
    }
  }

  @override
  void dispose() {
    services.session.timeUp.removeListener(_onTimeUp);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _stopListening();
    services.sound.hush();
    super.dispose();
  }
}
