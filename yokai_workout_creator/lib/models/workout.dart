import 'dart:convert';
import 'dart:math' as math;

class Cell {
  String text;
  bool bold;
  bool centered;
  int border; // 0 none, 1 normal, 2 thick
  int? foreground;
  int? background;
  Cell({this.text = '', this.bold = false, this.centered = false,
    this.border = 0, this.foreground, this.background});
  Map<String, dynamic> toJson() => {'text': text, 'bold': bold,
    'centered': centered, 'border': border, 'fg': foreground, 'bg': background};
  factory Cell.fromJson(Map<String, dynamic> j) => Cell(
    text: j['text'] as String? ?? '', bold: j['bold'] == true,
    centered: j['centered'] == true, border: (j['border'] as int? ?? 0).clamp(0, 2).toInt(),
    foreground: j['fg'] as int?, background: j['bg'] as int?);
  Cell copy() => Cell.fromJson(toJson());
  bool get visible => text.trim().isNotEmpty || border > 0 || background != null;
}

class CellRange {
  final int top, left, bottom, right;
  const CellRange(this.top, this.left, this.bottom, this.right);
  factory CellRange.between(int r1, int c1, int r2, int c2) => CellRange(
    math.min(r1, r2), math.min(c1, c2), math.max(r1, r2), math.max(c1, c2));
  int get rows => bottom - top + 1;
  int get cols => right - left + 1;
  bool contains(int r, int c) => r >= top && r <= bottom && c >= left && c <= right;
  bool covers(CellRange r) => contains(r.top, r.left) && contains(r.bottom, r.right);
  bool overlaps(CellRange r) => left <= r.right && right >= r.left &&
    top <= r.bottom && bottom >= r.top;
  CellRange union(CellRange r) => CellRange(math.min(top, r.top), math.min(left, r.left),
    math.max(bottom, r.bottom), math.max(right, r.right));
  CellRange shifted(int r, int c) => CellRange(top + r, left + c, bottom + r, right + c);
  List<int> toJson() => [top, left, bottom, right];
  factory CellRange.fromJson(List<dynamic> j) => CellRange(j[0] as int,
    j[1] as int, j[2] as int, j[3] as int);
  @override
  bool operator ==(Object other) => other is CellRange && top == other.top &&
    left == other.left && bottom == other.bottom && right == other.right;
  @override
  int get hashCode => Object.hash(top, left, bottom, right);
  String get label => '${String.fromCharCode(65 + left)}${top + 1} : '
    '${String.fromCharCode(65 + right)}${bottom + 1}';
}

