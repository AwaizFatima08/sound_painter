import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/audio/audio_input.dart';
import '../../core/audio/dsp.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../services/services.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/parent_widgets.dart';
import '../onboarding/parent_setup_view.dart';
import '../onboarding/warmup_view.dart';
import 'sound_check_view.dart';

const appVersion = '1.0.0';

/// Grown-ups only (behind the parent gate): progress, per-child settings,
/// device settings and privacy information.
class ParentZoneView extends StatefulWidget {
  const ParentZoneView({super.key});

  @override
  State<ParentZoneView> createState() => _ParentZoneViewState();
}

class _ParentZoneViewState extends State<ParentZoneView> with WidgetsBindingObserver {
  late final Services s = Services.of(context);
  late Profile _p = s.store.active!;
  PermissionStatus? _mic;
  bool _confirmDelete = false;
  late final _name = TextEditingController(text: _p.nickname);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkMic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    s.store.save();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkMic();
  }

  Future<void> _checkMic() async {
    final st = await Permission.microphone.status;
    if (mounted) setState(() => _mic = st);
  }

  void _select(Profile p) => setState(() {
        _p = p;
        s.store.active = p;
        _name.text = p.nickname;
        _confirmDelete = false;
      });

  void _changed() {
    s.store.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ParentPage(
      title: 'Grown-ups',
      onClose: () => Navigator.pop(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _children(),
        _progress(),
        _childSettings(),
        _device(),
        _about(),
      ]),
    );
  }

  Widget _children() {
    return SectionCard(
      title: 'Children',
      icon: Icons.groups_rounded,
      child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (final p in s.store.profiles)
          ChoiceChip(
            selected: p.id == _p.id,
            onSelected: (_) => _select(p),
            avatar: ClipOval(child: Image.asset('assets/images/avatar_${p.avatar.name}.webp')),
            label: Text(p.displayName, style: const TextStyle(fontSize: 16)),
          ),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParentSetupView(addingChild: true)));
            if (mounted) _select(s.store.active!);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add a child'),
        ),
      ]),
    );
  }

  Widget _progress() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final week = _p.sessions.where((x) => x.start.isAfter(weekAgo)).toList();
    final minutes = week.fold<double>(0, (a, x) => a + x.seconds) / 60;
    final voiceMin = week.fold<double>(0, (a, x) => a + x.voiceSeconds) / 60;
    final days = week.map((x) => DateUtils.dateOnly(x.start)).toSet().length;
    final pictures = _p.vowels.values.fold<int>(0, (a, v) => a + v.pictures);
    final ranged = _p.sessions.where((x) => x.highHz > 0).toList();
    final recent = _p.sessions.reversed.take(7).toList();

    return SectionCard(
      title: '${_p.displayName}: progress',
      icon: Icons.insights_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          _Stat(label: 'Minutes this week', value: minutes.toStringAsFixed(0)),
          _Stat(label: 'Days played this week', value: '$days'),
          _Stat(label: 'Minutes of voice this week', value: voiceMin.toStringAsFixed(1)),
          _Stat(label: 'Pictures coloured', value: '$pictures'),
          _Stat(label: 'Paintings made', value: '${_p.paintings}'),
        ]),
        const SizedBox(height: 20),
        const Text('Vowel sounds practised', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Seconds of voice on each picture; the brighter part sounded like the target vowel. '
            'Matching is approximate: it is there to encourage, not to test.',
            style: TextStyle(color: SP.muted, fontSize: 14)),
        const SizedBox(height: 10),
        for (final v in Vowel.values) _VowelBar(vowel: v, stats: _p.vowels[v]!, maxSeconds: _maxVowelSeconds()),
        const SizedBox(height: 16),
        const Text('Voice range', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Warm-up range: ${_p.calibration.lowHz.round()}–${_p.calibration.highHz.round()} Hz'
          '${_p.warmedUp ? '' : ' (default; warm-up not done yet)'}',
          style: const TextStyle(fontSize: 15),
        ),
        if (ranged.isNotEmpty)
          Text(
            'Widest range in a session: ${ranged.map((x) => x.lowHz).reduce(math.min).round()}–'
            '${ranged.map((x) => x.highHz).reduce(math.max).round()} Hz',
            style: const TextStyle(fontSize: 15),
          ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Recent sessions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final r in recent)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${_date(r.start)}  ·  ${(r.seconds / 60).toStringAsFixed(1)} min  ·  '
                '${(r.voiceSeconds / 60).toStringAsFixed(1)} min of voice'
                '${r.highHz > 0 ? '  ·  ${r.lowHz.round()}–${r.highHz.round()} Hz' : ''}',
                style: const TextStyle(fontSize: 15, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('No sessions yet.', style: TextStyle(color: SP.muted)),
          ),
      ]),
    );
  }

  double _maxVowelSeconds() =>
      math.max(30, _p.vowels.values.map((v) => v.practiceSeconds).fold<double>(0, math.max));

  static String _date(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hh = d.hour.toString().padLeft(2, '0'), mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${m[d.month - 1]}, $hh:$mm';
  }

  Widget _childSettings() {
    final sens = _p.calibration.sensitivity;
    return SectionCard(
      title: '${_p.displayName}: settings',
      icon: Icons.tune_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _name,
          maxLength: 20,
          decoration: const InputDecoration(labelText: 'Nickname (optional)', border: OutlineInputBorder()),
          onChanged: (t) {
            _p.nickname = t;
            _changed();
          },
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final a in Avatar.values)
            GestureDetector(
              onTap: () {
                _p.avatar = a;
                _changed();
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: a == _p.avatar ? SP.teal : Colors.transparent, width: 3),
                ),
                child: ClipOval(child: Image.asset('assets/images/avatar_${a.name}.webp', semanticLabel: a.name)),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        LevelPicker(value: _p.level, onChanged: (l) {
          _p.level = l;
          _changed();
        }),
        const Divider(height: 28),
        Text('Microphone sensitivity: ${sens < 0.85 ? 'lower' : sens > 1.2 ? 'higher' : 'normal'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const Text('Raise it if soft voices don\'t paint; lower it in a noisy room.', style: TextStyle(color: SP.muted)),
        Slider(
          value: sens,
          min: 0.5,
          max: 2,
          divisions: 6,
          label: '${(sens * 100).round()}%',
          onChanged: (v) {
            _p.calibration = _p.calibration.copyWith(sensitivity: v);
            _changed();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _p.calmMode,
          onChanged: (v) {
            _p.calmMode = v;
            _changed();
          },
          title: const Text('Calm mode', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Fewer sparkles, softer colours and slower motion, for children who are easily overwhelmed.'),
        ),
        const SizedBox(height: 8),
        const Text('Session length', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const Text('After this time, Pip says goodbye and the microphone turns off. You can unlock more time.',
            style: TextStyle(color: SP.muted)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final m in const [0, 5, 10, 15, 20])
            ChoiceChip(
              selected: _p.sessionMinutes == m,
              label: Text(m == 0 ? 'No limit' : '$m min'),
              onSelected: (_) {
                _p.sessionMinutes = m;
                _changed();
              },
            ),
        ]),
        const Divider(height: 28),
        Wrap(spacing: 10, runSpacing: 10, children: [
          OutlinedButton.icon(
            onPressed: (_mic?.isGranted ?? false)
                ? () async {
                    await Navigator.of(context).push(fadeRoute(const WarmupView()));
                    if (mounted) setState(() {});
                  }
                : null,
            icon: const Icon(Icons.record_voice_over_rounded),
            label: const Text('Redo Pip\'s warm-up'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await s.store.resetProgress(_p);
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset progress'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await s.store.clearGallery(_p);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paintings deleted')));
            },
            icon: const Icon(Icons.hide_image_rounded),
            label: const Text('Delete paintings'),
          ),
        ]),
        const SizedBox(height: 14),
        if (!_confirmDelete)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: SP.pink),
            onPressed: () => setState(() => _confirmDelete = true),
            icon: const Icon(Icons.person_remove_rounded),
            label: Text('Remove ${_p.displayName} from this device'),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border.all(color: SP.pink), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Remove ${_p.displayName}? Their progress and paintings will be deleted. This can\'t be undone.'),
              const SizedBox(height: 10),
              Row(children: [
                OutlinedButton(onPressed: () => setState(() => _confirmDelete = false), child: const Text('Keep')),
                const SizedBox(width: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: SP.pink),
                  onPressed: _remove,
                  child: const Text('Remove'),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }

  Future<void> _remove() async {
    s.session.end();
    await s.store.deleteProfile(_p);
    if (!mounted) return;
    if (s.store.profiles.isEmpty) {
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(const ParentSetupView()), (_) => false);
      return;
    }
    _select(s.store.active!);
  }

  Widget _device() {
    final st = s.store.settings;
    final granted = _mic?.isGranted ?? false;
    void apply() {
      s.sound.applySettings(voice: st.voiceVolume, music: st.musicVolume, musicEnabled: st.musicOn);
      _changed();
    }

    return SectionCard(
      title: 'This device',
      icon: Icons.phone_android_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(granted ? Icons.mic_rounded : Icons.mic_off_rounded, color: granted ? SP.teal : SP.amber),
          const SizedBox(width: 10),
          Expanded(child: Text(granted ? 'Microphone allowed' : 'Microphone not allowed: finger painting only')),
          if (!granted)
            TextButton(
              onPressed: () async {
                final r = await MicInput.request();
                if (r.isPermanentlyDenied) await openAppSettings();
                _checkMic();
              },
              child: const Text('Allow'),
            ),
        ]),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: granted ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SoundCheckView())) : null,
          icon: const Icon(Icons.graphic_eq_rounded),
          label: const Text('Sound check'),
        ),
        const SizedBox(height: 16),
        const Text('Voice and sound effects volume', style: TextStyle(fontWeight: FontWeight.w700)),
        Slider(value: st.voiceVolume, onChanged: (v) {
          st.voiceVolume = v;
          apply();
        }),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: st.musicOn,
          onChanged: (v) {
            st.musicOn = v;
            apply();
          },
          title: const Text('Background music', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Plays on the menus only, never while the microphone is listening.'),
        ),
        if (st.musicOn)
          Slider(value: st.musicVolume, max: 0.8, onChanged: (v) {
            st.musicVolume = v;
            apply();
          }),
      ]),
    );
  }

  Widget _about() {
    return SectionCard(
      title: 'Privacy and about',
      icon: Icons.verified_user_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Bullet(icon: Icons.mic_rounded, text: 'Microphone sound is analysed on this device in real time to make '
            'colours and shapes. It is never recorded, stored or sent anywhere.'),
        const Bullet(icon: Icons.wifi_off_rounded, text: 'The app has no internet access, no ads, no analytics and no accounts.'),
        const Bullet(icon: Icons.save_rounded, text: 'Progress and paintings are kept only on this device. Removing a '
            'child or uninstalling the app deletes them.'),
        const Bullet(icon: Icons.volunteer_activism_rounded, text: 'Sound Painter is a free community-welfare project. '
            'It is an educational game, not a therapy or medical tool.'),
        const Bullet(icon: Icons.mail_rounded, text: 'Questions or feedback: homilabs.smc@gmail.com\n'
            'Privacy policy: soundpainter.homilabs.org/privacy-policy.html'),
        const SizedBox(height: 10),
        Row(children: [
          const Text('Version $appVersion', style: TextStyle(color: SP.muted)),
          const Spacer(),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Sound Painter',
              applicationVersion: appVersion,
              applicationLegalese: 'Art and voices made with Google Gemini. Andika font © SIL International (OFL).',
            ),
            child: const Text('Licences'),
          ),
        ]),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: SP.dusk, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: SP.teal)),
        Text(label, style: const TextStyle(fontSize: 13, color: SP.muted)),
      ]),
    );
  }
}

