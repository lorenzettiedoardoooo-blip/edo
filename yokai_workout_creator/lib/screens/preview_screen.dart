import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/platform_bridge.dart';

class PreviewScreen extends StatefulWidget {
  final Uint8List bytes;
  final String format;
  final List<String> warnings;
  final PlatformBridge platform;
  const PreviewScreen({super.key, required this.bytes, required this.format,
    required this.warnings, required this.platform});
  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}
class _PreviewScreenState extends State<PreviewScreen> {
  bool busy = false, savedToGallery = false;
  String get filename => 'YOKAI_${DateTime.now().millisecondsSinceEpoch}.${widget.format}';
  Future<void> run(bool save) async {
    setState(() { busy = true; });
    try {
      if (save) {
        final saved = await widget.platform.saveImage(widget.bytes, filename, widget.format);
        if (saved && mounted) setState(() { savedToGallery = true; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:
          Text(saved ? 'Immagine salvata nella galleria YOKAI.' : 'Salvataggio annullato.')));
      } else {
        await widget.platform.shareImage(widget.bytes, filename, widget.format);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Operazione non riuscita: $e')));
    } finally { if (mounted) setState(() { busy = false; }); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PREVIEW'), actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('CLOSE'))]),
    body: SafeArea(child: Column(children: [
      Expanded(child: InteractiveViewer(minScale: 1, maxScale: 4,
        child: Center(child: Image.memory(widget.bytes, fit: BoxFit.contain, gaplessPlayback: true)))),
      if (widget.warnings.isNotEmpty) Padding(padding: const EdgeInsets.all(12),
        child: Text(widget.warnings.join('\n'), style: const TextStyle(fontSize: 12, color: Colors.orange))),
      Padding(padding: const EdgeInsets.all(8), child: Text(savedToGallery ? '1080 × 1920  •  Salvata in galleria' : '1080 × 1920  •  Non ancora salvata', style: const TextStyle(fontSize: 11, color: Colors.white54))),
      Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 8), child: Row(children: [
        Expanded(child: FilledButton.icon(onPressed: busy ? null : () => run(true), icon: const Icon(Icons.download), label: const Text('SAVE IMAGE'))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () => run(false), icon: const Icon(Icons.share), label: const Text('SHARE'))),
      ])),
      TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('EDIT')),
      if (busy) const LinearProgressIndicator(),
    ])));
}
