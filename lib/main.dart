import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const YokaiApp());

class YokaiApp extends StatelessWidget {
  const YokaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF08090C);
    const accent = Color(0xFFFF5A36);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'YOKAI WORKOUT CREATOR',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF15171D),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class Exercise {
  String name;
  String qty;
  Exercise({this.name = '', this.qty = ''});
  Map<String, dynamic> toJson() => {'name': name, 'qty': qty};
  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(name: j['name'] ?? '', qty: j['qty'] ?? '');
}

class WorkoutBlock {
  String title;
  String meta;
  List<Exercise> rows;
  WorkoutBlock({this.title = 'BLOCCO', this.meta = '', List<Exercise>? rows}) : rows = rows ?? [Exercise()];
  Map<String, dynamic> toJson() => {'title': title, 'meta': meta, 'rows': rows.map((e) => e.toJson()).toList()};
  factory WorkoutBlock.fromJson(Map<String, dynamic> j) => WorkoutBlock(
        title: j['title'] ?? 'BLOCCO',
        meta: j['meta'] ?? '',
        rows: ((j['rows'] ?? []) as List).map((e) => Exercise.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
}

class Workout {
  String id;
  String title;
  DateTime date;
  List<WorkoutBlock> blocks;
  String totalReps;
  String notes;
  Workout({
    String? id,
    this.title = 'FITNESS WORKOUT',
    DateTime? date,
    List<WorkoutBlock>? blocks,
    this.totalReps = '',
    this.notes = '',
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        date = date ?? DateTime.now(),
        blocks = blocks ?? [WorkoutBlock(title: 'WORKOUT')];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'blocks': blocks.map((e) => e.toJson()).toList(),
        'totalReps': totalReps,
        'notes': notes,
      };

  factory Workout.fromJson(Map<String, dynamic> j) => Workout(
        id: j['id'],
        title: j['title'] ?? 'FITNESS WORKOUT',
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        blocks: ((j['blocks'] ?? []) as List).map((e) => WorkoutBlock.fromJson(Map<String, dynamic>.from(e))).toList(),
        totalReps: j['totalReps'] ?? '',
        notes: j['notes'] ?? '',
      );
}

class Store {
  static const key = 'yokai_workouts_v1';
  static Future<List<Workout>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Workout.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(Workout w) async {
    final p = await SharedPreferences.getInstance();
    final list = await load();
    final i = list.indexWhere((e) => e.id == w.id);
    if (i >= 0) {
      list[i] = w;
    } else {
      list.insert(0, w);
    }
    await p.setString(key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<void> delete(String id) async {
    final p = await SharedPreferences.getInstance();
    final list = await load()..removeWhere((e) => e.id == id);
    await p.setString(key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget bigButton(BuildContext context, IconData icon, String title, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SizedBox(
          width: double.infinity,
          height: 84,
          child: FilledButton.tonalIcon(
            onPressed: onTap,
            icon: Icon(icon, size: 30),
            label: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, letterSpacing: .5)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 18),
            const Text('YOKAI', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 4)),
            Text('WORKOUT CREATOR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 42),
            bigButton(context, Icons.add_circle_outline, 'NUOVO WORKOUT', () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(workout: Workout())))),
            bigButton(context, Icons.archive_outlined, 'ARCHIVIO', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchiveScreen()))),
            bigButton(context, Icons.dashboard_customize_outlined, 'TEMPLATE', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TemplatesScreen()))),
            const Spacer(),
            const Text('Offline • salvataggio automatico • PNG 1080×1920', style: TextStyle(color: Colors.white54)),
          ]),
        ),
      ),
    );
  }
}

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});
  Workout make(String type) {
    if (type == '720') {
      return Workout(title: '720 REPS', totalReps: '720', blocks: [WorkoutBlock(title: '6 BLOCCHI', rows: [Exercise(name: 'SQUAT HIGH PULL', qty: '50'), Exercise(name: 'CURL IN PIEDI', qty: '50'), Exercise(name: 'SIT UP', qty: '100'), Exercise(name: 'PUSH UP', qty: '50'), Exercise(name: 'REMATORE', qty: '100'), Exercise(name: 'BURPEES', qty: '50')])]);
    }
    if (type == '10x10') {
      return Workout(title: '10 REP × 10 RND', blocks: [WorkoutBlock(title: '10 REP × 10 RND', rows: [Exercise(name: 'BURPEES', qty: '10'), Exercise(name: 'PUSH UP FROG', qty: '10'), Exercise(name: 'REMATORE CENTRALE', qty: '10'), Exercise(name: 'SQUAT HIGH PULL', qty: '10'), Exercise(name: 'BACK LUNGES', qty: '10')])]);
    }
    return Workout(title: 'PROGRESSIONE 25 • 50 • 25', blocks: [WorkoutBlock(title: '3 FASI', meta: '25 - 50 - 25', rows: [Exercise(name: 'SQUAT HIGH PULL', qty: '25-50-25'), Exercise(name: 'TOUCH PUSH UP', qty: '25-50-25'), Exercise(name: 'GORILLA CURL', qty: '25-50-25'), Exercise(name: 'PULLOVER SQUAT', qty: '25-50-25'), Exercise(name: 'BURPEES', qty: '15-20-15')])]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('TEMPLATE')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (final t in [('720', '720 REPS'), ('10x10', '10 REP × 10 RND'), ('prog', '25 • 50 • 25')])
            Card(child: ListTile(title: Text(t.$2, style: const TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => EditorScreen(workout: make(t.$1))))))
        ]),
      );
}

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});
  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<Workout> data = [];
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async => setState(() => data = await Store.load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ARCHIVIO')),
        body: data.isEmpty
            ? const Center(child: Text('Nessun workout salvato'))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: data.length,
                itemBuilder: (_, i) {
                  final w = data[i];
                  return Card(
                    child: ListTile(
                      title: Text(w.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(DateFormat('dd MMMM yyyy', 'it').format(w.date)),
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(workout: w)));
                        refresh();
                      },
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'dup') {
                            final c = Workout.fromJson(w.toJson());
                            c.id = DateTime.now().microsecondsSinceEpoch.toString();
                            c.title = '${c.title} COPIA';
                            await Store.save(c);
                          } else {
                            await Store.delete(w.id);
                          }
                          refresh();
                        },
                        itemBuilder: (_) => const [PopupMenuItem(value: 'dup', child: Text('Duplica')), PopupMenuItem(value: 'del', child: Text('Elimina'))],
                      ),
                    ),
                  );
                },
              ),
      );
}

