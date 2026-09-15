import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../storage/workout_store.dart';
import '../theme/yokai_theme.dart';
import 'editor_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  final WorkoutStore store;
  const HomeScreen({super.key, required this.store});
  Future<void> create(BuildContext context) async {
    final template = await showModalBottomSheet<String>(context: context, showDragHandle: true,
      builder: (context) => SafeArea(child: ListView(shrinkWrap: true, children: [
        const ListTile(title: Text('SCEGLI UN PUNTO DI PARTENZA', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('Ogni cella rimane liberamente modificabile.')),
        for (final t in ['EMPTY','ROUNDS','CIRCUIT','A / B / C','AMRAP','FOR TIME'])
          ListTile(leading: const Icon(Icons.grid_view_rounded), title: Text(t),
            trailing: const Icon(Icons.arrow_forward), onTap: () => Navigator.pop(context, t)),
      ])));
    if (template == null || !context.mounted) return;
    final workout = Workout.template(template); store.save(workout);
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => EditorScreen(store: store, workout: workout)));
  }
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: store, builder: (context, _) =>
    Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.all(26), children: [
      const SizedBox(height: 32),
      Align(alignment: Alignment.centerLeft, child: Container(width: 44, height: 5, color: YokaiTheme.red)),
      const SizedBox(height: 24),
      if (store.settings.logoBase64 != null)
        Align(alignment: Alignment.centerLeft, child: Image.memory(base64Decode(store.settings.logoBase64!),
          height: 90, width: 220, alignment: Alignment.centerLeft, fit: BoxFit.contain))
      else const Text('YOKAI', style: TextStyle(fontSize: 66, fontWeight: FontWeight.w900, letterSpacing: -3)),
      const Text('WORKOUT\nCREATOR', style: TextStyle(fontSize: 33, fontWeight: FontWeight.w800, height: 1.05)),
      const SizedBox(height: 18),
      const Text('Il tuo allenamento.\nPronto da pubblicare.', style: TextStyle(color: Colors.white60, fontSize: 17)),
      const SizedBox(height: 42),
      FilledButton.icon(onPressed: () => create(context), icon: const Icon(Icons.add), label: const Text('NEW WORKOUT')),
      const SizedBox(height: 14),
      OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 58)),
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => HistoryScreen(store: store))),
        icon: const Icon(Icons.calendar_month_outlined), label: Text('WORKOUTS  /  ${store.workouts.length}')),
      const SizedBox(height: 14),
      OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 58)),
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SettingsScreen(store: store))),
        icon: const Icon(Icons.tune), label: const Text('SETTINGS')),
      const SizedBox(height: 34),
      if (store.workouts.isNotEmpty) ...[
        const Text('RIPRENDI L’ULTIMO', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 2)),
        ListTile(contentPadding: EdgeInsets.zero, title: Text(store.workouts.first.title),
          subtitle: Text(store.workouts.first.date), trailing: const Icon(Icons.arrow_forward),
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) =>
            EditorScreen(store: store, workout: store.workouts.first.copy())))),
      ],
      if (store.saveError != null) Text('Salvataggio da riprovare: ${store.saveError}', style: const TextStyle(color: Colors.orange)),
      const SizedBox(height: 24),
      const Text('OFFLINE  •  NO ACCOUNT  •  1080 × 1920', style: TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 1)),
    ])))) ;
}
