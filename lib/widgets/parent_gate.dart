import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Grown-ups-only check before settings, the dashboard or anything that
/// leaves the child's world (Google Play Families policy).
///
/// A multiplication question with three large answers: easy for an adult,
/// out of reach for a pre-reader, and a wrong answer simply asks another
/// question (no lockout to frustrate a parent).
Future<bool> showParentGate(BuildContext context) async {
  final ok = await Navigator.of(context).push<bool>(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black54,
      pageBuilder: (_, _, _) => const _ParentGate(),
      transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
    ),
  );
  return ok ?? false;
}

class _ParentGate extends StatefulWidget {
  const _ParentGate();

  @override
  State<_ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends State<_ParentGate> {
  final _rand = math.Random();
  late int _a, _b;
  late List<int> _choices;
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    _a = 3 + _rand.nextInt(7);
    _b = 3 + _rand.nextInt(7);
    final answer = _a * _b;
    final set = <int>{answer};
    while (set.length < 3) {
      final d = (_rand.nextInt(4) + 1) * (_rand.nextBool() ? 1 : -1) * (_rand.nextBool() ? 1 : _a);
      if (answer + d > 0) set.add(answer + d);
    }
    _choices = set.toList()..shuffle(_rand);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
          decoration: BoxDecoration(
            color: SP.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: SP.cardLine, width: 1.5),
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.lock_rounded, color: SP.lilac),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('For grown-ups', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
              const SizedBox(height: 8),
              Text('What is $_a × $_b?', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                _wrong ? 'Not quite. Here is another one.' : 'Tap the right answer to continue.',
                style: TextStyle(color: _wrong ? SP.amber : SP.muted, fontSize: 15),
              ),
              const SizedBox(height: 20),
              Wrap(spacing: 14, runSpacing: 14, alignment: WrapAlignment.center, children: [
                for (final c in _choices)
                  SizedBox(
                    width: 104,
                    height: 72,
                    child: OutlinedButton(
                      onPressed: () {
                        if (c == _a * _b) {
                          Navigator.pop(context, true);
                        } else {
                          setState(() {
                            _wrong = true;
                            _next();
                          });
                        }
                      },
                      child: Text('$c', style: const TextStyle(fontSize: 26)),
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