class Workout {
  final String id;
  String title, date, subtitle, totalReps, difficulty, notes;
  List<List<Cell>> cells;
  List<double> widths, heights;
  List<CellRange> groups, merges;
  String modified;
  int get rows => cells.length;
  int get cols => cells.first.length;
  Workout({required this.id, required this.title, required this.date,
    this.subtitle = '', this.totalReps = '', this.difficulty = '', this.notes = '',
    required this.cells, required this.widths, required this.heights,
    List<CellRange>? groups, List<CellRange>? merges, String? modified})
      : groups = groups ?? [], merges = merges ?? [],
        modified = modified ?? DateTime.now().toIso8601String();
  static String today() => DateTime.now().toIso8601String().substring(0, 10);
  static String newId() => '${DateTime.now().microsecondsSinceEpoch}-'
    '${math.Random.secure().nextInt(1 << 30)}';
  factory Workout.empty() => Workout(id: newId(), title: 'YOKAI FITNESS', date: today(),
    cells: List.generate(15, (_) => List.generate(10, (_) => Cell())),
    widths: List.generate(10, (i) => i == 0 ? 220.0 : 100.0),
    heights: List.filled(15, 58.0, growable: true));
  factory Workout.template(String name) {
    final w = Workout.empty();
    if (name == 'EMPTY') return w;
    w.cells[0][0] = Cell(text: 'EXERCISE', bold: true);
    w.cells[0][1] = Cell(text: 'REPS', bold: true, centered: true);
    if (name == 'ROUNDS') {
      for (var c = 1; c <= 4; c++) {
        w.cells[0][c] = Cell(text: 'ROUND $c', bold: true, centered: true);
      }
    } else if (name == 'A / B / C') {
      w.cells[0][0].text = '';
      w.cells[0][1].text = '';
      for (var g = 0; g < 3; g++) {
        final r = g * 5;
        w.cells[r][0] = Cell(text: 'CIRCUIT ${String.fromCharCode(65 + g)}', bold: true, centered: true);
        w.merges.add(CellRange(r, 0, r, 1));
        w.groups.add(CellRange(r, 0, r + 3, 1));
      }
    } else if (name == 'AMRAP') {
      w.subtitle = "AMRAP 20'";
    } else if (name == 'FOR TIME') {
      w.subtitle = 'FOR TIME';
    }
    return w;
  }
  CellRange? mergeAt(int r, int c) {
    for (final m in merges) { if (m.contains(r, c)) return m; }
    return null;
  }
  bool hidden(int r, int c) {
    final m = mergeAt(r, c);
    return m != null && (m.top != r || m.left != c);
  }
  CellRange expandSelection(CellRange s) {
    var next = s;
    bool changed;
    do {
      changed = false;
      for (final m in merges) {
        if (m.overlaps(next) && !next.covers(m)) { next = next.union(m); changed = true; }
      }
    } while (changed);
    return next;
  }
  CellRange get usedRange {
    var r = 0, c = 0;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        if (cells[y][x].visible && !hidden(y, x)) { r = math.max(r, y); c = math.max(c, x); }
      }
    }
    for (final area in [...groups, ...merges]) {
      r = math.max(r, area.bottom); c = math.max(c, area.right);
    }
    return CellRange(0, 0, r, c);
  }
  bool get hasContent => cells.any((row) => row.any((cell) => cell.text.trim().isNotEmpty));
  Map<String, dynamic> toJson() => {'version': 1, 'id': id, 'title': title, 'date': date,
    'subtitle': subtitle, 'totalReps': totalReps, 'difficulty': difficulty, 'notes': notes,
    'cells': cells.map((row) => row.map((c) => c.toJson()).toList()).toList(),
    'widths': widths, 'heights': heights, 'groups': groups.map((r) => r.toJson()).toList(),
    'merges': merges.map((r) => r.toJson()).toList(), 'modified': modified};
  String encode() => jsonEncode(toJson());
  factory Workout.decode(String source) => Workout.fromJson(jsonDecode(source) as Map<String, dynamic>);
  factory Workout.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) throw const FormatException('Versione workout non supportata');
    final w = Workout(id: j['id'] as String, title: j['title'] as String,
      date: j['date'] as String, subtitle: j['subtitle'] as String? ?? '',
      totalReps: j['totalReps'] as String? ?? '', difficulty: j['difficulty'] as String? ?? '',
      notes: j['notes'] as String? ?? '',
      cells: (j['cells'] as List).map((row) => (row as List).map((c) =>
        Cell.fromJson(Map<String, dynamic>.from(c as Map))).toList()).toList(),
      widths: (j['widths'] as List).map((n) => (n as num).toDouble()).toList(),
      heights: (j['heights'] as List).map((n) => (n as num).toDouble()).toList(),
      groups: (j['groups'] as List? ?? []).map((r) => CellRange.fromJson(r as List)).toList(),
      merges: (j['merges'] as List? ?? []).map((r) => CellRange.fromJson(r as List)).toList(),
      modified: j['modified'] as String?);
    if (w.rows < 1 || w.rows > 20 || w.cols < 1 || w.cols > 12 ||
      w.cells.any((r) => r.length != w.cols) || w.widths.length != w.cols ||
      w.heights.length != w.rows ||
      w.widths.any((n) => !n.isFinite || n < 48 || n > 420) ||
      w.heights.any((n) => !n.isFinite || n < 36 || n > 180) ||
      !RegExp(r'^\d+-\d+$').hasMatch(w.id) || DateTime.tryParse(w.date) == null) {
      throw const FormatException('Workout danneggiato: struttura non valida');
    }
    for (final area in [...w.groups, ...w.merges]) {
      if (area.top < 0 || area.left < 0 || area.bottom >= w.rows || area.right >= w.cols ||
        area.rows < 1 || area.cols < 1) throw const FormatException('Intervallo non valido');
    }
    for (var i = 0; i < w.merges.length; i++) {
      for (var j = i + 1; j < w.merges.length; j++) {
        if (w.merges[i].overlaps(w.merges[j])) throw const FormatException('Merge sovrapposti');
      }
    }
    return w;
  }
  Workout copy() => Workout.decode(encode());
  Workout duplicate() {
    final json = toJson();
    json['id'] = newId(); json['date'] = today();
    json['modified'] = DateTime.now().toIso8601String();
    return Workout.fromJson(json);
  }
}

class AppSettings {
  int accent, background, foreground;
  String format;
  String? logoBase64;
  AppSettings({this.accent = 0xFFE63840, this.background = 0xFF101114,
    this.foreground = 0xFFF7F7F8, this.format = 'png', this.logoBase64});
  Map<String, dynamic> toJson() => {'accent': accent, 'background': background,
    'foreground': foreground, 'format': format, 'logo': logoBase64};
  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    accent: j['accent'] as int? ?? 0xFFE63840,
    background: j['background'] as int? ?? 0xFF101114,
    foreground: j['foreground'] as int? ?? 0xFFF7F7F8,
    format: j['format'] == 'jpg' ? 'jpg' : 'png', logoBase64: j['logo'] as String?);
}
