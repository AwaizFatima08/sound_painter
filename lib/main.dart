import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/audio/audio_input.dart';
import 'core/audio/sound_player.dart';
import 'core/audio/voice_engine.dart';
import 'core/theme.dart';
import 'services/services.dart';
import 'services/session.dart';
import 'services/store.dart';
import 'views/home/home_view.dart';
import 'views/home/profile_picker_view.dart';
import 'views/onboarding/parent_setup_view.dart';
import 'views/onboarding/warmup_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final store = await Store.open();
  final sound = SoundPlayer();
  final st = store.settings;
  sound.applySettings(voice: st.voiceVolume, music: st.musicVolume, musicEnabled: st.musicOn);
  final micGranted = VoiceEngine.synthVoice || await MicInput.granted();

  runApp(SoundPainterApp(
    store: store,
    sound: sound,
    voice: VoiceEngine(sound: sound),
    session: SessionTracker(store),
    micGranted: micGranted,
  ));
}

class SoundPainterApp extends StatelessWidget {
  const SoundPainterApp({
    super.key,
    required this.store,
    required this.sound,
    required this.voice,
    required this.session,
    this.micGranted = false,
  });

  final Store store;
  final SoundPlayer sound;
  final VoiceEngine voice;
  final SessionTracker session;
  final bool micGranted;

  Widget _first() {
    if (!store.isSetUp) return const ParentSetupView();
    if (store.profiles.length > 1) return const ProfilePickerView();
    if (!store.active!.warmedUp && micGranted) return const WarmupView(next: HomeView());
    return const HomeView();
  }

  @override
  Widget build(BuildContext context) {
    return Services(
      store: store,
      sound: sound,
      voice: voice,
      session: session,
      child: MaterialApp(
        title: 'Sound Painter',
        debugShowCheckedModeBanner: false,
        theme: SP.theme(),
        home: _first(),
      ),
    );
  }
}
