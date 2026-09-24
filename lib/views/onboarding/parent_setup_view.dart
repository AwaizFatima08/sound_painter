import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/audio/audio_input.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../services/services.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/parent_widgets.dart';
import '../home/home_view.dart';
import 'warmup_view.dart';

/// First run, for the grown-up: what the app does, a child profile, and the
/// microphone. The child's part starts only after this.
class ParentSetupView extends StatefulWidget {
  const ParentSetupView({super.key, this.addingChild = false});

  /// True when opened from the Parent Zone to add another child.
  final bool addingChild;

  @override
  State<ParentSetupView> createState() => _ParentSetupViewState();
}

class _ParentSetupViewState extends State<ParentSetupView> {
  late int _step = widget.addingChild ? 1 : 0;
  Avatar _avatar = Avatar.fox;
  PlayLevel _level = PlayLevel.explore;
  final _name = TextEditingController();
  PermissionStatus? _mic;

  @override
  void initState() {
    super.initState();
    MicInput.granted().then((g) {
      if (mounted && g) setState(() => _mic = PermissionStatus.granted);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _askMic() async {
    final st = await MicInput.request();
    if (mounted) setState(() => _mic = st);
  }

  void _finish() {
    final s = Services.of(context);
    s.store.addProfile(avatar: _avatar, nickname: _name.text.trim(), level: _level);
    final micOk = _mic?.isGranted ?? false;
    if (widget.addingChild) {
      Navigator.pop(context);
      return;
    }
    Navigator.of(context).pushReplacement(fadeRoute(
      micOk ? const WarmupView(next: HomeView()) : const HomeView(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final steps = [_welcome(), _child(), _micStep(), _handOver()];
    return ParentPage(
      title: widget.addingChild ? 'Add a child' : 'Welcome to Sound Painter',
      onClose: widget.addingChild ? () => Navigator.pop(context) : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(key: ValueKey(_step), child: steps[_step]),
      ),
    );
  }

  Widget _nav({VoidCallback? onNext, String next = 'Continue', bool back = true}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(children: [
        if (back && _step > (widget.addingChild ? 1 : 0))
          OutlinedButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
        const Spacer(),
        FilledButton(onPressed: onNext, child: Text(next)),
      ]),
    );
  }

  Widget _welcome() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Lead('Children paint with their voice. Loudness sets the brush size, pitch sets the colour, '
          'and held vowel sounds colour in pictures.'),
      const SizedBox(height: 16),
      const Bullet(icon: Icons.favorite_rounded, text: 'Made for children aged 3–6 who learn at their own pace. '
          'There is no failing, no timer and no score: every sound makes art.'),
      const Bullet(icon: Icons.lock_rounded, text: 'The microphone is used only while your child plays. Sound is '
          'analysed on this device in real time and is never recorded, stored or sent anywhere.'),
      const Bullet(icon: Icons.wifi_off_rounded, text: 'No ads, no accounts, no tracking. The app does not use the internet.'),
      const Bullet(icon: Icons.child_care_rounded, text: 'Please stay nearby. Settings and progress are behind a '
          'grown-ups-only question.'),
      _nav(onNext: () => setState(() => _step = 1), next: 'Set up'),
    ]);
  }

  Widget _child() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Lead('Choose an animal friend for your child. It is their picture in the app; '
          'we never ask for a real name or photo.'),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final a in Avatar.values)
          Semantics(
            selected: a == _avatar,
            button: true,
            label: a.name,
            child: GestureDetector(
              onTap: () => setState(() => _avatar = a),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: a == _avatar ? SP.teal : Colors.transparent, width: 4),
                ),
                child: ClipOval(child: Image.asset('assets/images/avatar_${a.name}.webp', fit: BoxFit.cover)),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 16),
      TextField(
        controller: _name,
        maxLength: 20,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nickname (optional)',
          helperText: 'Only helps you tell children apart. Stays on this device.',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      LevelPicker(value: _level, onChanged: (l) => setState(() => _level = l)),
      _nav(onNext: () => setState(() => _step = widget.addingChild ? 3 : 2)),
    ]);
  }

  Widget _micStep() {
    final granted = _mic?.isGranted ?? false;
    final blocked = _mic?.isPermanentlyDenied ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Lead('Sound Painter needs the microphone to hear your child\'s voice.'),
      const SizedBox(height: 8),
      const Bullet(icon: Icons.graphic_eq_rounded, text: 'Listening happens only on the painting and picture screens, '
          'and stops when your child leaves them.'),
      const Bullet(icon: Icons.delete_forever_rounded, text: 'Nothing is recorded. Each moment of sound is turned into '
          'colour and then discarded.'),
      const SizedBox(height: 12),
      if (granted)
        const Bullet(icon: Icons.check_circle_rounded, text: 'Microphone allowed. Thank you!', color: SP.teal)
      else if (_mic != null)
        Bullet(
          icon: Icons.info_rounded,
          color: SP.amber,
          text: blocked
              ? 'The microphone is turned off for this app. You can still continue: your child can paint with a finger. '
                  'To allow it later, open the app settings.'
              : 'No problem. Your child can paint with a finger, and you can allow the microphone later from the '
                  'grown-ups area.',
        ),
      if (blocked)
        TextButton.icon(onPressed: openAppSettings, icon: const Icon(Icons.settings_rounded), label: const Text('Open app settings')),
      _nav(
        onNext: granted || _mic != null ? () => setState(() => _step = 3) : _askMic,
        next: granted || _mic != null ? 'Continue' : 'Allow microphone',
      ),
    ]);
  }

  Widget _handOver() {
    final micOk = _mic?.isGranted ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Lead(widget.addingChild
          ? 'All set. Your child can pick their animal on the start screen.'
          : 'All set! Please hand the device to your child.'),
      const SizedBox(height: 8),
      if (micOk && !widget.addingChild)
        const Bullet(icon: Icons.record_voice_over_rounded, text: 'First, Pip the penguin will play a one-minute warm-up: '
            'a loud sound, a quiet sound, a high sound and a low sound. It learns your child\'s own voice range, '
            'so colours spread across their voice. Any response is fine.'),
      const Bullet(icon: Icons.lock_rounded, text: 'To change settings or see progress, tap the small lock in the top corner.'),
      _nav(onNext: _finish, next: widget.addingChild ? 'Done' : 'Start'),
    ]);
  }
}
