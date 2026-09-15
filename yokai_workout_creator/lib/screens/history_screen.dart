import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../storage/workout_store.dart';
import 'editor_screen.dart';

class HistoryScreen extends StatelessWidget {
  final WorkoutStore store;
  const HistoryScreen({super.key, required this.store});
  Future<void> action(BuildContext context, Workout w, String command) async {
    if (command == 'delete') {
      final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Eliminare il workout?'), content: Text('${w.title}\n${w.date}\nQuesta azione non è annullabile.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULLA')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE'))]));
      if (yes != true) return;
      try { await store.delete(w.id); } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Eliminazione non riuscita: $e')));
      }
    } else {
      final next = command == 'duplicate' ? w.duplicate() : w.copy();
      if (command == 'duplicate') store.save(next);
      if (!context.mounted) return;
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => EditorScreen(store: store, workout: next)));
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('WORKOUTS')),
    body: ListenableBuilder(listenable: store, builder: (context, _) {
      final items = store.workouts;
      if (items.isEmpty) return const Center(child: Text('Nessun workout. Crea il primo dalla Home.'));
      return ListView.separated(padding: const EdgeInsets.all(18), itemCount: items.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10), itemBuilder: (context, i) {
          final w = items[i];
          return Card(child: ListTile(contentPadding: const EdgeInsets.all(16),
            title: Text(w.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${w.date}${w.totalReps.isEmpty ? '' : '  •  ${w.totalReps} REPS'}'
              '${w.subtitle.isEmpty ? '' : '\n${w.subtitle}'}'),
            onTap: () => action(context, w, 'open'),
            trailing: PopupMenuButton<String>(onSelected: (v) => action(context, w, v),
              itemBuilder: (_) => const [PopupMenuItem(value: 'open', child: Text('OPEN / EDIT')),
                PopupMenuItem(value: 'duplicate', child: Text('DUPLICATE')),
                PopupMenuItem(value: 'delete', child: Text('DELETE'))])));
        });
    }));
}
