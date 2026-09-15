import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/workout.dart';

class CopiedCells {
  final List<List<Cell>> cells;
  final List<CellRange> merges, groups;
  CopiedCells(this.cells, this.merges, this.groups);
  String get tsv => cells.map((r) => r.map((c) => c.text.replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t')).join('\n');
}

class EditorController extends ChangeNotifier {
  Workout workout;
  CellRange selection = const CellRange(0, 0, 0, 0);
  bool selecting = false;
  final void Function(Workout) onChanged;
  final List<String> _undo = [], _redo = [];
  String? _typingKey;
  DateTime? _typingTime;
  int anchorRow = 0, anchorCol = 0;
  EditorController(this.workout, this.onChanged);
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  Cell get active => workout.cells[selection.top][selection.left];
  void select(int r, int c, {bool extend = false}) {
    if (extend) {
      selection = workout.expandSelection(CellRange.between(anchorRow, anchorCol, r, c));
    } else {
      anchorRow = r; anchorCol = c;
      selection = workout.expandSelection(CellRange(r, c, r, c));
    }
    _typingKey = null;
    notifyListeners();
  }
  void setRange(CellRange range) {
    selection = workout.expandSelection(range);
    anchorRow = selection.top; anchorCol = selection.left;
    selecting = true; _typingKey = null; notifyListeners();
  }
  void setSelecting(bool value) { selecting = value; notifyListeners(); }
  void move(int dr, int dc) {
    final r = (dr > 0 ? selection.bottom + dr : selection.top + dr).clamp(0, workout.rows - 1).toInt();
    final c = (dc > 0 ? selection.right + dc : selection.left + dc).clamp(0, workout.cols - 1).toInt();
    selecting = false; select(r, c);
  }
  void transact(void Function() edit, {String? typingKey}) {
    final before = workout.encode();
    final now = DateTime.now();
    try { edit(); } catch (_) { workout = Workout.decode(before); rethrow; }
    if (workout.encode() == before) return;
    final combine = typingKey != null && _typingKey == typingKey && _typingTime != null &&
      now.difference(_typingTime!).inMilliseconds < 800;
    if (!combine) {
      _undo.add(before);
      if (_undo.length > 60) _undo.removeAt(0);
    }
    _redo.clear(); _typingKey = typingKey; _typingTime = now;
    workout.modified = now.toIso8601String();
    onChanged(workout); notifyListeners();
  }
  void setText(String text) => transact(() { active.text = text; },
    typingKey: 'cell:${selection.top}:${selection.left}');
  void setMetadata(String key, String value) => transact(() {
    switch (key) {
      case 'title': workout.title = value;
      case 'date': workout.date = value;
      case 'subtitle': workout.subtitle = value;
      case 'totalReps': workout.totalReps = value;
      case 'difficulty': workout.difficulty = value;
      case 'notes': workout.notes = value;
    }
  }, typingKey: 'meta:$key');
  void format(void Function(Cell) edit) => transact(() {
    for (var r = selection.top; r <= selection.bottom; r++) {
      for (var c = selection.left; c <= selection.right; c++) { edit(workout.cells[r][c]); }
    }
  });
  void group() => transact(() {
    if (!workout.groups.contains(selection)) workout.groups.add(selection);
  });
  void ungroup() => transact(() { workout.groups.removeWhere(selection.overlaps); });
  bool get mergeHidesText {
    for (var r = selection.top; r <= selection.bottom; r++) {
      for (var c = selection.left; c <= selection.right; c++) {
        if ((r != selection.top || c != selection.left) && workout.cells[r][c].text.isNotEmpty) return true;
      }
    }
    return false;
  }
  void merge() => transact(() {
    if (selection.rows * selection.cols < 2) return;
    workout.merges.removeWhere(selection.overlaps);
    workout.merges.add(selection);
    active.centered = true;
  });
  void unmerge() => transact(() { workout.merges.removeWhere(selection.overlaps); });
  CopiedCells copy() => CopiedCells(
    List.generate(selection.rows, (r) => List.generate(selection.cols,
      (c) => workout.cells[r + selection.top][c + selection.left].copy())),
    workout.merges.where(selection.covers).map((m) => m.shifted(-selection.top, -selection.left)).toList(),
    workout.groups.where(selection.covers).map((m) => m.shifted(-selection.top, -selection.left)).toList());
  void paste(CopiedCells data) {
    final dest = CellRange(selection.top, selection.left,
      selection.top + data.cells.length - 1, selection.left + data.cells.first.length - 1);
    if (dest.bottom >= workout.rows || dest.right >= workout.cols) {
      throw StateError('Il blocco supera la griglia. Aggiungi righe/colonne o scegli un’altra cella.');
    }
    if (workout.merges.any((m) => m.overlaps(dest) && !dest.covers(m))) {
      throw StateError('La destinazione taglia celle unite: usa prima UNMERGE.');
    }
    transact(() {
      workout.merges.removeWhere(dest.overlaps);
      workout.groups.removeWhere(dest.covers);
      for (var r = 0; r < data.cells.length; r++) {
        for (var c = 0; c < data.cells[r].length; c++) {
          workout.cells[dest.top + r][dest.left + c] = data.cells[r][c].copy();
        }
      }
      workout.merges.addAll(data.merges.map((m) => m.shifted(dest.top, dest.left)));
      workout.groups.addAll(data.groups.map((m) => m.shifted(dest.top, dest.left)));
      selection = dest;
    });
  }
  void pasteTsv(String text) {
    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    if (lines.length > 1 && lines.last.isEmpty) lines.removeLast();
    final split = lines.map((s) => s.split('\t')).toList();
    final columns = split.fold<int>(1, (n, r) => math.max(n, r.length));
    paste(CopiedCells(split.map((r) => List.generate(columns,
      (c) => Cell(text: c < r.length ? r[c] : ''))).toList(), [], []));
  }
  void resizeColumns(double delta) => transact(() {
    for (var c = selection.left; c <= selection.right; c++) {
      workout.widths[c] = (workout.widths[c] + delta).clamp(48.0, 420.0).toDouble();
    }
  });
  void resizeRows(double delta) => transact(() {
    for (var r = selection.top; r <= selection.bottom; r++) {
      workout.heights[r] = (workout.heights[r] + delta).clamp(36.0, 180.0).toDouble();
    }
  });
  void addRow() => transact(() {
    if (workout.rows >= 20) throw StateError('Massimo 20 righe.');
    workout.cells.add(List.generate(workout.cols, (_) => Cell())); workout.heights.add(58);
  });
  void addColumn() => transact(() {
    if (workout.cols >= 12) throw StateError('Massimo 12 colonne.');
    for (final r in workout.cells) { r.add(Cell()); } workout.widths.add(100);
  });
  CellRange? _afterDelete(CellRange area, int index, bool row) {
    final start = row ? area.top : area.left, end = row ? area.bottom : area.right;
    if (start == end && start == index) return null;
    final a = start > index ? start - 1 : start;
    final b = end >= index ? end - 1 : end;
    return row ? CellRange(a, area.left, b, area.right) : CellRange(area.top, a, area.bottom, b);
  }
  void deleteAxis(bool row) => transact(() {
    if ((row ? workout.rows : workout.cols) <= 1) throw StateError('Deve restare almeno una riga/colonna.');
    final index = row ? selection.top : selection.left;
    if (row) { workout.cells.removeAt(index); workout.heights.removeAt(index); }
    else { for (final r in workout.cells) { r.removeAt(index); } workout.widths.removeAt(index); }
    workout.groups = workout.groups.map((a) => _afterDelete(a, index, row)).whereType<CellRange>().toList();
    workout.merges = workout.merges.map((a) => _afterDelete(a, index, row))
      .whereType<CellRange>().where((a) => a.rows * a.cols > 1).toList();
    final r = math.min(selection.top, workout.rows - 1), c = math.min(selection.left, workout.cols - 1);
    selection = workout.expandSelection(CellRange(r, c, r, c));
    anchorRow = r; anchorCol = c;
  });
  void _restore(String snapshot) {
    workout = Workout.decode(snapshot); workout.modified = DateTime.now().toIso8601String();
    final r = math.min(selection.top, workout.rows - 1), c = math.min(selection.left, workout.cols - 1);
    selection = workout.expandSelection(CellRange(r, c, r, c));
    anchorRow = r; anchorCol = c; _typingKey = null;
    onChanged(workout); notifyListeners();
  }
  void undo() { if (canUndo) { _redo.add(workout.encode()); _restore(_undo.removeLast()); } }
  void redo() { if (canRedo) { _undo.add(workout.encode()); _restore(_redo.removeLast()); } }
}
