// End-to-end run on a real device or emulator, driven by a synthetic child
// voice (no microphone needed):
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_flow_test.dart
//
// Screenshots land in build/screenshots/.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sound_painter/core/audio/audio_input.dart';
import 'package:sound_painter/core/audio/dsp.dart';
import 'package:sound_painter/core/audio/sound_player.dart';
import 'package:sound_painter/core/audio/voice_engine.dart';
import 'package:sound_painter/main.dart';
import 'package:sound_painter/models/profile.dart';
import 'package:sound_painter/services/session.dart';
import 'package:sound_painter/services/store.dart';
import 'package:sound_painter/widgets/kid_widgets.dart';

/// What the synthetic child "says" next; tests swap it per screen.
List<Float32List> script = SynthInput.demoScript();

Future<void> wait(WidgetTester t, double seconds) async {
  final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Finder button(String label) =>
    find.byWidgetPredicate((w) => w is BouncyButton && w.label == label, description: 'button "$label"');

Future<void> tapWhenReady(WidgetTester t, Finder f, {double timeout = 60}) async {
  final end = DateTime.now().add(Duration(seconds: timeout.round()));
  while (f.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for $f');
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.tap(f.first, warnIfMissed: false);
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var converted = false;

  // Screenshots are opt-in (--dart-define=SP_SHOTS=true): converting the
  // Flutter surface crashes the Android emulator's GPU emulation.
  const shots = bool.fromEnvironment('SP_SHOTS');

  Future<void> shot(WidgetTester t, String name) async {
    if (!shots) return;
    if (Platform.isAndroid && !converted) {
      await binding.convertFlutterSurfaceToImage();
      converted = true;
    }
    await t.pump();
    await binding.takeScreenshot(name);
  }

  testWidgets('a child warms up, paints, colours a picture, and a parent sees progress', (t) async {
    final dir = await Directory.systemTemp.createTemp('sp_it');
    final store = await Store.open(dir);
    store.addProfile(avatar: Avatar.fox, nickname: 'Test');
    final sound = SoundPlayer();
    final voice = VoiceEngine(sound: sound, inputFactory: () => SynthInput(script: script));

    await t.pumpWidget(SoundPainterApp(
      store: store,
      sound: sound,
      voice: voice,
      session: SessionTracker(store),
      micGranted: true,
    ));

    // 1. Pip's warm-up runs to the end with the synthetic voice.
    debugPrint('STEP 1');
    script = [
      SynthInput.demoScript()[1], // glide, already singing as the warm-up starts
      SynthInput.demoScript()[0], // a breath
      SynthInput.demoScript()[3], // loud aaa
    ];
    await wait(t, 12);
    await shot(t, '01_warmup');
    final home = button('Free Canvas: paint with your voice');
    final warmEnd = DateTime.now().add(const Duration(seconds: 150));
    while (home.evaluate().isEmpty && DateTime.now().isBefore(warmEnd)) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(home, findsOneWidget, reason: 'warm-up should finish on its own');
    expect(store.active!.warmedUp, isTrue);
    debugPrint('calibration: ${store.active!.calibration.toJson()}');
    await wait(t, 3);
    await shot(t, '02_home');

    // 2. Free Canvas: sing for a while, then go home (auto-saves).
    debugPrint('STEP 2');
    script = SynthInput.demoScript();
    await tapWhenReady(t, home);
    await wait(t, 16);
    await shot(t, '03_free_canvas');
    await tapWhenReady(t, button('Home'));
    await wait(t, 3);
    expect(await store.paintings(store.active!), isNotEmpty, reason: 'painting auto-saved');

    // 3. Phonics Safari: hold "aaa" for the apple until it's coloured in.
    debugPrint('STEP 3');
    await tapWhenReady(t, button('Phonics Safari: colour pictures with sounds'));
    await wait(t, 4);
    await shot(t, '04_safari_map');
    script = SynthInput.vowelScript(Vowel.a);
    await tapWhenReady(t, button('apple, the a sound'));
    await wait(t, 14);
    await shot(t, '05_safari_colouring');
    debugPrint('safari: speaking=${sound.speaking.value} voice=${store.active!.vowels[Vowel.a]!.practiceSeconds.toStringAsFixed(1)}s');
    final again = button('Colour it again');
    final safariEnd = DateTime.now().add(const Duration(seconds: 60));
    while (again.evaluate().isEmpty && DateTime.now().isBefore(safariEnd)) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(again, findsOneWidget, reason: 'picture should complete');
    expect(store.active!.vowels[Vowel.a]!.pictures, 1);
    expect(store.active!.vowels[Vowel.a]!.matchSeconds, greaterThan(0), reason: 'vowel /a/ recognised');
    await shot(t, '06_safari_done');
    await tapWhenReady(t, button('Back to the map'));
    await wait(t, 2);
    await tapWhenReady(t, button('Home'));
    await wait(t, 2);

    // 4. Gallery shows the saved painting.
    debugPrint('STEP 4');
    await tapWhenReady(t, button('My paintings'));
    await wait(t, 3);
    expect(button('Painting 1'), findsOneWidget);
    await shot(t, '07_gallery');
    await tapWhenReady(t, button('Home'));
    await wait(t, 2);

    // 5. Parent gate + Parent Zone.
    debugPrint('STEP 5');
    await tapWhenReady(t, button('Grown-ups'));
    await wait(t, 1);
    final q = find.textContaining('What is ');
    expect(q, findsOneWidget);
    final m = RegExp(r'What is (\d+) × (\d+)\?').firstMatch((q.evaluate().first.widget as Text).data!)!;
    final answer = int.parse(m[1]!) * int.parse(m[2]!);
    await t.tap(find.text('$answer'));
    await wait(t, 2);
    expect(find.text('Grown-ups'), findsOneWidget);
    expect(find.text('Test: progress'), findsOneWidget);
    await shot(t, '08_parent_zone');

    await t.fling(find.byType(CustomScrollView), const Offset(0, -2500), 3000);
    await wait(t, 2);
    await shot(t, '09_parent_settings');
  });
}
