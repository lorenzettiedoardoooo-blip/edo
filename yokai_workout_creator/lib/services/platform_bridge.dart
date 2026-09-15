import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Android implementation is in MainActivity.kt. Keep platform services isolated
/// so an iOS adapter can be added without changing the editor or renderer.
class PlatformBridge {
  static const channel = MethodChannel('it.yokai.workout/platform');
  Future<List<String>> readWorkouts() async =>
    (await channel.invokeListMethod<String>('readWorkouts')) ?? [];
  Future<void> writeWorkout(String id, String json) =>
    channel.invokeMethod<void>('writeWorkout', {'id': id, 'json': json});
  Future<void> deleteWorkout(String id) => channel.invokeMethod<void>('deleteWorkout', {'id': id});
  Future<String?> readSettings() => channel.invokeMethod<String>('readSettings');
  Future<void> writeSettings(String json) => channel.invokeMethod<void>('writeSettings', {'json': json});
  Future<Uint8List?> pickLogo() => channel.invokeMethod<Uint8List>('pickLogo');
  Future<Uint8List> encodeImage(Uint8List png, String format) async {
    if (format == 'png') return png;
    final bytes = await channel.invokeMethod<Uint8List>('encodeJpg', {'bytes': png});
    if (bytes == null) throw StateError('Conversione JPG non riuscita');
    return bytes;
  }
  Future<bool> saveImage(Uint8List bytes, String name, String format) async =>
    await channel.invokeMethod<bool>('saveImage', {'bytes': bytes, 'name': name, 'format': format}) ?? false;
  Future<void> shareImage(Uint8List bytes, String name, String format) =>
    channel.invokeMethod<void>('shareImage', {'bytes': bytes, 'name': name, 'format': format});
}
