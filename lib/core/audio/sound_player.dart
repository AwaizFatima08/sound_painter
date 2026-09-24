import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Short sound effects bundled in assets/audio/sfx/.
enum Sfx { pop, chime, sparkle, whoosh, tada }

/// Plays Pip's, Ollie's and Aria's voice lines, sound effects and background
/// music. Voice lines are pre-generated (Gemini TTS) and bundled, so nothing
/// needs the network.
class SoundPlayer {
  SoundPlayer({this.enabled = true});

  /// False in widget tests, where no audio platform exists.
  final bool enabled;

  final _voice = AudioPlayer();
  final _sfx = [AudioPlayer(), AudioPlayer()];
  final _music = AudioPlayer();
  int _nextSfx = 0;

  /// True while a voice line is playing. The voice engine ignores the
  /// microphone meanwhile, so prompts never paint.
  final speaking = ValueNotifier<bool>(false);

  double voiceVolume = 1.0;
  double musicVolume = 0.35;
  bool musicOn = true;
  bool _musicWanted = false;
  int _token = 0;

  /// Speaks line [id] (a file in assets/audio/voice/). Completes when it
  /// finishes or is interrupted by another line.
  Future<void> say(String id) async {
    final token = ++_token;
    if (!enabled) return;
    speaking.value = true;
    _duck(true);
    try {
      await _voice.setAsset('assets/audio/voice/$id.wav');
      await _voice.setVolume(voiceVolume);
      await _voice.play();
      await _voice.processingStateStream.firstWhere((s) => s == ProcessingState.completed);
    } catch (e) {
      debugPrint('voice line $id failed: $e');
    } finally {
      if (token == _token) {
        // Short tail so the room echo has died away before we listen again.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (token == _token) {
          speaking.value = false;
          _duck(false);
        }
      }
    }
  }

  /// Stops any voice line now.
  Future<void> hush() async {
    _token++;
    if (enabled) await _voice.stop();
    speaking.value = false;
    _duck(false);
  }

  Future<void> sfx(Sfx s, {double volume = 0.7}) async {
    if (!enabled) return;
    final p = _sfx[_nextSfx];
    _nextSfx = (_nextSfx + 1) % _sfx.length;
    try {
      await p.setAsset('assets/audio/sfx/${s.name}.wav');
      await p.setVolume(volume * voiceVolume);
      await p.play();
    } catch (e) {
      debugPrint('sfx ${s.name} failed: $e');
    }
  }

  /// Gentle background music, only on screens where the mic is off.
  Future<void> music(bool on) async {
    _musicWanted = on;
    if (!enabled) return;
    try {
      if (on && musicOn && musicVolume > 0) {
        if (_music.audioSource == null) {
          await _music.setAsset('assets/audio/music/calm_loop.mp3');
          await _music.setLoopMode(LoopMode.one);
        }
        await _music.setVolume(speaking.value ? musicVolume * 0.3 : musicVolume);
        if (!_music.playing) unawaited(_music.play());
      } else if (_music.playing) {
        await _music.pause();
      }
    } catch (e) {
      debugPrint('music failed: $e');
    }
  }

  void applySettings({required double voice, required double music, required bool musicEnabled}) {
    voiceVolume = voice;
    musicVolume = music;
    musicOn = musicEnabled;
    this.music(_musicWanted);
  }

  void _duck(bool down) {
    if (!enabled || !_music.playing) return;
    _music.setVolume(down ? musicVolume * 0.3 : musicVolume);
  }

  Future<void> pauseAll() async {
    if (!enabled) return;
    await hush();
    await _music.pause();
  }

  Future<void> resume() => music(_musicWanted);
}
