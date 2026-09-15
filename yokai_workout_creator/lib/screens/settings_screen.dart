import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../storage/workout_store.dart';

class SettingsScreen extends StatefulWidget {
  final WorkoutStore store;
  const SettingsScreen({super.key, required this.store});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  bool busy = false;
  AppSettings get settings => widget.store.settings;
  Future<void> update(void Function(AppSettings) edit) async {
    setState(() { busy = true; });
    try {
      final next = AppSettings.fromJson(settings.toJson()); edit(next);
      await widget.store.saveSettings(next); await widget.store.flush();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Salvataggio non riuscito: $e')));
    } finally { if (mounted) setState(() { busy = false; }); }
  }
  Future<void> logo() async {
    setState(() { busy = true; });
    try {
      final bytes = await widget.store.platform.pickLogo();
      if (bytes == null) return;
      await widget.store.saveSettings(AppSettings.fromJson(settings.toJson())..logoBase64 = base64Encode(bytes));
      await widget.store.flush();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Caricamento logo non riuscito: $e')));
    } finally { if (mounted) setState(() { busy = false; }); }
  }
  Widget palette(String title, List<int> values, int selected, void Function(AppSettings, int) change) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title), const SizedBox(height: 10),
      Wrap(spacing: 12, children: values.map((v) => Semantics(label: '$title ${v.toRadixString(16)}',
        selected: v == selected, button: true, child: InkWell(onTap: busy ? null : () => update((s) => change(s, v)),
          child: Container(width: 48, height: 48, decoration: BoxDecoration(color: Color(v),
            borderRadius: BorderRadius.circular(12), border: Border.all(color: v == selected ? Colors.white : Colors.white24, width: 2)),
            child: v == selected ? Icon(Icons.check, color: Color(v).computeLuminance() > .5 ? Colors.black : Colors.white) : null)))).toList()),
      const SizedBox(height: 24)]);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('SETTINGS')),
    body: ListView(padding: const EdgeInsets.all(22), children: [
      const Text('YOKAI LOGO', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      Container(height: 150, padding: const EdgeInsets.all(20), color: const Color(0xFF17191F),
        child: settings.logoBase64 == null ? const Center(child: Text('YOKAI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 48))) :
          Image.memory(base64Decode(settings.logoBase64!), fit: BoxFit.contain)),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: busy ? null : logo, icon: const Icon(Icons.upload_file), label: const Text('CARICA LOGO')),
      const Text('PNG trasparente consigliato. Il logo viene copiato sul telefono e ricordato.', style: TextStyle(color: Colors.white60)),
      if (settings.logoBase64 != null) TextButton(onPressed: busy ? null : () => update((s) => s.logoBase64 = null), child: const Text('RIMUOVI LOGO')),
      const SizedBox(height: 28),
      palette('ACCENT', [0xFFE63840,0xFFEB8E3E,0xFFB8D962,0xFF67B9EB,0xFFD7D8DC], settings.accent, (s, v) => s.accent = v),
      palette('BACKGROUND', [0xFF101114,0xFF000000,0xFF20232B], settings.background, (s, v) => s.background = v),
      palette('TEXT', [0xFFF7F7F8,0xFFD2D5DB,0xFFFFF5E8], settings.foreground, (s, v) => s.foreground = v),
      DropdownButtonFormField<String>(initialValue: settings.format, decoration: const InputDecoration(labelText: 'IMAGE FORMAT'),
        items: const [DropdownMenuItem(value: 'png', child: Text('PNG · senza perdita')),
          DropdownMenuItem(value: 'jpg', child: Text('JPG · qualità 95%'))],
        onChanged: busy ? null : (v) { if (v != null) update((s) => s.format = v); }),
      const SizedBox(height: 22),
      const Text('1080 × 1920 PX  /  QUALITÀ ALTA', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      const Text('La generazione apre solo l’anteprima. La galleria viene modificata esclusivamente con SAVE IMAGE.'),
      if (busy) const LinearProgressIndicator(),
      if (widget.store.saveError != null) TextButton(onPressed: busy ? null : () => update((_) {}), child: const Text('RIPROVA SALVATAGGIO')),
    ]));
}
