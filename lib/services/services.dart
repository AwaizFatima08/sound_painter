import 'package:flutter/widgets.dart';

import '../core/audio/sound_player.dart';
import '../core/audio/voice_engine.dart';
import 'session.dart';
import 'store.dart';

/// The app's long-lived services, available to every screen.
class Services extends InheritedWidget {
  const Services({
    super.key,
    required this.store,
    required this.sound,
    required this.voice,
    required this.session,
    required super.child,
  });

  final Store store;
  final SoundPlayer sound;
  final VoiceEngine voice;
  final SessionTracker session;

  static Services of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<Services>()!;

  @override
  bool updateShouldNotify(Services oldWidget) => false;
}
