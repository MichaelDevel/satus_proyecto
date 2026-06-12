import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == 'send_notification') {
      final plugin = FlutterLocalNotificationsPlugin();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await plugin.initialize(const InitializationSettings(android: android));

      await plugin.show(
        inputData?['id'] ?? 0,
        inputData?['title'] ?? 'Recordatorio',
        inputData?['body'] ?? '',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders_channel',
            'Recordatorios',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            enableVibration: true,
            playSound: true,
          ),
        ),
      );
    }
    return true;
  });
}