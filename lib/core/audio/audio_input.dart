import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'dsp.dart';
import 'synth_voice.dart';

/// Where voice samples come from: the real microphone, or a synthetic voice
/// for tests, the emulator and store screenshots.
abstract class AudioInput {
  /// Starts capture; emits mono float samples at [kSampleRate].
  Future<Stream<Float32List>> start();
  Future<void> stop();
}

class MicInput implements AudioInput {
  final _rec = AudioRecorder();

  static Future<bool> granted() async {
    try {
      return (await Permission.microphone.status).isGranted;
    } catch (_) {
      return false; // no platform (tests) or plugin unavailable
    }
  }

  /// Asks for the microphone. Returns the resulting status so the parent
  /// screen can offer "Open settings" when it's permanently denied.
  static Future<PermissionStatus> request() => Permission.microphone.request();

  @override
  Future<Stream<Float32List>> start() async {
    final bytes = await _rec.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: kSampleRate,
      numChannels: 1,
      // The app talks to the child through the speaker; cancel that echo so
      // Pip's own voice doesn't paint.
      echoCancel: true,
      autoGain: false,
      noiseSuppress: false,
      androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceRecognition),
    ));
    return bytes.map(pcm16ToFloat);
  }

  @override
  Future<void> stop() async {
    if (await _rec.isRecording()) await _rec.stop();
  }
}

/// Plays a scripted synthetic voice in real time: glides, hums and vowels,
/// with pauses. Drives the whole app on devices with no microphone input.
class SynthInput implements AudioInput {
  SynthInput({this.script});

  /// Pieces to loop through; defaults to a varied demo performance.
  final List<Float32List>? script;
  Timer? _timer;
  StreamController<Float32List>? _ctrl;

  static List<Float32List> demoScript() {
    final s = SynthVoice(seed: 3);
    return [
      s.silence(0.6),
      s.vowel(seconds: 2.2, f0: 220, f0End: 480, f1: 900, f2: 1300, amp: 0.25),
      s.silence(0.4),
      s.childVowel(Vowel.a, seconds: 1.8, f0: 330, amp: 0.4),
      s.silence(0.3),
      s.vowel(seconds: 2.0, f0: 460, f0End: 250, f1: 500, f2: 2600, amp: 0.12),
      s.silence(0.5),
      s.childVowel(Vowel.o, seconds: 1.6, f0: 270, amp: 0.3),
      s.childVowel(Vowel.i, seconds: 1.4, f0: 420, amp: 0.2),
      s.silence(0.7),
    ];
  }

  /// A child holding one vowel with short breaths, for Phonics Safari.
  static List<Float32List> vowelScript(Vowel v) {
    final s = SynthVoice(seed: 5);
    return [
      s.silence(0.5),
      s.childVowel(v, seconds: 2.5, f0: 300, amp: 0.3),
      s.silence(0.4),
      s.childVowel(v, seconds: 2.5, f0: 320, amp: 0.3),
    ];
  }

  @override
  Future<Stream<Float32List>> start() async {
    final pieces = script ?? demoScript();
    final all = SynthVoice.concat(pieces);
    var pos = 0;
    const chunk = 512;
    _ctrl = StreamController<Float32List>();
    _timer = Timer.periodic(const Duration(milliseconds: 32), (_) {
      final out = Float32List(chunk);
      for (var i = 0; i < chunk; i++) {
        out[i] = all[pos];
        pos = (pos + 1) % all.length;
      }
      _ctrl?.add(out);
    });
    return _ctrl!.stream;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _ctrl?.close();
    _ctrl = null;
  }
}

/// Math helper shared by visual code: hue for a 0..1 pitch position.
/// 260° (blue-violet, low voice) down to 0° (warm red, high voice), per GDD.
double hueForPitch(double norm) => (1 - norm.clamp(0.0, 1.0)) * 260.0;

double lerpD(double a, double b, double t) => a + (b - a) * t;

double smoothTo(double current, double target, double rate, double dt) =>
    target + (current - target) * math.exp(-rate * dt);
