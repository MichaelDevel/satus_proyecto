import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:workmanager/workmanager.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Bogota'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {},
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // ← Crear canal explícitamente
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'reminders_channel',
        'Recordatorios',
        description: 'Notificaciones de recordatorios',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    await androidPlugin?.requestNotificationsPermission();
/*
    final canSchedule = await androidPlugin?.canScheduleExactNotifications();
    if (canSchedule != true) {
      await androidPlugin?.requestExactAlarmsPermission();
    }
*/
    _initialized = true;
  }

  // ── Programar recordatorio ────────────────────────────────────────────────
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    required String repeat,
  }) async {
    await init();

    final now = DateTime.now();
    final delay = dateTime.difference(now);

    print('🔔 Programando notificación:');
    print('   ID: $id');
    print('   Título: $title');
    print('   Fecha programada: $dateTime');
    print('   Delay: ${delay.inSeconds} segundos');

    if (delay.isNegative) {
      print('❌ Fecha ya pasó');
      return;
    }

    // Cancelar tarea previa con mismo ID
    await Workmanager().cancelByUniqueName('reminder_$id');

    // Programar con WorkManager
    await Workmanager().registerOneOffTask(
      'reminder_$id',
      'send_notification',
      initialDelay: delay,
      inputData: {
        'id': id,
        'title': title,
        'body': body,
      },
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    print('✅ Tarea registrada en WorkManager');
  }

  Future<void> testNotification() async {
    await init();
    await _plugin.show(
      999,
      'Prueba',
      'Si ves esto, las notificaciones funcionan ✅',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders_channel',
          'Recordatorios',
          importance: Importance.max,
          priority: Priority.max,
        ),
      ),
    );
  }

  Future<void> testScheduled() async {
    await init();
    final scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 30));

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    final canSchedule = await androidPlugin?.canScheduleExactNotifications();
    print('¿Puede alarmas exactas?: $canSchedule');

    await _plugin.zonedSchedule(
      998,
      'Prueba programada',
      'Llegó la notificación programada ✅',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders_channel',
          'Recordatorios',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
    print('⏰ Programada para: $scheduledDate');
  }

  // ── Cancelar recordatorio ─────────────────────────────────────────────────
  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
    await Workmanager().cancelByUniqueName('reminder_$id');
  }

  // ── Cancelar todos ────────────────────────────────────────────────────────
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Reprogramar todos desde Firestore ─────────────────────────────────────
  Future<void> rescheduleAll() async {
    await init();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('reminders')
        .where('active', isEqualTo: true)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final dt = (data['dateTime'] as Timestamp?)?.toDate();
      if (dt == null) continue;

      // Usar los últimos 8 caracteres del ID como int
      final notifId = doc.id.hashCode.abs();

      await scheduleReminder(
        id: notifId,
        title: data['title'] ?? 'Recordatorio',
        body: data['note']?.isNotEmpty == true ? data['note'] : 'Tienes un recordatorio',
        dateTime: dt,
        repeat: data['repeat'] ?? 'No repetir',
      );
    }
  }

  // ── Generar ID desde doc ID de Firestore ──────────────────────────────────
  int idFromDocId(String docId) => docId.hashCode.abs();
}