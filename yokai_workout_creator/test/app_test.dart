import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yokai_workout_creator/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Home to real editor, typing, grouping, autosave, history', (tester) async {
    final documents = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('it.yokai.workout/platform'), (call) async {
        switch (call.method) {
          case 'readWorkouts': return documents.values.toList();
          case 'readSettings': return null;
          case 'writeWorkout': documents[call.arguments['id'] as String] = call.arguments['json'] as String; return null;
          default: return null;
        }
      });
    await tester.pumpWidget(const YokaiApp()); await tester.pumpAndSettle();
    await tester.tap(find.text('NEW WORKOUT')); await tester.pumpAndSettle();
    await tester.tap(find.text('EMPTY')); await tester.pumpAndSettle();
    expect(find.text('GENERATE IMAGE'), findsOneWidget);
    final input = find.byWidgetPredicate((widget) => widget is TextField && (widget.decoration?.labelText ?? '').startsWith('CELLA'));
    await tester.enterText(input, 'SQUAT'); await tester.pumpAndSettle();
    expect(documents.values.single, contains('SQUAT'));
    await tester.tap(find.text('GROUP')); await tester.pumpAndSettle();
    expect(documents.values.single, contains('"groups":[[0,0,0,0]]'));
    // Exit commits queued edits before returning to Home.
    FocusManager.instance.primaryFocus?.unfocus(); await tester.pumpAndSettle();
    await tester.pageBack(); await tester.pumpAndSettle();
    expect(find.text('NEW WORKOUT'), findsOneWidget);
    expect(documents, hasLength(1));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('it.yokai.workout/platform'), null);
  });
}
