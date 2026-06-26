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

  Future<void> testTaskAndHabit() async {
    final now = DateTime.now();

    // Tarea en 30 segundos
    await Workmanager().registerOneOffTask(
      'test_task',
      'send_notification',
      initialDelay: const Duration(seconds: 30),
      inputData: {
        'id': 111,
        'title': '📋 Prueba Tarea',
        'body': 'Notificación de tarea funcionando ✅',
      },
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    print('✅ Tarea de prueba programada para 30 segundos');

    // Hábito en 60 segundos
    await Workmanager().registerOneOffTask(
      'test_habit',
      'send_notification',
      initialDelay: const Duration(seconds: 60),
      inputData: {
        'id': 222,
        'title': '💪 Prueba Hábito',
        'body': 'Notificación de hábito funcionando ✅',
      },
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    print('✅ Hábito de prueba programado para 60 segundos');
  }

  // ── Notificación de tarea próxima ─────────────────────────────────────────
  Future<void> scheduleTaskReminder({
    required int id,
    required String title,
    required DateTime dueDate,
  }) async {
    await init();
    final now = DateTime.now();

    // Notificación el día anterior a las 9am
    final dayBefore = DateTime(dueDate.year, dueDate.month, dueDate.day - 1, 9, 0);

    // Notificación 1 hora antes de la hora límite
    final oneHourBefore = dueDate.subtract(const Duration(hours: 1));

    // Notificación exacta a la hora límite
    final exactTime = dueDate;

    if (dayBefore.isAfter(now)) {
      await Workmanager().registerOneOffTask(
        'task_before_$id',
        'send_notification',
        initialDelay: dayBefore.difference(now),
        inputData: {'id': id, 'title': '📋 Tarea mañana', 'body': 'Mañana vence: $title'},
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    }

    if (oneHourBefore.isAfter(now)) {
      await Workmanager().registerOneOffTask(
        'task_hour_$id',
        'send_notification',
        initialDelay: oneHourBefore.difference(now),
        inputData: {'id': id + 1, 'title': '⏰ Tarea en 1 hora', 'body': 'En 1 hora vence: $title'},
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    }

    if (exactTime.isAfter(now)) {
      await Workmanager().registerOneOffTask(
        'task_due_$id',
        'send_notification',
        initialDelay: exactTime.difference(now),
        inputData: {'id': id + 2, 'title': '🚨 Tarea vencida', 'body': 'Venció ahora: $title'},
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    }
  }

// ── Cancelar notificaciones de tarea ──────────────────────────────────────
  Future<void> cancelTaskReminder(int id) async {
    await _plugin.cancel(id);
    await _plugin.cancel(id + 1);
    await _plugin.cancel(id + 2);
    await Workmanager().cancelByUniqueName('task_before_$id');
    await Workmanager().cancelByUniqueName('task_hour_$id');
    await Workmanager().cancelByUniqueName('task_due_$id');
  }

// ── Notificación diaria de hábito ─────────────────────────────────────────
  Future<void> scheduleHabitReminder({
    required int id,
    required String title,
    required String icon,
    required int hour,
    required int minute,
  }) async {
    await init();

    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

    // Si ya pasó la hora hoy, programa para mañana
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    print('🔄 Programando hábito: $title');
    print('   Hora: $hour:$minute');
    print('   Primera notif: $scheduledTime');
    print('   Delay: ${scheduledTime.difference(now).inMinutes} minutos');
    await Workmanager().registerPeriodicTask(
      'habit_$id',
      'send_notification',
      frequency: const Duration(hours: 24),
      initialDelay: scheduledTime.difference(now),
      inputData: {
        'id': id,
        'title': '$icon Hábito pendiente',
        'body': 'No olvides: $title',
      },
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.not_required),
    );
    print('   ✅ Hábito registrado en WorkManager');
  }

// ── Cancelar notificación de hábito ──────────────────────────────────────
  Future<void> cancelHabitReminder(int id) async {
    await _plugin.cancel(id);
    await Workmanager().cancelByUniqueName('habit_$id');
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

    final db = FirebaseFirestore.instance;

    // Recordatorios
    final reminders = await db.collection('users').doc(uid)
        .collection('reminders').where('active', isEqualTo: true).get();

    for (final doc in reminders.docs) {
      final data = doc.data();
      final dt = (data['dateTime'] as Timestamp?)?.toDate();
      if (dt == null || dt.isBefore(DateTime.now())) continue;
      await scheduleReminder(
        id: doc.id.hashCode.abs(),
        title: data['title'] ?? 'Recordatorio',
        body: data['note']?.isNotEmpty == true ? data['note'] : 'Tienes un recordatorio',
        dateTime: dt,
        repeat: data['repeat'] ?? 'No repetir',
      );
    }

    // Tareas
    final tasks = await db.collection('users').doc(uid)
        .collection('tasks').where('completed', isEqualTo: false).get();

    for (final doc in tasks.docs) {
      final data = doc.data();
      final dt = (data['dueDate'] as Timestamp?)?.toDate();
      if (dt == null) continue;
      await scheduleTaskReminder(
        id: doc.id.hashCode.abs(),
        title: data['title'] ?? 'Tarea',
        dueDate: dt,
      );
    }

    // Hábitos
    final habits = await db.collection('users').doc(uid)
        .collection('habits').where('active', isEqualTo: true).get();

    for (final doc in habits.docs) {
      final data = doc.data();
      final hour = data['notifHour'] as int?;
      final minute = data['notifMinute'] as int?;
      if (hour == null || minute == null) continue;
      await scheduleHabitReminder(
        id: doc.id.hashCode.abs(),
        title: data['title'] ?? 'Hábito',
        icon: data['icon'] ?? '💪',
        hour: hour,
        minute: minute,
      );
    }

    print('✅ Notificaciones reprogramadas para: $uid');
  }

  Future<void> cancelAllUserNotifications() async {
    await Workmanager().cancelAll();
    await _plugin.cancelAll();
    print('🗑️ Todas las notificaciones canceladas');
  }

  Future<void> rescheduleForUser(String uid) async {
    await cancelAllUserNotifications();
    await rescheduleAll();
    print('🔄 Notificaciones reprogramadas para usuario: $uid');
  }

  // ── Generar ID desde doc ID de Firestore ──────────────────────────────────
  int idFromDocId(String docId) => docId.hashCode.abs();
}