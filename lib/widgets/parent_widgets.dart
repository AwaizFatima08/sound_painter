import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/profile.dart';

/// Plain, readable layout for the grown-up screens (setup, Parent Zone).
class ParentPage extends StatelessWidget {
  const ParentPage({super.key, required this.title, required this.child, this.onClose, this.actions = const []});

  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SP.night,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: SP.cream)),
                    ),
                    ...actions,
                    if (onClose != null)
                      IconButton(tooltip: 'Close', onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 28)),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                sliver: SliverToBoxAdapter(child: child),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class Lead extends StatelessWidget {
  const Lead(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 19, height: 1.4, color: SP.cream));
}

class Bullet extends StatelessWidget {
  const Bullet({super.key, required this.icon, required this.text, this.color = SP.lilac});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16, height: 1.45, color: SP.cream))),
      ]),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.icon});
  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SP.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SP.cardLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icon != null) ...[Icon(icon, color: SP.teal), const SizedBox(width: 10)],
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class LevelPicker extends StatelessWidget {
  const LevelPicker({super.key, required this.value, required this.onChanged});
  final PlayLevel value;
  final ValueChanged<PlayLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<PlayLevel>(
      groupValue: value,
      onChanged: (v) => onChanged(v!),
      child: const Column(children: [
        RadioListTile<PlayLevel>(
          value: PlayLevel.explore,
          contentPadding: EdgeInsets.zero,
          title: Text('Explore', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Every sound counts the same. Best to start with, and for children who are still finding their voice.'),
        ),
        RadioListTile<PlayLevel>(
          value: PlayLevel.practise,
          contentPadding: EdgeInsets.zero,
          title: Text('Practise', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Pictures colour in faster when the matching vowel sound is heard, and the letter is shown.'),
        ),
      ]),
    );
  }
}
