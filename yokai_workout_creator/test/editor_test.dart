import 'package:flutter_test/flutter_test.dart';
import 'package:yokai_workout_creator/models/workout.dart';
import 'package:yokai_workout_creator/services/editor_controller.dart';

void main() {
  EditorController make() => EditorController(Workout.empty(), (_) {});
  test('Default grid: 150 independent editable cells', () {
    final e = make();
    expect(e.workout.rows, 15); expect(e.workout.cols, 10);
    e.setText('SQUAT'); expect(e.workout.cells[1][0].text, '');
    expect(Workout.decode(e.workout.encode()).cells[0][0].text, 'SQUAT');
  });
  test('Merge preserves hidden content and expands rectangular selections', () {
    final e = make(); e.setText('CIRCUIT A'); e.select(0, 1); e.setText('retained');
    e.setRange(const CellRange(0, 0, 0, 3)); e.merge();
    e.select(0, 2); expect(e.selection, const CellRange(0, 0, 0, 3));
    e.unmerge(); expect(e.workout.cells[0][1].text, 'retained');
    expect(e.workout.merges, isEmpty);
  });
  test('Copy/paste relocates merges, groups, content and formatting', () {
    final e = make(); e.setText('A'); e.format((c) { c.bold = true; c.border = 2; });
    e.setRange(const CellRange(0, 0, 0, 1)); e.merge();
    e.setRange(const CellRange(0, 0, 2, 1)); e.group(); final copy = e.copy();
    e.select(5, 3); e.paste(copy);
    expect(e.workout.merges, contains(const CellRange(5, 3, 5, 4)));
    expect(e.workout.groups, contains(const CellRange(5, 3, 7, 4)));
    expect(e.workout.cells[5][3].bold, true); expect(e.workout.cells[5][3].text, 'A');
    e.format((c) => c.text = 'changed'); expect(e.workout.cells[0][0].text, 'A');
  });
  test('Invalid paste is atomic and does not damage target merges', () {
    final e = make(); e.setRange(const CellRange(0, 0, 0, 2)); e.merge();
    e.select(1, 1); final before = e.workout.encode();
    final large = CopiedCells(List.generate(20, (_) => [Cell(text: 'x')]), [], []);
    expect(() => e.paste(large), throwsStateError); expect(e.workout.encode(), before);
    e.select(0, 0); // selected merge spans 3 cols; a 1-cell paste must be rejected
    expect(() => e.pasteTsv('x'), throwsStateError);
  });
  test('UNDO REDO covers metadata, dimensions, groups and content', () {
    final e = make(); e.setText('20'); e.setMetadata('notes', 'Rest 60 seconds');
    e.addColumn(); e.undo(); expect(e.workout.cols, 10); e.redo(); expect(e.workout.cols, 11);
    e.undo(); e.undo(); expect(e.workout.notes, ''); e.undo(); expect(e.active.text, '');
    e.redo(); expect(e.active.text, '20');
  });
  test('Deleting axes shrinks and relocates ranges without out-of-bounds data', () {
    final e = make(); e.setRange(const CellRange(2, 1, 4, 3)); e.group(); e.merge();
    e.setRange(const CellRange(0, 0, 0, 0)); e.deleteAxis(true);
    expect(e.workout.merges.single, const CellRange(1, 1, 3, 3));
    e.select(0, 0); e.deleteAxis(false);
    expect(e.workout.groups.single, const CellRange(1, 0, 3, 2));
    expect(() => Workout.decode(e.workout.encode()), returnsNormally);
    e.undo(); expect(e.workout.cols, 10);
  });
  test('Used area includes explicit groups and ignores empty trailing cells', () {
    final e = make(); e.select(5, 4); e.setText('15');
    expect(e.workout.usedRange, const CellRange(0, 0, 5, 4));
    e.setRange(const CellRange(8, 0, 10, 1)); e.group();
    expect(e.workout.usedRange, const CellRange(0, 0, 10, 4));
  });
  test('Duplication has independent values, new identity, current date', () {
    final w = Workout.template('A / B / C'); w.notes = 'Rest'; w.date = '2024-01-01';
    final duplicate = w.duplicate(); duplicate.cells[0][0].text = 'B';
    expect(duplicate.id, isNot(w.id)); expect(duplicate.date, Workout.today());
    expect(w.cells[0][0].text, 'CIRCUIT A'); expect(duplicate.notes, 'Rest');
  });
  test('Limits and TSV preserve a rectangular grid', () {
    final e = make(); e.pasteTsv('EXERCISE\tREPS\nSQUAT\t20\nRUN');
    expect(e.workout.cells[2][1].text, '');
    for (var i = 0; i < 5; i++) { e.addRow(); }
    expect(e.addRow, throwsStateError); e.addColumn(); e.addColumn();
    expect(e.addColumn, throwsStateError);
  });
  test('Malformed snapshots are rejected instead of silently resetting data', () {
    final j = Workout.empty().toJson(); j['widths'] = [double.nan];
    expect(() => Workout.fromJson(j), throwsFormatException);
  });
}
