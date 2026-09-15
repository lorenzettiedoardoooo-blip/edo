import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/workout.dart';
import '../services/platform_bridge.dart';

/// Every revision is captured before enqueueing. Writes are ordered and native
/// AtomicFile commits on a worker thread. Failed saves stay in memory for retry.
class WorkoutStore extends ChangeNotifier {
  final PlatformBridge platform;
  final Map<String, Workout> _workouts = {};
  final Map<String, String> _dirty = {};
  Future<void> _queue = Future<void>.value();
  int _pending = 0;
  bool _settingsDirty = false;
  String? saveError;
  AppSettings settings = AppSettings();
  WorkoutStore(this.platform);
  List<Workout> get workouts => _workouts.values.toList()
    ..sort((a, b) => b.modified.compareTo(a.modified));
  bool get saving => _pending > 0;
  bool get unsaved => _dirty.isNotEmpty || _settingsDirty;
  Future<void> load() async {
    final documents = await platform.readWorkouts();
    final loaded = <String, Workout>{};
    for (final json in documents) {
      final w = Workout.decode(json); loaded[w.id] = w;
    }
    final json = await platform.readSettings();
    final nextSettings = json == null ? AppSettings() : AppSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
    _workouts.clear(); _workouts.addAll(loaded); settings = nextSettings;
    notifyListeners();
  }
  Future<void> _enqueue(Future<void> Function() action) {
    _pending++; notifyListeners();
    final operation = _queue.then((_) => action());
    _queue = operation.then<void>((_) {
      if (!unsaved) saveError = null;
    }, onError: (Object e, StackTrace s) { saveError = e.toString(); }).whenComplete(() {
      _pending--; notifyListeners();
    });
    // Errors are exposed through saveError/flush, never left unhandled.
    return _queue;
  }
  void save(Workout workout) {
    final json = workout.encode(), id = workout.id;
    _workouts[id] = Workout.decode(json); _dirty[id] = json;
    _enqueue(() async {
      await platform.writeWorkout(id, json);
      if (_dirty[id] == json) _dirty.remove(id);
    });
  }
  Future<void> saveSettings(AppSettings next) async {
    settings = next; _settingsDirty = true;
    final json = jsonEncode(next.toJson());
    await _enqueue(() async {
      await platform.writeSettings(json);
      if (jsonEncode(settings.toJson()) == json) _settingsDirty = false;
    });
  }
  Future<void> retry() async {
    for (final entry in Map<String, String>.from(_dirty).entries) {
      save(Workout.decode(entry.value));
    }
    if (_settingsDirty) await saveSettings(settings);
    await flush();
  }
  Future<void> flush() async {
    await _queue;
    if (unsaved || saveError != null) throw StateError(saveError ?? 'Salvataggio non completato');
  }
  Future<void> delete(String id) async {
    await flush();
    await platform.deleteWorkout(id);
    _workouts.remove(id); _dirty.remove(id); notifyListeners();
  }
}
