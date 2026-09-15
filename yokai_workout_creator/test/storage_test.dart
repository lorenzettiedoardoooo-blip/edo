import 'package:flutter_test/flutter_test.dart';
import 'package:yokai_workout_creator/models/workout.dart';
import 'package:yokai_workout_creator/services/platform_bridge.dart';
import 'package:yokai_workout_creator/storage/workout_store.dart';

class MemoryPlatform extends PlatformBridge {
  final Map<String, String> data = {};
  final List<String> writes = [];
  bool fail = false;
  String? settings;
  @override
  Future<List<String>> readWorkouts() async => data.values.toList();
  @override
  Future<void> writeWorkout(String id, String json) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    if (fail) throw StateError('disk full');
    writes.add(json); data[id] = json;
  }
  @override
  Future<String?> readSettings() async => settings;
  @override
  Future<void> writeSettings(String json) async { if (fail) throw StateError('disk full'); settings = json; }
  @override
  Future<void> deleteWorkout(String id) async { data.remove(id); }
}
void main() {
  test('Autosave snapshots are ordered, not mutable references', () async {
    final platform = MemoryPlatform(), w = Workout.empty();
    final store = WorkoutStore(platform); await store.load();
    w.title = 'ONE'; store.save(w); w.title = 'TWO'; store.save(w);
    w.title = 'THREE'; store.save(w); await store.flush();
    expect(platform.writes.map((j) => Workout.decode(j).title), ['ONE', 'TWO', 'THREE']);
    final reloaded = WorkoutStore(platform); await reloaded.load();
    expect(reloaded.workouts.single.title, 'THREE'); expect(store.unsaved, false);
  });
  test('Failed write is retained, reported and retried', () async {
    final platform = MemoryPlatform()..fail = true;
    final store = WorkoutStore(platform), w = Workout.empty(); store.save(w);
    await expectLater(store.flush(), throwsStateError); expect(store.unsaved, true);
    platform.fail = false; await store.retry();
    expect(store.unsaved, false); expect(store.saveError, null); expect(platform.data, hasLength(1));
  });
  test('Delete cannot race with pending writes', () async {
    final platform = MemoryPlatform(), w = Workout.empty();
    final store = WorkoutStore(platform); store.save(w); await store.delete(w.id);
    expect(platform.data, isEmpty); expect(store.workouts, isEmpty);
  });
}