class EditorScreen extends StatefulWidget {
  final Workout workout;
  const EditorScreen({super.key, required this.workout});
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Workout w;
  late TextEditingController titleC, totalC, notesC;
  @override
  void initState() {
    super.initState();
    w = widget.workout;
    titleC = TextEditingController(text: w.title);
    totalC = TextEditingController(text: w.totalReps);
    notesC = TextEditingController(text: w.notes);
  }

  Future<void> autosave() async {
    w.title = titleC.text.trim().isEmpty ? 'FITNESS WORKOUT' : titleC.text.trim();
    w.totalReps = totalC.text.trim();
    w.notes = notesC.text.trim();
    await Store.save(w);
  }

  void addBlock() => setState(() => w.blocks.add(WorkoutBlock(title: 'BLOCCO ${w.blocks.length + 1}')));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('EDITOR'),
          actions: [IconButton(onPressed: () async { await autosave(); if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => PreviewScreen(workout: w))); }, icon: const Icon(Icons.visibility_outlined))],
        ),
        floatingActionButton: FloatingActionButton.extended(onPressed: addBlock, icon: const Icon(Icons.add), label: const Text('BLOCCO')),
        body: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 100), children: [
          TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Titolo workout'), onChanged: (_) => autosave()),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: w.date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => w.date = d);
              autosave();
            },
            child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF15171D), borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(Icons.calendar_month), const SizedBox(width: 12), Text(DateFormat('dd MMMM yyyy', 'it').format(w.date))])),
          ),
          const SizedBox(height: 16),
          for (int bi = 0; bi < w.blocks.length; bi++) blockCard(bi),
          const SizedBox(height: 10),
          TextField(controller: totalC, decoration: const InputDecoration(labelText: 'TOTAL REPS (opzionale)', hintText: 'es. 720'), onChanged: (_) => autosave()),
          const SizedBox(height: 10),
          TextField(controller: notesC, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'NOTE FINALI'), onChanged: (_) => autosave()),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: () async { await autosave(); if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => PreviewScreen(workout: w))); }, icon: const Icon(Icons.auto_awesome), label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('ANTEPRIMA / GENERA IMMAGINE', style: TextStyle(fontWeight: FontWeight.bold)))),
        ]),
      );

  Widget blockCard(int bi) {
    final b = w.blocks[bi];
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(child: TextFormField(initialValue: b.title, decoration: const InputDecoration(labelText: 'Titolo blocco'), onChanged: (v) { b.title = v; autosave(); })),
            IconButton(onPressed: w.blocks.length == 1 ? null : () { setState(() => w.blocks.removeAt(bi)); autosave(); }, icon: const Icon(Icons.delete_outline)),
          ]),
          const SizedBox(height: 8),
          TextFormField(initialValue: b.meta, decoration: const InputDecoration(labelText: 'Giri / tempo / formula', hintText: 'es. 5 GIRI, 12 MIN AMRAP, 25-50-25'), onChanged: (v) { b.meta = v; autosave(); }),
          const SizedBox(height: 12),
          for (int ri = 0; ri < b.rows.length; ri++) exerciseRow(bi, ri),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () { setState(() => b.rows.add(Exercise())); autosave(); }, icon: const Icon(Icons.add), label: const Text('Aggiungi esercizio'))),
        ]),
      ),
    );
  }

  Widget exerciseRow(int bi, int ri) {
    final r = w.blocks[bi].rows[ri];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(flex: 3, child: TextFormField(initialValue: r.name, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'ESERCIZIO'), onChanged: (v) { r.name = v; autosave(); })),
        const SizedBox(width: 8),
        Expanded(flex: 1, child: TextFormField(initialValue: r.qty, decoration: const InputDecoration(hintText: '20 / X / 40"'), onChanged: (v) { r.qty = v; autosave(); })),
        IconButton(onPressed: () {
          setState(() {
            if (w.blocks[bi].rows.length > 1) w.blocks[bi].rows.removeAt(ri);
          });
          autosave();
        }, icon: const Icon(Icons.close, size: 20)),
      ]),
    );
  }
}

