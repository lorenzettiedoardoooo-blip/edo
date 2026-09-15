import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:yokai_workout_creator/models/workout.dart';
import 'package:yokai_workout_creator/image_generation/poster_renderer.dart';

Workout sample({bool dense = false}) {
  final w = Workout.template('ROUNDS'); w.title = 'FULL BODY'; w.date = '2026-09-15';
  final rows = dense ? 15 : 5, cols = dense ? 9 : 5;
  const names = ['SQUAT','PUSH UP','BURPEE','SIT UP','LUNGES','ROW','RUN'];
  for (var r = 1; r < rows; r++) {
    w.cells[r][0].text = names[(r - 1) % names.length];
    w.cells[r][0].bold = true;
    for (var c = 1; c < cols; c++) { w.cells[r][c] = Cell(text: '${25 - c * 2}', centered: true); }
  }
  for (var c = 1; c < cols; c++) { w.cells[0][c] = Cell(text: 'R$c', bold: true, centered: true); }
  w.totalReps = '720'; w.difficulty = 'HARD'; w.subtitle = '5 ROUNDS • FOR TIME';
  w.notes = 'Rest 60 seconds between rounds. Complete every exercise before starting the next round.';
  w.groups = [CellRange(1, 0, rows - 1, cols - 1)];
  return w;
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Real raster output is exactly 1080x1920 for short and dense workouts', () async {
    for (final dense in [false, true]) {
      final poster = await PosterRenderer().render(sample(dense: dense), AppSettings());
      final codec = await ui.instantiateImageCodec(poster.png);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1080); expect(frame.image.height, 1920);
      expect(poster.png.length, greaterThan(1000));
      final dir = Directory('build/qa')..createSync(recursive: true);
      File('${dir.path}/${dense ? 'dense' : 'short'}.png').writeAsBytesSync(poster.png);
      frame.image.dispose(); codec.dispose();
    }
  });
  test('Empty workout and excessive notes fail with actionable errors', () async {
    await expectLater(PosterRenderer().render(Workout.empty(), AppSettings()), throwsStateError);
    final w = sample(); w.notes = List.filled(1200, 'complete').join(' ');
    await expectLater(PosterRenderer().render(w, AppSettings()), throwsStateError);
  });
  test('Optional fields can all be empty; merge and groups render', () async {
    final w = sample(); w.totalReps = ''; w.difficulty = ''; w.notes = ''; w.subtitle = '';
    w.merges = [const CellRange(0, 0, 0, 4)]; w.cells[0][0].text = 'CIRCUIT A';
    final result = await PosterRenderer().render(w, AppSettings()); expect(result.png, isNotEmpty);
  });
}
