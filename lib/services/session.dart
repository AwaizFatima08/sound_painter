import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/audio/voice_analyzer.dart';
import '../models/profile.dart';
import 'store.dart';

/// Tracks one child's play session: time, voice time and pitch range for the
/// parent dashboard, and the parent's optional time limit.
class SessionTracker {
  SessionTracker(this._store);

  final Store _store;
  Profile? _profile;
  SessionRecord? _record;
  DateTime? _limitStart;
  Timer? _timer;
  final _pitches = <double>[];

  /// Becomes true when the parent's session length is reached.
  final timeUp = ValueNotifier<bool>(false);

  Profile? get profile => _profile;

  void begin(Profile p) {
    if (_profile?.id == p.id && _record != null) return;
    end();
    _profile = p;
    _record = SessionRecord(start: DateTime.now());
    p.sessions.add(_record!);
    if (p.sessions.length > Profile.maxSessions) p.sessions.removeAt(0);
    _limitStart = DateTime.now();
    timeUp.value = false;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
    _store.save();
  }

  /// A parent chose "keep playing": restart the limit window.
  void extend() {
    _limitStart = DateTime.now();
    timeUp.value = false;
  }

  void _tick() {
    final r = _record, p = _profile;
    if (r == null || p == null) return;
    r.seconds = DateTime.now().difference(r.start).inMilliseconds / 1000;
    if (p.sessionMinutes > 0 &&
        DateTime.now().difference(_limitStart!).inSeconds >= p.sessionMinutes * 60) {
      timeUp.value = true;
    }
    _finishPitch();
    _store.save();
  }

  /// Called by listening screens for every voice frame.
  void onVoice(VoiceFrame f, double dt) {
    final r = _record;
    if (r == null || !f.voiced) return;
    r.voiceSeconds += dt;
    if (f.pitchHz > 0 && _pitches.length < 20000) _pitches.add(f.pitchHz);
  }

  void _finishPitch() {
    final r = _record;
    if (r == null || _pitches.length < 10) return;
    final s = [..._pitches]..sort();
    r.lowHz = s[(s.length * 0.1).floor()];
    r.highHz = s[(s.length * 0.9).floor().clamp(0, s.length - 1)];
  }

  void end() {
    _timer?.cancel();
    _timer = null;
    final r = _record;
    if (r != null) {
      r.seconds = DateTime.now().difference(r.start).inMilliseconds / 1000;
      _finishPitch();
      // Drop accidental sub-10-second sessions so the dashboard stays honest.
      if (r.seconds < 10) _profile?.sessions.remove(r);
      _store.save();
    }
    _record = null;
    _profile = null;
    _pitches.clear();
  }
}
