import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SatusTaskHandler());
}

class SatusTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('🚀 Foreground service iniciado');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onNotificationButtonPressed(String id) async {
    print('🔘 Botón presionado en servicio: $id');
    if (id == 'btn_speak') {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/pending_listen.txt');
        await file.writeAsString(DateTime.now().millisecondsSinceEpoch.toString());
        print('✅ Archivo escrito: ${file.path}');
      } catch (e) {
        print('❌ Error escribiendo archivo: $e');
      }
      FlutterForegroundTask.launchApp();
    }
  }

  @override
  void onNotificationPressed() async {
    print('🔔 Notificación presionada');
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/pending_listen.txt');
      await file.writeAsString(DateTime.now().millisecondsSinceEpoch.toString());
    } catch (e) {
      print('❌ Error: $e');
    }
    FlutterForegroundTask.launchApp();
  }
}