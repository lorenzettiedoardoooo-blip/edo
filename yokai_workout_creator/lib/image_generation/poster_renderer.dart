import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/workout.dart';

class PosterResult {
  final Uint8List png;
  final List<String> warnings;
  PosterResult(this.png, this.warnings);
}

class PosterRenderer {
  static const width = 1080, height = 1920;
  static TextPainter text(String value, double size, Color color,
      {bool bold = false, TextAlign align = TextAlign.left, double spacing = 0}) => TextPainter(
    text: TextSpan(text: value, style: TextStyle(fontFamily: 'sans-serif', fontSize: size,
      color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      height: 1.18, letterSpacing: spacing)),
    textDirection: TextDirection.ltr, textAlign: align);

  Future<PosterResult> render(Workout w, AppSettings settings) async {
    if (!w.hasContent) throw StateError('Inserisci almeno un esercizio o un testo nella griglia.');
    final warnings = <String>[];
    ui.Image? logo;
    if (settings.logoBase64 != null) {
      final codec = await ui.instantiateImageCodec(base64Decode(settings.logoBase64!),
        targetWidth: 600);
      logo = (await codec.getNextFrame()).image; codec.dispose();
    }
    final recorder = ui.PictureRecorder();
    try {
    final canvas = Canvas(recorder);
    final bg = Color(settings.background), fg = Color(settings.foreground), accent = Color(settings.accent);
    final muted = Color.lerp(fg, bg, .38)!;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..color = bg);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..shader =
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Colors.white.withValues(alpha: .045), Colors.transparent, accent.withValues(alpha: .045)])
        .createShader(const Rect.fromLTWH(0, 0, 1080, 1920)));
    canvas.drawRect(const Rect.fromLTWH(68, 0, 118, 9), Paint()..color = accent);
    canvas.drawLine(const Offset(68, 175), const Offset(1012, 175), Paint()..color = fg.withValues(alpha: .16)..strokeWidth = 1);
    void label(String value, double x, double y, double maxWidth, double font,
        {Color? color, bool bold = false}) {
      final p = text(value, font, color ?? fg, bold: bold)..layout(maxWidth: maxWidth);
      p.paint(canvas, Offset(x, y)); p.dispose();
    }
    if (logo != null) {
      final source = Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble());
      final fitted = applyBoxFit(BoxFit.contain, source.size, const Size(310, 100));
      final dest = Alignment.centerLeft.inscribe(fitted.destination, const Rect.fromLTWH(68, 54, 310, 100));
      canvas.drawImageRect(logo, source, dest, Paint()..filterQuality = FilterQuality.high);
    } else {
      label('YOKAI', 68, 61, 520, 70, bold: true);
    }
    label('DAILY\nWORKOUT', 793, 79, 220, 23, bold: true, color: muted);
    var y = 211.0;
    var titleSize = 78.0;
    TextPainter title;
    while (true) {
      title = text(w.title.trim().isEmpty ? 'YOKAI WORKOUT' : w.title.trim(), titleSize, fg, bold: true)
        ..layout(maxWidth: 944);
      if (title.height <= 194 || titleSize <= 28) break;
      title.dispose(); titleSize -= 2;
    }
    if (title.height > 194) {
      title.dispose(); recorder.endRecording().dispose();
      throw StateError('Il titolo è troppo lungo: accorcialo per mantenere la grafica leggibile.');
    }
    title.paint(canvas, Offset(68, y)); y += title.height + 24; title.dispose();
    final d = DateTime.parse(w.date);
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    label('${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}', 68, y, 944, 24, color: muted, bold: true);
    y += 42;
    if (w.subtitle.trim().isNotEmpty) {
      final sub = text(w.subtitle.trim(), 31, accent, bold: true)..layout(maxWidth: 944);
      if (sub.height > 150) {
        sub.dispose(); recorder.endRecording().dispose();
        throw StateError('Il sottotitolo è troppo lungo: usa NOTES per la spiegazione.');
      }
      sub.paint(canvas, Offset(68, y)); y += sub.height + 22; sub.dispose();
    }
    y += 20;
    TextPainter? notes;
    if (w.notes.trim().isNotEmpty) {
      for (var size = 27.0; size >= 20; size -= 1) {
        notes?.dispose();
        notes = text(w.notes.trim(), size, muted)..layout(maxWidth: 900);
        if (notes.height <= 380) break;
      }
      if (notes!.height > 380) {
        notes.dispose(); recorder.endRecording().dispose();
        throw StateError('Le note sono troppo lunghe per una storia 9:16. Riduci il testo.');
      }
    }
    final hasStats = w.totalReps.trim().isNotEmpty || w.difficulty.trim().isNotEmpty;
    final footerSpace = (hasStats ? 164.0 : 0.0) + (notes != null ? notes.height + 98 : 0.0);
    final available = 1802.0 - y - footerSpace;
    final used = w.usedRange;
    final columns = used.cols, rows = used.rows;
    final totalWeight = w.widths.take(columns).reduce((a, b) => a + b);
    final widths = w.widths.take(columns).map((n) => 944 * n / totalWeight).toList();
    final xs = <double>[68];
    for (final n in widths) { xs.add(xs.last + n); }
    var rowHeights = <double>[];
    var font = 42.0;
    bool fits = false;
    for (; font >= 18; font -= 1) {
      rowHeights = w.heights.take(rows).map((h) => math.max(45.0, h * .9)).toList();
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < columns; c++) {
          if (w.hidden(r, c)) continue;
          final area = w.mergeAt(r, c) ?? CellRange(r, c, r, c);
          final cell = w.cells[r][c];
          if (cell.text.isEmpty) continue;
          final p = text(cell.text, font, fg, bold: cell.bold,
            align: cell.centered || w.mergeAt(r, c) != null ? TextAlign.center : TextAlign.left)
            ..layout(maxWidth: math.max(1.0, xs[area.right + 1] - xs[c] - 22));
          final needed = p.height + 30; p.dispose();
          final current = rowHeights.sublist(r, area.bottom + 1).reduce((a, b) => a + b);
          if (needed > current) {
            for (var k = r; k <= area.bottom; k++) { rowHeights[k] += (needed - current) / area.rows; }
          }
        }
      }
      if (rowHeights.reduce((a, b) => a + b) <= available) { fits = true; break; }
    }
    if (!fits || available < 100) {
      notes?.dispose(); recorder.endRecording().dispose();
      throw StateError('Troppo contenuto per 1080×1920 leggibile. Riduci testo/colonne o dividi il workout.');
    }
    if (font < 24 || columns > 8) {
      warnings.add('Tabella molto densa: controlla la leggibilità sul telefono prima di pubblicare.');
    }
    final natural = rowHeights.reduce((a, b) => a + b);
    final target = math.min(available, math.max(natural, rows <= 6 ? 670.0 : 900.0));
    for (var r = 0; r < rows; r++) { rowHeights[r] += (target - natural) / rows; }
    // Short workouts use breathing room above and below, without blank grid cells.
    final breathing = math.max(0.0, available - target);
    y += breathing * .35;
    final ys = <double>[y];
    for (final h in rowHeights) { ys.add(ys.last + h); }
    final tableRect = Rect.fromLTRB(68, y, 1012, ys.last);
    canvas.drawRRect(RRect.fromRectAndRadius(tableRect, const Radius.circular(14)),
      Paint()..color = fg.withValues(alpha: .025));
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        if (w.hidden(r, c)) continue;
        final cell = w.cells[r][c];
        final merged = w.mergeAt(r, c);
        final area = merged ?? CellRange(r, c, r, c);
        final rect = Rect.fromLTRB(xs[c], ys[r], xs[area.right + 1], ys[area.bottom + 1]);
        if (cell.background != null) {
          canvas.drawRect(rect, Paint()..color = Color(cell.background!));
        } else if (r.isOdd) {
          canvas.drawRect(rect, Paint()..color = fg.withValues(alpha: .028));
        }
        if (cell.border > 0) {
          canvas.drawRect(rect.deflate(cell.border == 2 ? 2 : .5), Paint()
            ..color = cell.border == 2 ? accent : fg.withValues(alpha: .38)
            ..style = PaintingStyle.stroke..strokeWidth = cell.border == 2 ? 4 : 1);
        }
        final p = text(cell.text, font, cell.foreground == null ? fg : Color(cell.foreground!),
          bold: cell.bold, align: cell.centered || merged != null ? TextAlign.center : TextAlign.left)
          ..layout(minWidth: math.max(1.0, rect.width - 22), maxWidth: math.max(1.0, rect.width - 22));
        p.paint(canvas, Offset(rect.left + 11, rect.top + (rect.height - p.height) / 2)); p.dispose();
      }
    }
    for (final g in w.groups) {
      canvas.drawRect(Rect.fromLTRB(xs[g.left], ys[g.top], xs[g.right + 1], ys[g.bottom + 1]).deflate(2),
        Paint()..color = accent..style = PaintingStyle.stroke..strokeWidth = 4);
    }
    y = ys.last + 30 + breathing * .4;
    if (hasStats) {
      final stats = Rect.fromLTWH(68, y, 944, 130);
      canvas.drawLine(Offset(68, y), Offset(1012, y), Paint()..color = fg.withValues(alpha: .2)..strokeWidth = 1);
      if (w.totalReps.trim().isNotEmpty) {
        label('TOTAL REPS', 68, y + 22, 360, 20, color: muted, bold: true);
        final value = _fit(w.totalReps.trim(), Rect.fromLTWH(68, y + 50, w.difficulty.trim().isEmpty ? 944 : 480, 78),
          70, 18, accent, true, TextAlign.left);
        value.paint(canvas, Offset(68, y + 50)); value.dispose();
      }
      if (w.difficulty.trim().isNotEmpty) {
        final left = w.totalReps.trim().isEmpty ? 68.0 : 588.0;
        final badge = Rect.fromLTWH(left, stats.top + 30, 1012 - left, 84);
        canvas.drawRRect(RRect.fromRectAndRadius(badge, const Radius.circular(12)),
          Paint()..color = accent.withValues(alpha: .12));
        final value = _fit('DIFFICULTY • ${w.difficulty.trim()}', badge.deflate(15), 27, 18, fg, true, TextAlign.center);
        value.paint(canvas, Offset(left + 15, badge.top + (badge.height - value.height) / 2)); value.dispose();
      }
      y += 164;
    }
    if (notes != null) {
      canvas.drawRect(Rect.fromLTWH(68, y + 3, 4, notes.height + 53), Paint()..color = accent);
      label('NOTES', 90, y, 900, 20, color: accent, bold: true);
      notes.paint(canvas, Offset(90, y + 38)); notes.dispose();
    }
    label('YOKAI  /  TRAIN WITH INTENT', 68, 1849, 850, 17, color: muted, bold: true);
    canvas.drawRect(const Rect.fromLTWH(938, 1853, 74, 5), Paint()..color = accent);
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(width, height);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Rendering immagine non riuscito');
      return PosterResult(bytes.buffer.asUint8List(), warnings);
    } finally { image?.dispose(); picture.dispose(); }
    } finally {
      if (recorder.isRecording) recorder.endRecording().dispose();
      logo?.dispose();
    }
  }
  TextPainter _fit(String content, Rect bounds, double start, double minimum, Color color,
      bool bold, TextAlign align) {
    var font = start;
    while (true) {
      final p = text(content, font, color, bold: bold, align: align)..layout(minWidth: bounds.width, maxWidth: bounds.width);
      if (p.height <= bounds.height) return p;
      p.dispose(); font -= 1;
      if (font < minimum) throw StateError('TOTAL REPS o DIFFICULTY troppo lungo: accorcia il testo.');
    }
  }
}
