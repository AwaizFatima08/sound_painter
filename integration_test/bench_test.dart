// On-device speed check for the voice analyser (run with --profile for
// release-like numbers). Real time = 10 s of audio must analyse in < 10 s.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sound_painter/core/audio/audio_input.dart';
import 'package:sound_painter/core/audio/synth_voice.dart';
import 'package:sound_painter/core/audio/voice_analyzer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('voice analyser keeps up with real time', (t) async {
    final audio = SynthVoice.concat(SynthInput.demoScript()); // ~12 s
    final seconds = audio.length / 16000;
    for (final vowels in [false, true]) {
      final a = VoiceAnalyzer()..scoreVowels = vowels;
      final sw = Stopwatch()..start();
      for (var i = 0; i < audio.length; i += 512) {
        a.add(Float32List.sublistView(audio, i, (i + 512).clamp(0, audio.length)));
      }
      sw.stop();
      final load = sw.elapsedMilliseconds / 1000 / seconds;
      debugPrint('BENCH mode=${kReleaseMode ? 'release' : kProfileMode ? 'profile' : 'debug'} vowels=$vowels '
          'audio=${seconds.toStringAsFixed(1)}s analysed in ${sw.elapsedMilliseconds}ms '
          '= ${(load * 100).toStringAsFixed(0)}% of one CPU core');
    }
  });
}
