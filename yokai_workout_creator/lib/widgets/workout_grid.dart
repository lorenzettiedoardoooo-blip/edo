import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/editor_controller.dart';
import '../image_generation/poster_renderer.dart';
import '../theme/yokai_theme.dart';

class WorkoutGrid extends StatefulWidget {
  final EditorController editor;
  final VoidCallback onEdit;
  const WorkoutGrid({super.key, required this.editor, required this.onEdit});
  @override
  State<WorkoutGrid> createState() => WorkoutGridState();
}
class WorkoutGridState extends State<WorkoutGrid> {
  final transform = TransformationController();
  Size viewport = Size.zero;
  @override
  void dispose() { transform.dispose(); super.dispose(); }
  void revealSelection() {
    final w = widget.editor.workout, s = widget.editor.selection;
    final scale = transform.value.getMaxScaleOnAxis();
    final x = 42 + w.widths.take(s.left).fold<double>(0, (a, b) => a + b);
    final y = 34 + w.heights.take(s.top).fold<double>(0, (a, b) => a + b);
    final oldX = transform.value.entry(0, 3), oldY = transform.value.entry(1, 3);
    var tx = oldX, ty = oldY;
    final right = (x + w.widths[s.left]) * scale + tx;
    final bottom = (y + w.heights[s.top]) * scale + ty;
    if (right > viewport.width) tx -= right - viewport.width + 12;
    if (x * scale + tx < 0) tx = -x * scale + 12;
    if (bottom > viewport.height) ty -= bottom - viewport.height + 12;
    if (y * scale + ty < 0) ty = -y * scale + 12;
    transform.value = Matrix4.identity()..setEntry(0, 0, scale)..setEntry(1, 1, scale)
      ..setEntry(0, 3, tx)..setEntry(1, 3, ty);
  }
  void zoom(double factor) {
    final old = transform.value.getMaxScaleOnAxis();
    final next = (old * factor).clamp(.35, 2.5).toDouble();
    transform.value = Matrix4.identity()..setEntry(0, 0, next)..setEntry(1, 1, next)
      ..setEntry(0, 3, transform.value.entry(0, 3) * next / old)
      ..setEntry(1, 3, transform.value.entry(1, 3) * next / old);
    revealSelection();
  }
  (int, int) hit(Offset p) {
    final w = widget.editor.workout;
    var c = -1, r = -1, x = 42.0, y = 34.0;
    for (var i = 0; i < w.cols; i++) { if (p.dx >= x) c = i; x += w.widths[i]; }
    for (var i = 0; i < w.rows; i++) { if (p.dy >= y) r = i; y += w.heights[i]; }
    return (r, c);
  }
  void tap(Offset p, {bool long = false, bool drag = false}) {
    final (r, c) = hit(p);
    final e = widget.editor, w = e.workout;
    if (r < 0 && c < 0) { e.setRange(CellRange(0, 0, w.rows - 1, w.cols - 1)); return; }
    if (r < 0) { e.setRange(CellRange(0, c, w.rows - 1, c)); return; }
    if (c < 0) { e.setRange(CellRange(r, 0, r, w.cols - 1)); return; }
    if (long) { e.select(r, c); e.setSelecting(true); FocusScope.of(context).unfocus(); }
    else if (drag || e.selecting) { e.select(r, c, extend: true); }
    else { e.select(r, c); widget.onEdit(); }
  }
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    viewport = box.biggest;
    final w = widget.editor.workout;
    final size = Size(42 + w.widths.fold<double>(0, (a, b) => a + b),
      34 + w.heights.fold<double>(0, (a, b) => a + b));
    return ClipRect(child: InteractiveViewer(
      transformationController: transform, constrained: false,
      minScale: .35, maxScale: 2.5, boundaryMargin: const EdgeInsets.all(80),
      child: GestureDetector(behavior: HitTestBehavior.opaque,
        onTapUp: (d) => tap(d.localPosition),
        onLongPressStart: (d) => tap(d.localPosition, long: true),
        onLongPressMoveUpdate: (d) => tap(d.localPosition, drag: true),
        child: CustomPaint(size: size, painter: _GridPainter(w, widget.editor.selection)))));
  });
}
class _GridPainter extends CustomPainter {
  final Workout w;
  final CellRange selection;
  _GridPainter(this.w, this.selection);
  @override
  void paint(Canvas canvas, Size size) {
    final xs = <double>[42], ys = <double>[34];
    for (final n in w.widths) { xs.add(xs.last + n); }
    for (final n in w.heights) { ys.add(ys.last + n); }
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF111318));
    void heading(String t, Rect rect) {
      canvas.drawRect(rect, Paint()..color = const Color(0xFF252830));
      final p = PosterRenderer.text(t, 11, const Color(0xFFAEB3C1), bold: true, align: TextAlign.center)
        ..layout(minWidth: rect.width, maxWidth: rect.width);
      p.paint(canvas, Offset(rect.left, rect.top + (rect.height - p.height) / 2)); p.dispose();
    }
    heading('ALL', const Rect.fromLTWH(0, 0, 42, 34));
    for (var c = 0; c < w.cols; c++) { heading(String.fromCharCode(65 + c), Rect.fromLTWH(xs[c], 0, w.widths[c], 34)); }
    for (var r = 0; r < w.rows; r++) {
      heading('${r + 1}', Rect.fromLTWH(0, ys[r], 42, w.heights[r]));
      for (var c = 0; c < w.cols; c++) {
        if (w.hidden(r, c)) continue;
        final cell = w.cells[r][c], m = w.mergeAt(r, c);
        final area = m ?? CellRange(r, c, r, c);
        final rect = Rect.fromLTRB(xs[c], ys[r], xs[area.right + 1], ys[area.bottom + 1]);
        if (cell.background != null) canvas.drawRect(rect, Paint()..color = Color(cell.background!));
        if (selection.overlaps(area)) canvas.drawRect(rect, Paint()..color = YokaiTheme.red.withValues(alpha: .17));
        canvas.drawRect(rect, Paint()..style = PaintingStyle.stroke..strokeWidth = cell.border == 2 ? 3 : 1
          ..color = cell.border == 2 ? Colors.white70 : cell.border == 1 ? Colors.white38 : Colors.white10);
        var font = 16.0;
        TextPainter p;
        while (true) {
          p = PosterRenderer.text(cell.text, font, cell.foreground == null ? Colors.white : Color(cell.foreground!),
            bold: cell.bold, align: cell.centered || m != null ? TextAlign.center : TextAlign.left)
            ..layout(minWidth: math.max(1.0, rect.width - 14), maxWidth: math.max(1.0, rect.width - 14));
          if (p.height <= rect.height - 10 || font <= 6) break;
          p.dispose(); font -= 1;
        }
        canvas.save(); canvas.clipRect(rect.deflate(3));
        p.paint(canvas, Offset(rect.left + 7, rect.top + math.max(3.0, (rect.height - p.height) / 2)));
        canvas.restore(); p.dispose();
      }
    }
    for (final g in w.groups) {
      canvas.drawRect(Rect.fromLTRB(xs[g.left], ys[g.top], xs[g.right + 1], ys[g.bottom + 1]).deflate(1.5),
        Paint()..color = YokaiTheme.red..style = PaintingStyle.stroke..strokeWidth = 3);
    }
    canvas.drawRect(Rect.fromLTRB(xs[selection.left], ys[selection.top], xs[selection.right + 1], ys[selection.bottom + 1]),
      Paint()..color = const Color(0xFFFF747B)..style = PaintingStyle.stroke..strokeWidth = 2);
  }
  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => true;
}
