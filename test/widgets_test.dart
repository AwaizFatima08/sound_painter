import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_painter/core/audio/audio_input.dart';
import 'package:sound_painter/core/audio/sound_player.dart';
import 'package:sound_painter/core/audio/voice_engine.dart';
import 'package:sound_painter/main.dart';
import 'package:sound_painter/services/session.dart';
import 'package:sound_painter/services/store.dart';
import 'package:sound_painter/widgets/parent_gate.dart';

Future<SoundPainterApp> app(Directory dir) async {
  final store = await Store.open(dir);
  final sound = SoundPlayer(enabled: false);
  return SoundPainterApp(
    store: store,
    sound: sound,
    voice: VoiceEngine(sound: sound, inputFactory: SynthInput.new),
    session: SessionTracker(store),
  );
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('sp_w'));

  testWidgets('first run shows the parent setup with the privacy promise', (t) async {
    await t.binding.setSurfaceSize(const Size(1280, 800));
    await t.pumpWidget(await t.runAsync(() => app(dir)) as Widget);
    await t.pump();
    expect(find.text('Welcome to Sound Painter'), findsOneWidget);
    expect(find.textContaining('never recorded, stored or sent anywhere'), findsOneWidget);
    await t.tap(find.text('Set up'));
    await t.pumpAndSettle();
    expect(find.textContaining('never ask for a real name'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Practise'), findsOneWidget);
  });

  testWidgets('parent gate: wrong answers ask again, the right one opens', (t) async {
    await t.binding.setSurfaceSize(const Size(1280, 800));
    bool? result;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(onPressed: () async => result = await showParentGate(c), child: const Text('open')),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    int answer() {
      final q = (find.textContaining('What is ').evaluate().single.widget as Text).data!;
      final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
      return int.parse(m[1]!) * int.parse(m[2]!);
    }

    final right = answer();
    final wrong = find.byType(OutlinedButton).evaluate().map((e) => ((e.widget as OutlinedButton).child as Text).data!)
        .map(int.parse)
        .firstWhere((v) => v != right);
    await t.tap(find.text('$wrong'));
    await t.pumpAndSettle();
    expect(find.text('Not quite. Here is another one.'), findsOneWidget);
    expect(result, isNull);

    await t.tap(find.text('${answer()}'));
    await t.pumpAndSettle();
    expect(result, isTrue);
  });
}
