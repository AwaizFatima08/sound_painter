import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/services.dart';
import '../../widgets/kid_widgets.dart';
import '../canvas/free_canvas_view.dart';

/// "My Paintings": everything the child has painted, newest first. The
/// child can only look; deleting lives behind the parent gate.
class GalleryView extends StatefulWidget {
  const GalleryView({super.key});

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  List<File>? _files;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final s = Services.of(context);
    final files = await s.store.paintings(s.store.active!);
    if (!mounted) return;
    setState(() => _files = files);
    if (files.isNotEmpty) s.sound.say('gallery_intro');
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    final size = MediaQuery.sizeOf(context);
    return Scene(
      background: 'bg_home',
      dim: 0.4,
      child: Stack(children: [
        if (files != null && files.isEmpty)
          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CharacterView(character: Character.pip, pose: 'idle', height: size.height * 0.45),
              const SizedBox(width: 24),
              Bob(
                child: BouncyButton(
                  label: 'Paint something',
                  onTap: () => Navigator.of(context).pushReplacement(fadeRoute(const FreeCanvasView())),
                  child: Image.asset('assets/images/badge_canvas.webp', width: size.height * 0.4),
                ),
              ),
            ]),
          ),
        if (files != null && files.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(112, 16, 24, 16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                childAspectRatio: 16 / 10,
              ),
              itemCount: files.length,
              itemBuilder: (_, i) => BouncyButton(
                label: 'Painting ${i + 1}',
                onTap: () => Navigator.of(context).push(fadeRoute(_PaintingView(file: files[i]))),
                child: _Frame(child: Image.file(files[i], fit: BoxFit.cover, cacheWidth: 480)),
              ),
            ),
          ),
        Positioned(
          top: 12,
          left: 12,
          child: GlowIconButton(icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.pop(context)),
        ),
      ]),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SP.amber, width: 5),
        boxShadow: [BoxShadow(color: SP.amber.withValues(alpha: 0.35), blurRadius: 16)],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(13), child: child),
    );
  }
}

class _PaintingView extends StatelessWidget {
  const _PaintingView({required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    return Scene(
      background: 'bg_home',
      dim: 0.6,
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(112, 20, 112, 20),
          child: Center(child: _Frame(child: Image.file(file, fit: BoxFit.contain))),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: GlowIconButton(icon: Icons.arrow_back_rounded, label: 'Back', onTap: () => Navigator.pop(context)),
        ),
      ]),
    );
  }
}
