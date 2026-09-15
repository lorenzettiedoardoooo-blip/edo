import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/workout.dart';
import '../services/editor_controller.dart';
import '../storage/workout_store.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/workout_grid.dart';
import '../image_generation/poster_renderer.dart';
import 'preview_screen.dart';

class EditorScreen extends StatefulWidget {
  final WorkoutStore store;
  final Workout workout;
  const EditorScreen({super.key, required this.store, required this.workout});
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}
class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  late final EditorController editor;
  final cellInput = TextEditingController();
  final titleInput = TextEditingController();
  final inputFocus = FocusNode();
  final gridKey = GlobalKey<WorkoutGridState>();
  CopiedCells? copied;
  bool generating = false, canLeave = false;
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    editor = EditorController(widget.workout.copy(), widget.store.save)..addListener(refresh);
    cellInput.text = editor.active.text; titleInput.text = editor.workout.title;
  }
  void refresh() {
    if (cellInput.text != editor.active.text) {
      cellInput.value = TextEditingValue(text: editor.active.text,
        selection: TextSelection.collapsed(offset: editor.active.text.length));
    }
    if (titleInput.text != editor.workout.title) {
      titleInput.value = TextEditingValue(text: editor.workout.title,
        selection: TextSelection.collapsed(offset: editor.workout.title.length));
    }
    if (mounted) setState(() {});
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      widget.store.flush().catchError((Object _) {});
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); editor.removeListener(refresh); editor.dispose();
    cellInput.dispose(); titleInput.dispose(); inputFocus.dispose(); super.dispose();
  }
  void message(Object text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text.toString())));
  }
  Future<bool> confirm(String title, String content) async => await showDialog<bool>(context: context,
    builder: (ctx) => AlertDialog(title: Text(title), content: Text(content), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULLA')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CONFERMA'))])) ?? false;
  Future<void> leave() async {
    FocusScope.of(context).unfocus();
    try {
      await widget.store.retry();
      if (!mounted) return;
      setState(() { canLeave = true; });
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.pop(context); });
    } catch (e) { message('Salvataggio non riuscito. Resta nell’editor e riprova: $e'); }
  }
  void editCell() {
    inputFocus.requestFocus();
    cellInput.selection = TextSelection(baseOffset: 0, extentOffset: cellInput.text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) => gridKey.currentState?.revealSelection());
  }
  void move(int r, int c) { editor.move(r, c); editCell(); }
  Future<void> metadata() async {
    FocusScope.of(context).unfocus();
    final w = editor.workout;
    final fields = <String, TextEditingController>{
      'title': TextEditingController(text: w.title), 'subtitle': TextEditingController(text: w.subtitle),
      'totalReps': TextEditingController(text: w.totalReps), 'difficulty': TextEditingController(text: w.difficulty),
      'notes': TextEditingController(text: w.notes),
    };
    var date = DateTime.parse(w.date);
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => SafeArea(child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DETTAGLI WORKOUT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
          const SizedBox(height: 16),
          for (final entry in fields.entries) ...[
            TextField(controller: entry.value, minLines: entry.key == 'notes' ? 3 : 1,
              maxLines: entry.key == 'notes' ? 6 : entry.key == 'subtitle' ? 2 : 1,
              keyboardType: entry.key == 'totalReps' ? TextInputType.number : TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: {'title':'TITLE','subtitle':'SUBTITLE · opzionale',
                'totalReps':'TOTAL REPS · opzionale','difficulty':'DIFFICULTY · opzionale','notes':'NOTES · opzionale'}[entry.key]),
              onChanged: (v) => editor.setMetadata(entry.key, v)), const SizedBox(height: 12),
          ],
          OutlinedButton.icon(icon: const Icon(Icons.calendar_month), label: Text('DATE  ${date.toIso8601String().substring(0, 10)}'),
            onPressed: () async {
              final picked = await showDatePicker(context: ctx, initialDate: date,
                firstDate: DateTime(1900), lastDate: DateTime(2200));
              if (picked != null && ctx.mounted) {
                update(() { date = picked; }); editor.setMetadata('date', picked.toIso8601String().substring(0, 10));
              }
            }),
          const SizedBox(height: 12),
          const Text('I campi vuoti non compaiono nella grafica.', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('FATTO'))),
        ]))))));
    // The route owns the TextFields until its closing animation completes.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    for (final c in fields.values) { c.dispose(); }
  }
  Future<void> range() async {
    var r1 = editor.selection.top, c1 = editor.selection.left;
    var r2 = editor.selection.bottom, c2 = editor.selection.right;
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) {
      Widget choose(String label, int value, int count, void Function(int) change, bool column) =>
        Expanded(child: DropdownButtonFormField<int>(initialValue: value, decoration: InputDecoration(labelText: label),
          items: List.generate(count, (i) => DropdownMenuItem(value: i,
            child: Text(column ? String.fromCharCode(65 + i) : '${i + 1}'))),
          onChanged: (v) { if (v != null) update(() => change(v)); }));
      return AlertDialog(title: const Text('Seleziona intervallo'), content: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [choose('Da riga', r1, editor.workout.rows, (v) => r1 = v, false), const SizedBox(width: 10),
          choose('Colonna', c1, editor.workout.cols, (v) => c1 = v, true)]), const SizedBox(height: 12),
        Row(children: [choose('A riga', r2, editor.workout.rows, (v) => r2 = v, false), const SizedBox(width: 10),
          choose('Colonna', c2, editor.workout.cols, (v) => c2 = v, true)]),
      ]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ANNULLA')),
        FilledButton(onPressed: () { editor.setRange(CellRange.between(r1, c1, r2, c2)); Navigator.pop(ctx); }, child: const Text('SELEZIONA'))]);
    }));
  }
  Future<void> colors() async {
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (ctx) =>
      SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final background in [false, true]) ...[
          Text(background ? 'SFONDO CELLE' : 'COLORE TESTO'), const SizedBox(height: 12),
          Wrap(spacing: 12, children: [for (final value in <int?>[null,0xFFF7F7F8,0xFFE63840,0xFF20232B,0xFFF5CE6C])
            IconButton.filledTonal(tooltip: value == null ? 'Automatico' : value.toRadixString(16),
              onPressed: () { editor.format((c) { if (background) { c.background = value; } else { c.foreground = value; } }); },
              icon: value == null ? const Icon(Icons.restart_alt) : Icon(Icons.circle, color: Color(value))) ]),
          const SizedBox(height: 20),
        ],
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('FATTO')),
      ]))));
  }
  Future<void> action(String command) async {
    try {
      switch (command) {
        case 'bold': final boldValue = !editor.active.bold; editor.format((c) => c.bold = boldValue);
        case 'normal': editor.format((c) => c.bold = false);
        case 'center': final centerValue = !editor.active.centered; editor.format((c) => c.centered = centerValue);
        case 'left': editor.format((c) => c.centered = false);
        case 'group': editor.group();
        case 'ungroup': editor.ungroup();
        case 'merge':
          if (editor.mergeHidesText && !await confirm('Unire le celle?',
            'Verrà mostrato il testo della cella in alto a sinistra. Gli altri testi restano conservati e tornano visibili con UNMERGE.')) return;
          editor.merge();
        case 'unmerge': editor.unmerge();
        case 'clear': editor.format((c) => c.text = '');
        case 'border0': editor.format((c) => c.border = 0);
        case 'border1': editor.format((c) => c.border = 1);
        case 'border2': editor.format((c) => c.border = 2);
        case 'copy': copied = editor.copy(); await Clipboard.setData(ClipboardData(text: copied!.tsv)); message('Celle copiate');
        case 'paste':
          final clip = await Clipboard.getData(Clipboard.kTextPlain);
          if (!mounted) return;
          if (copied != null && clip?.text == copied!.tsv) { editor.paste(copied!); }
          else if (clip?.text != null) { editor.pasteTsv(clip!.text!); }
        case 'range': await range();
        case 'colors': await colors();
        case 'wider': editor.resizeColumns(20);
        case 'narrower': editor.resizeColumns(-20);
        case 'taller': editor.resizeRows(8);
        case 'shorter': editor.resizeRows(-8);
        case 'addRow': editor.addRow();
        case 'addColumn': editor.addColumn();
        case 'deleteRow':
          if (await confirm('Eliminare la riga ${editor.selection.top + 1}?', 'Verranno eliminati i contenuti di questa riga. Puoi usare UNDO.')) editor.deleteAxis(true);
        case 'deleteColumn':
          if (await confirm('Eliminare la colonna ${String.fromCharCode(65 + editor.selection.left)}?', 'Verranno eliminati i contenuti di questa colonna. Puoi usare UNDO.')) editor.deleteAxis(false);
      }
    } catch (e) { message(e); }
  }
  Future<void> generate() async {
    FocusScope.of(context).unfocus(); setState(() { generating = true; });
    try {
      await widget.store.retry();
      final result = await PosterRenderer().render(editor.workout.copy(), widget.store.settings);
      final format = widget.store.settings.format;
      final bytes = await widget.store.platform.encodeImage(result.png, format);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PreviewScreen(
        bytes: bytes, format: format, warnings: result.warnings, platform: widget.store.platform)));
    } catch (e) { message(e); }
    finally { if (mounted) setState(() { generating = false; }); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: canLeave,
    onPopInvokedWithResult: (didPop, result) { if (!didPop) leave(); },
    child: Scaffold(resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('WORKOUT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [IconButton(tooltip: 'DUPLICATE', onPressed: generating ? null : () async {
          try {
            await widget.store.retry();
            final copy = editor.workout.duplicate(); widget.store.save(copy);
            if (!context.mounted) return;
            await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => EditorScreen(store: widget.store, workout: copy)));
          } catch (e) { message(e); }
        }, icon: const Icon(Icons.copy_all)),
        IconButton(tooltip: 'Istruzioni griglia', onPressed: () => showDialog<void>(context: context,
          builder: (ctx) => AlertDialog(title: const Text('COMPILAZIONE RAPIDA'),
            content: const SingleChildScrollView(child: Text('Tocca una cella e scrivi nel campo CELLA. Le frecce cambiano cella; Next va sotto.\n\n'
              'Tieni premuto e trascina per selezionare un blocco. Oppure attiva SELEZIONE e tocca l’angolo opposto. Tocca numeri/lettere per righe/colonne.\n\n'
              'Sposta la tabella con un dito. Usa due dita o +/− per lo zoom. Il menu ⋯ contiene bordi, copia/incolla e dimensioni.\n\n'
              'Le righe sottili dell’editor sono guide: nell’immagine compaiono solo i bordi impostati e i gruppi.')),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))])), icon: const Icon(Icons.help_outline))]),
      body: SafeArea(top: false, child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
          Expanded(child: TextField(controller: titleInput, decoration: const InputDecoration(labelText: 'TITLE', isDense: true),
            onChanged: (v) => editor.setMetadata('title', v))),
          IconButton(tooltip: 'Titolo, data e dettagli', onPressed: metadata, icon: const Icon(Icons.tune)),
        ])),
        EditorToolbar(editor: editor, onAction: action),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
          Text(editor.selection.label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
          const Spacer(),
          TextButton(style: TextButton.styleFrom(visualDensity: VisualDensity.compact), onPressed: () {
            editor.setSelecting(!editor.selecting); FocusScope.of(context).unfocus();
          }, child: Text(editor.selecting ? 'FINE SELEZIONE' : 'SELEZIONE', style: const TextStyle(fontSize: 11))),
          IconButton(visualDensity: VisualDensity.compact, tooltip: 'Zoom −', onPressed: () => gridKey.currentState?.zoom(.85), icon: const Icon(Icons.remove, size: 18)),
          IconButton(visualDensity: VisualDensity.compact, tooltip: 'Zoom +', onPressed: () => gridKey.currentState?.zoom(1.18), icon: const Icon(Icons.add, size: 18)),
        ])),
        Expanded(child: WorkoutGrid(key: gridKey, editor: editor, onEdit: editCell)),
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: TextField(
          controller: cellInput, focusNode: inputFocus, minLines: 1, maxLines: 2,
          textInputAction: TextInputAction.next, textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: 'CELLA ${String.fromCharCode(65 + editor.selection.left)}${editor.selection.top + 1}',
            isDense: true, suffixIcon: IconButton(tooltip: 'Chiudi tastiera', onPressed: () => inputFocus.unfocus(), icon: const Icon(Icons.keyboard_hide))),
          onChanged: editor.setText, onSubmitted: (_) => move(1, 0))),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(tooltip: 'Sinistra', onPressed: () => move(0, -1), icon: const Icon(Icons.arrow_back)),
          IconButton(tooltip: 'Sopra', onPressed: () => move(-1, 0), icon: const Icon(Icons.arrow_upward)),
          IconButton(tooltip: 'Sotto / Next', onPressed: () => move(1, 0), icon: const Icon(Icons.arrow_downward)),
          IconButton(tooltip: 'Destra', onPressed: () => move(0, 1), icon: const Icon(Icons.arrow_forward)),
          ListenableBuilder(listenable: widget.store, builder: (context, _) =>
            GestureDetector(onTap: () async { try { await widget.store.retry(); } catch (e) { message(e); } },
              child: Padding(padding: const EdgeInsets.all(6), child: Text(widget.store.saveError != null ? 'RIPROVA' : widget.store.saving ? 'SALVO…' : 'SALVATO',
                style: TextStyle(fontSize: 10, color: widget.store.saveError != null ? Colors.orange : Colors.white54))))),
        ]),
        if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
          TextButton(onPressed: metadata, child: Text(
            '${editor.workout.date}  ·  ${editor.workout.totalReps.isEmpty ? 'TOTAL REPS' : '${editor.workout.totalReps} REPS'}  ·  DIFFICULTY  ·  NOTES',
            style: const TextStyle(fontSize: 10))),
          Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: SizedBox(width: double.infinity,
            child: FilledButton.icon(onPressed: generating ? null : generate,
              icon: generating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
              label: Text(generating ? 'GENERAZIONE…' : 'GENERATE IMAGE')))),
        ],
      ]))));
}
