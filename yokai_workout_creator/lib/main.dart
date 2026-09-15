import 'package:flutter/material.dart';
import 'services/platform_bridge.dart';
import 'storage/workout_store.dart';
import 'theme/yokai_theme.dart';
import 'screens/home_screen.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const YokaiApp()); }
class YokaiApp extends StatefulWidget {
  const YokaiApp({super.key});
  @override
  State<YokaiApp> createState() => _YokaiAppState();
}
class _YokaiAppState extends State<YokaiApp> {
  final store = WorkoutStore(PlatformBridge());
  late Future<void> ready;
  @override
  void initState() { super.initState(); ready = store.load(); }
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'YOKAI WORKOUT CREATOR', debugShowCheckedModeBanner: false, theme: YokaiTheme.dark,
    home: FutureBuilder<void>(future: ready, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.warning_amber_rounded, size: 48),
            const Text('Impossibile aprire i dati salvati.', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 12),
            const Text('I file esistenti non vengono sostituiti. Riprova prima di modificare gli allenamenti.'),
            Text('${snapshot.error}', maxLines: 5),
            FilledButton(onPressed: () => setState(() { ready = store.load(); }), child: const Text('RIPROVA')),
          ]))));
      }
      return HomeScreen(store: store);
    }));
}
