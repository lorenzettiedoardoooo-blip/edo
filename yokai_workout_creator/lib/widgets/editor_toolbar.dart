import 'package:flutter/material.dart';
import '../services/editor_controller.dart';

class EditorToolbar extends StatelessWidget {
  final EditorController editor;
  final void Function(String) onAction;
  const EditorToolbar({super.key, required this.editor, required this.onAction});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [
      IconButton(tooltip: 'UNDO', onPressed: editor.canUndo ? editor.undo : null, icon: const Icon(Icons.undo)),
      IconButton(tooltip: 'REDO', onPressed: editor.canRedo ? editor.redo : null, icon: const Icon(Icons.redo)),
      IconButton(tooltip: 'BOLD / NORMAL', isSelected: editor.active.bold,
        onPressed: () => onAction('bold'), icon: const Icon(Icons.format_bold)),
      IconButton(tooltip: 'CENTER / ALIGN LEFT', isSelected: editor.active.centered,
        onPressed: () => onAction('center'), icon: const Icon(Icons.format_align_center)),
      TextButton(onPressed: () => onAction('group'), child: const Text('GROUP')),
      TextButton(onPressed: () => onAction('merge'), child: const Text('MERGE')),
      PopupMenuButton<String>(tooltip: 'Altri comandi', icon: const Icon(Icons.more_horiz),
        onSelected: onAction, itemBuilder: (_) => const [
          PopupMenuItem(value: 'range', child: Text('Seleziona intervallo…')),
          PopupMenuItem(value: 'copy', child: Text('COPY')),
          PopupMenuItem(value: 'paste', child: Text('PASTE')),
          PopupMenuItem(value: 'ungroup', child: Text('UNGROUP')),
          PopupMenuItem(value: 'unmerge', child: Text('UNMERGE')),
          PopupMenuItem(value: 'normal', child: Text('NORMAL')),
          PopupMenuItem(value: 'left', child: Text('ALIGN LEFT')),
          PopupMenuItem(value: 'border0', child: Text('Nessun bordo')),
          PopupMenuItem(value: 'border1', child: Text('BORDER')),
          PopupMenuItem(value: 'border2', child: Text('THICK BORDER')),
          PopupMenuItem(value: 'colors', child: Text('Colore testo / sfondo…')),
          PopupMenuItem(value: 'clear', child: Text('CLEAR (solo contenuto)')),
          PopupMenuItem(value: 'wider', child: Text('Larghezza colonne +')),
          PopupMenuItem(value: 'narrower', child: Text('Larghezza colonne −')),
          PopupMenuItem(value: 'taller', child: Text('Altezza righe +')),
          PopupMenuItem(value: 'shorter', child: Text('Altezza righe −')),
          PopupMenuItem(value: 'addRow', child: Text('ADD ROW')),
          PopupMenuItem(value: 'addColumn', child: Text('ADD COLUMN')),
          PopupMenuItem(value: 'deleteRow', child: Text('DELETE ROW (prima selezionata)')),
          PopupMenuItem(value: 'deleteColumn', child: Text('DELETE COLUMN (prima selezionata)')),
        ]),
    ]));
}