class _VowelBar extends StatelessWidget {
  const _VowelBar({required this.vowel, required this.stats, required this.maxSeconds});
  final Vowel vowel;
  final VowelStats stats;
  final double maxSeconds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 120,
          child: Text('${vowel.letter}  ${vowel.word}', style: const TextStyle(fontSize: 15)),
        ),
        Expanded(
          child: LayoutBuilder(builder: (_, c) {
            final w = c.maxWidth;
            final total = (stats.practiceSeconds / maxSeconds).clamp(0.0, 1.0) * w;
            final match = (stats.matchSeconds / maxSeconds).clamp(0.0, 1.0) * w;
            return Stack(children: [
              Container(height: 16, width: w, decoration: BoxDecoration(color: SP.dusk, borderRadius: BorderRadius.circular(8))),
              Container(height: 16, width: total, decoration: BoxDecoration(color: SP.lilac.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(8))),
              Container(height: 16, width: match, decoration: BoxDecoration(color: SP.teal, borderRadius: BorderRadius.circular(8))),
            ]);
          }),
        ),
        SizedBox(
          width: 110,
          child: Text(
            '  ${stats.practiceSeconds.round()} s · ${stats.pictures}★',
            style: const TextStyle(fontSize: 14, color: SP.muted, fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ),
      ]),
    );
  }
}
