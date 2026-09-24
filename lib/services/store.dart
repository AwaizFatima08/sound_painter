import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/profile.dart';

/// Everything the app remembers, stored only on this device: one JSON file
/// plus each child's paintings as PNGs. There is no server and no account.
class Store extends ChangeNotifier {
  Store._(this._dir);

  final Directory _dir;
  final List<Profile> profiles = [];
  AppSettings settings = AppSettings();
  String? _activeId;

  /// Paintings kept per child; the oldest is removed beyond this.
  static const maxPaintings = 60;

  static Future<Store> open([Directory? dir]) async {
    final d = dir ?? await getApplicationDocumentsDirectory();
    final s = Store._(d);
    await s._load();
    return s;
  }

  File get _file => File('${_dir.path}/sound_painter.json');

  Profile? get active {
    for (final p in profiles) {
      if (p.id == _activeId) return p;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  set active(Profile? p) {
    _activeId = p?.id;
    save();
  }

  bool get isSetUp => profiles.isNotEmpty;

  Future<void> _load() async {
    try {
      if (!await _file.exists()) return;
      final j = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      profiles
        ..clear()
        ..addAll([
          for (final p in (j['profiles'] as List?) ?? const []) Profile.fromJson((p as Map).cast<String, dynamic>()),
        ]);
      settings = AppSettings.fromJson((j['settings'] as Map?)?.cast<String, dynamic>());
      _activeId = j['active'] as String?;
    } catch (e) {
      // A corrupt file must never lock a child out of the app. Keep a copy
      // for debugging and start fresh.
      debugPrint('store load failed: $e');
      try {
        await _file.rename('${_file.path}.corrupt');
      } catch (_) {}
    }
  }

  Future<void>? _pending;
  bool _dirty = false;

  /// Saves soon; coalesces bursts of changes into one write. Writes never
  /// overlap: changes made during a write trigger one more write after it.
  Future<void> save() {
    notifyListeners();
    _dirty = true;
    return _pending ??= _writeLoop();
  }

  Future<void> _writeLoop() async {
    try {
      while (_dirty) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        _dirty = false;
        final j = {
          'version': 1,
          'profiles': [for (final p in profiles) p.toJson()],
          'settings': settings.toJson(),
          'active': _activeId,
        };
        final tmp = File('${_file.path}.tmp');
        await tmp.writeAsString(jsonEncode(j), flush: true);
        await tmp.rename(_file.path);
      }
    } catch (e) {
      debugPrint('store save failed: $e');
    } finally {
      _pending = null;
    }
  }

  Profile addProfile({required Avatar avatar, String nickname = '', PlayLevel level = PlayLevel.explore}) {
    final id = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(999)}';
    final p = Profile(id: id, avatar: avatar, nickname: nickname, level: level);
    profiles.add(p);
    _activeId = id;
    save();
    return p;
  }

  Future<void> deleteProfile(Profile p) async {
    profiles.remove(p);
    if (_activeId == p.id) _activeId = profiles.isEmpty ? null : profiles.first.id;
    final g = _galleryDir(p);
    if (await g.exists()) await g.delete(recursive: true);
    await save();
  }

  /// Clears a child's practice history but keeps their profile and warm-up.
  Future<void> resetProgress(Profile p) async {
    for (final v in p.vowels.values) {
      v
        ..practiceSeconds = 0
        ..matchSeconds = 0
        ..pictures = 0;
    }
    p.sessions.clear();
    await save();
  }

  // ---- gallery ----

  Directory _galleryDir(Profile p) => Directory('${_dir.path}/gallery/${p.id}');

  Future<File> addPainting(Profile p, Uint8List png) async {
    final d = _galleryDir(p);
    await d.create(recursive: true);
    final f = File('${d.path}/${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(png, flush: true);
    p.paintings++;
    final all = await paintings(p);
    for (final old in all.skip(maxPaintings)) {
      await old.delete();
    }
    await save();
    return f;
  }

  /// Newest first.
  Future<List<File>> paintings(Profile p) async {
    final d = _galleryDir(p);
    if (!await d.exists()) return [];
    final files = await d.list().where((e) => e is File && e.path.endsWith('.png')).cast<File>().toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> clearGallery(Profile p) async {
    final d = _galleryDir(p);
    if (await d.exists()) await d.delete(recursive: true);
    notifyListeners();
  }
}
