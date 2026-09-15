import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yokai_workout_creator/main.dart';
import 'package:yokai_workout_creator/models/workout.dart';
import 'package:yokai_workout_creator/services/platform_bridge.dart';
import 'package:yokai_workout_creator/storage/workout_store.dart';
import 'package:yokai_workout_creator/image_generation/poster_renderer.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android native storage, image encoding, gallery and editor', (tester) async {
    final bridge = PlatformBridge();
    final store = WorkoutStore(bridge);
    await store.load();
    final w = Workout.template('ROUNDS');
    w.title = 'FULL BODY'; w.subtitle = '4 ROUNDS • FOR TIME';
    w.totalReps = '720'; w.difficulty = 'HARD';
    w.notes = 'Rest 60 seconds between rounds.';
    const names = ['SQUAT', 'PUSH UP', 'BURPEE', 'SIT UP'];
    for (var r = 1; r <= 4; r++) {
      w.cells[r][0] = Cell(text: names[r - 1], bold: true);
      for (var c = 1; c <= 4; c++) { w.cells[r][c] = Cell(text: '${30 - c * 5}', centered: true); }
    }
    w.groups.add(const CellRange(1, 0, 4, 4));
    store.save(w); await store.flush();
    final reload = WorkoutStore(bridge); await reload.load();
    expect(reload.workouts.singleWhere((a) => a.id == w.id).cells[1][0].text, 'SQUAT');
    final poster = await PosterRenderer().render(w, store.settings);
    final codec = await ui.instantiateImageCodec(poster.png);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 1080); expect(frame.image.height, 1920);
    frame.image.dispose(); codec.dispose();
    expect(await bridge.saveImage(poster.png, 'YOKAI_104.png', 'png'), true);
    final jpg = await bridge.encodeImage(poster.png, 'jpg');
    expect(jpg.take(2).toList(), [255, 216]);
    expect(await bridge.saveImage(jpg, 'YOKAI_105.jpg', 'jpg'), true);
    await tester.pumpWidget(const YokaiApp()); await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage(); await tester.pumpAndSettle();
    final home = await binding.takeScreenshot('home');
    await bridge.saveImage(Uint8List.fromList(home), 'YOKAI_101.png', 'png');
    await tester.tap(find.text('NEW WORKOUT')); await tester.pumpAndSettle();
    await tester.tap(find.text('EMPTY')); await tester.pumpAndSettle();
    final input = find.byWidgetPredicate((widget) => widget is TextField &&
      (widget.decoration?.labelText ?? '').startsWith('CELLA'));
    await tester.enterText(input, 'SQUAT');
    FocusManager.instance.primaryFocus?.unfocus(); await tester.pumpAndSettle();
    await tester.tap(find.text('GROUP')); await tester.pumpAndSettle();
    final editor = await binding.takeScreenshot('editor');
    await bridge.saveImage(Uint8List.fromList(editor), 'YOKAI_102.png', 'png');
    await tester.tap(find.text('GENERATE IMAGE')); await tester.pumpAndSettle();
    expect(find.text('PREVIEW'), findsOneWidget);
    final preview = await binding.takeScreenshot('preview');
    await bridge.saveImage(Uint8List.fromList(preview), 'YOKAI_103.png', 'png');
    await tester.tap(find.text('SAVE IMAGE')); await tester.pumpAndSettle();
    expect(find.text('1080 × 1920  •  Salvata in galleria'), findsOneWidget);
    final finalStore = WorkoutStore(bridge); await finalStore.load();
    expect(finalStore.workouts.any((a) => a.cells[0][0].text == 'SQUAT'), true);
    expect(tester.takeException(), isNull);
  });
}