class PreviewScreen extends StatefulWidget {
  final Workout workout;
  const PreviewScreen({super.key, required this.workout});
  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final GlobalKey boundaryKey = GlobalKey();
  bool busy = false;

  Future<String?> renderPng() async {
    try {
      setState(() => busy = true);
      await Future.delayed(const Duration(milliseconds: 120));
      final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/YOKAI_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';
      await File(path).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      return path;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final path = await renderPng();
    if (path == null) return;
    await Gal.putImage(path, album: 'YOKAI');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Immagine salvata nella galleria')));
  }

  Future<void> share() async {
    final path = await renderPng();
    if (path == null) return;
    await Share.shareXFiles([XFile(path)], text: 'YOKAI WORKOUT');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ANTEPRIMA')),
        body: Column(children: [
          Expanded(child: Center(child: FittedBox(fit: BoxFit.contain, child: RepaintBoundary(key: boundaryKey, child: WorkoutPoster(workout: widget.workout))))),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: FilledButton.icon(onPressed: busy ? null : save, icon: const Icon(Icons.download), label: const Text('SALVA PNG'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton.tonalIcon(onPressed: busy ? null : share, icon: const Icon(Icons.share), label: const Text('CONDIVIDI'))),
              ]),
            ),
          ),
        ]),
      );
}

class WorkoutPoster extends StatelessWidget {
  final Workout workout;
  const WorkoutPoster({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF5A36);
    final nonEmptyRows = workout.blocks.expand((b) => b.rows).where((r) => r.name.trim().isNotEmpty).length;
    final small = nonEmptyRows > 16;
    return Container(
      width: 360,
      height: 640,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF11141B), Color(0xFF050608)]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('YOKAI', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: 3)),
            const SizedBox(height: 1),
            Text(workout.title.toUpperCase(), maxLines: 2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accent, letterSpacing: 1.2)),
          ])),
          Text(DateFormat('dd.MM.yyyy').format(workout.date), style: const TextStyle(fontSize: 10, color: Colors.white60)),
        ]),
        const SizedBox(height: 14),
        Container(height: 2, color: accent),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final b in workout.blocks) if (b.rows.any((r) => r.name.trim().isNotEmpty)) ...[
              Row(children: [
                Expanded(child: Text(b.title.toUpperCase(), style: TextStyle(fontSize: small ? 11 : 13, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
                if (b.meta.trim().isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: accent.withOpacity(.16), borderRadius: BorderRadius.circular(8)), child: Text(b.meta.toUpperCase(), style: TextStyle(fontSize: small ? 8 : 9, color: accent, fontWeight: FontWeight.w800))),
              ]),
              SizedBox(height: small ? 5 : 7),
              for (final r in b.rows.where((r) => r.name.trim().isNotEmpty)) Padding(
                padding: EdgeInsets.only(bottom: small ? 4 : 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 4, height: small ? 12 : 14, margin: const EdgeInsets.only(top: 2, right: 8), color: accent),
                  Expanded(child: Text(r.name.toUpperCase(), style: TextStyle(fontSize: small ? 11 : 13, height: 1.05, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 10),
                  Text(r.qty.toUpperCase(), textAlign: TextAlign.right, style: TextStyle(fontSize: small ? 11 : 13, fontWeight: FontWeight.w900, color: Colors.white)),
                ]),
              ),
              SizedBox(height: small ? 8 : 12),
            ]
          ])),
        ),
        if (workout.totalReps.trim().isNotEmpty) Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(border: Border.all(color: accent), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL REPS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accent)), Text(workout.totalReps, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))])),
        if (workout.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('NOTE  ${workout.notes}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8.5, color: Colors.white70, height: 1.25)),
        ],
        const SizedBox(height: 8),
        const Align(alignment: Alignment.centerRight, child: Text('TRAIN HARD • STAY YOKAI', style: TextStyle(fontSize: 7, color: Colors.white38, letterSpacing: 1))),
      ]),
    );
  }
}
