import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'foreground_service.dart';

class PersistentNotificationService {
  static final PersistentNotificationService _instance = PersistentNotificationService._();
  factory PersistentNotificationService() => _instance;
  PersistentNotificationService._();

  void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'satus_assistant',
        channelName: 'Asistente Satus',
        channelDescription: 'Toca Hablar para dar un comando de voz',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,   // ← reinicia al encender el celular
        allowWakeLock: true,   // ← mantiene el servicio activo
      ),
    );
  }

  Future<void> start() async {
    // Pedir permiso de notificaciones primero
    await FlutterForegroundTask.requestNotificationPermission();

    await FlutterForegroundTask.startService(
      serviceId: 1,
      notificationTitle: 'Satus Assistant',
      notificationText: 'Toca Hablar para dar un comando de voz',
      notificationButtons: [
        const NotificationButton(id: 'btn_speak', text: '🎤 Hablar'),
      ],
      callback: startCallback,
    );
  }

  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }

  Future<void> updateText(String text) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Satus Assistant',
      notificationText: text,
    );
  }
}