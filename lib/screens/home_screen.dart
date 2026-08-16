import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:satus_proyecto/screens/habit_detail_screen.dart';
import 'package:satus_proyecto/screens/reminder_detail_screen.dart';
import 'package:satus_proyecto/screens/task_detail_screen.dart';
import 'package:satus_proyecto/services/notification_service.dart';
import '../services/persistent_notification_service.dart';
import '../services/voice_command_service.dart';
import 'adds/add_habit_screen.dart';
import 'adds/add_reminder_screen.dart';
import 'adds/add_task_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ── Colores ──────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF060A12);
  static const _surface = Color(0xFF0D1117);
  static const _accent = Color(0xFF6366F1);

  bool _pendingStartListening = false;
  // ── Estado del micrófono ─────────────────────────────────────────────────────
  bool _isListening = false;
  // String _voiceText = 'Toca el micrófono para hablar...';
  final ValueNotifier<String> _voiceTextNotifier = ValueNotifier('Toca el micrófono para hablar...');
  late AnimationController _pulseCtrl;
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isProcessingCommand = false;

  // Estado del flujo de voz
  String _voiceFlowType = ''; // 'task', 'habit', 'reminder'
  int _voiceFlowStep = 0;
  Map<String, dynamic> _voiceFlowData = {};
  bool _inFlow = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  final MethodChannel _widgetChannel = const MethodChannel('com.example.satus_proyecto/widget');
  int _selectedTab = 0;
  // ── Estado del calendario ─────────────────────────────────────────────────────
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _initSpeech();
    _initTts();
    _updateHabitStreaks();
    _updateHomeWidget();
    NotificationService().testZonedSchedule();
    NotificationService().rescheduleAll();
    //PersistentNotificationService().start();
    FlutterForegroundTask.addTaskDataCallback(_onForegroundData);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 1500));
      await _checkPendingListen();
    });
    _widgetChannel.setMethodCallHandler((call) async {
      if (call.method == 'openHabit') {
        final habitId = call.arguments as String;
        // Buscar el hábito en Firestore y navegar
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.uid)
            .collection('habits')
            .doc(habitId)
            .get();
        if (snap.exists && mounted) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => HabitDetailScreen(
              habitId: habitId,
              data: snap.data()!,
            ),
          ));
        }
      }
    });
    // Limpiar todas las tareas viejas y reprogramar
    _cleanAndReschedule();
  }
  // ── Inicializaciones ─────────────────────────────────────────────────────
  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() {
            _isListening = false;
            _pulseCtrl.stop();
            _pulseCtrl.reset();
          });
          _voiceTextNotifier.value = 'Toca el micrófono para hablar...';
          PersistentNotificationService().updateText('Toca Hablar para dar un comando de voz');
        }
      },
      onError: (error) {
        if (mounted) setState(() {
          _isListening = false;
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        });
        _voiceTextNotifier.value = 'Error: ${error.errorMsg}';
      },
    );

    // ← Ejecutar intent pendiente si llegó antes de que el micrófono estuviera listo
    if (_pendingStartListening && _speechAvailable && mounted) {
      _pendingStartListening = false;
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && !_isListening) _toggleListening();
    }
  }

  Future<void> _cleanAndReschedule() async {
    await Workmanager().cancelAll();
    await NotificationService().rescheduleAll();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('es-CO');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  void _onForegroundData(Object data) {
    print('📨 Datos recibidos del foreground: $data');
    print('   _speechAvailable: $_speechAvailable');
    print('   _isListening: $_isListening');
    print('   mounted: $mounted');
    print('   _pendingStartListening: $_pendingStartListening');
    if (data is Map && data['action'] == 'start_listening') {
      if (_speechAvailable && mounted && !_isListening) {
        print('✅ Activando micrófono directamente...');
        Future.delayed(const Duration(milliseconds: 1000), () {
          print('⏰ Delay completado, llamando _toggleListening...');
          if (mounted && !_isListening) _toggleListening();
        });
      } else {
        print('⏳ Marcando como pendiente...');
        _pendingStartListening = true;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    print('🔄 Ciclo de vida: $state');

    if (state == AppLifecycleState.resumed) {
      await _checkPendingListen();
      await _updateHomeWidget();
    }
  }

  Future<void> _checkPendingListen() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/pending_listen.txt');

      if (!await file.exists()) {
        print('🔍 No hay archivo pending_listen');
        return;
      }

      final content = await file.readAsString();
      final timestamp = int.tryParse(content.trim()) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;

      print('🔍 Archivo encontrado, age: ${age}ms');

      if (age < 15000) { // menos de 15 segundos
        await file.delete(); // limpiar
        print('✅ Activando micrófono desde archivo...');
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted && !_isListening && _speechAvailable) {
          _toggleListening();
        }
      } else {
        print('⚠️ Archivo muy antiguo ($age ms), ignorando');
        await file.delete();
      }
    } catch (e) {
      print('❌ Error leyendo archivo: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onForegroundData);
    _pulseCtrl.dispose();
    _audioPlayer.dispose();
    _tts.stop();
    _voiceTextNotifier.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    if (!_speechAvailable) {
      _voiceTextNotifier.value = 'Micrófono no disponible.';
      return;
    }

    if (_isListening) {
      await _playStopSound(); // ← sonido de fin
      await _speech.stop();
      setState(() {
        _isListening = false;
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      });
      PersistentNotificationService().updateText('Toca Hablar para dar un comando de voz');
      _voiceTextNotifier.value = 'Toca el micrófono para hablar...';
    } else {
      await _playStartSound(); // ← sonido de inicio
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _isListening = true;
        _pulseCtrl.repeat(reverse: true);
      });
      PersistentNotificationService().updateText('🎤 Escuchando...');
      _voiceTextNotifier.value = 'Escuchando...';
      await _speech.listen(
        onResult: (result) {
          _voiceTextNotifier.value = result.recognizedWords.isNotEmpty
              ? result.recognizedWords
              : 'Escuchando...';
          if (result.finalResult &&
              result.recognizedWords.isNotEmpty &&
              !_isProcessingCommand) {
            _isProcessingCommand = true;
            _processVoiceCommand(result.recognizedWords);
          }
        },
        localeId: 'es_CO',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _createReminderFromCommand(String text) async {
    _voiceTextNotifier.value = '🔔 Creando recordatorio...';

    // Extraer título: lo que sigue a "llamada/llamado/titulada" o después de "para"
    String title = _extractTitle(text, ['llamada', 'llamado', 'titulada', 'titulado', 'llamar']);

    // Si no encontró título explícito, usar lo que queda después de quitar fecha/hora/verbos
    if (title.isEmpty) {
      title = _extractFallbackTitle(text);
    }

    // Extraer fecha (default: mañana)
    DateTime date = _parseDateFromText(text) ?? DateTime.now();

    // Extraer hora (default: 9:00 AM)
    List<int>? time = _parseTimeFromTextNullable(text);
    int hour = time?[0] ?? 9;
    int minute = time?[1] ?? 0;

    final dateTime = DateTime(date.year, date.month, date.day, hour, minute);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final docRef = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('reminders')
          .add({
        'title': title.isNotEmpty ? title : 'Recordatorio',
        'note': '',
        'dateTime': Timestamp.fromDate(dateTime),
        'repeat': 'No repetir',
        'active': true,
        'triggered': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await NotificationService().scheduleReminder(
        id: docRef.id.hashCode.abs(),
        title: title.isNotEmpty ? title : 'Recordatorio',
        body: 'Tienes un recordatorio',
        dateTime: dateTime,
        repeat: 'No repetir',
      );

      final dateLabel = _formatDateLabel(dateTime);
      final dateFormatted = '${dateTime.day.toString().padLeft(2,'0')}/${dateTime.month.toString().padLeft(2,'0')}/${dateTime.year}';
      _endFlow('✅ Recordatorio "$title" creado para el día $dateFormatted a las ${hour.toString().padLeft(2,'0')}:${minute.toString().padLeft(2,'0')}.');
    } catch (e) {
      _endFlow('❌ Error al crear el recordatorio.');
    }
  }

  Future<void> _handleSmartCreate(String text) async {
    await _playStopSound();
    await _speech.stop();
    setState(() {
      _isListening = false;
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    });

    final t = text.toLowerCase();

    if (t.contains('hábito') || t.contains('habito')) {
      await _createHabitFromCommand(text);
    } else if (t.contains('recordatorio') || t.contains('alerta')) {
      await _createReminderFromCommand(text);
    } else if (t.contains('tarea')) {
      await _createTaskFromCommand(text);
    } else {
      _endFlow('❓ No entendí qué quieres crear.');
    }
  }

  Future<void> _handleCompleteCommand(String text) async {
    await _playStopSound();
    await _speech.stop();
    setState(() {
      _isListening = false;
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    });

    final t = text.toLowerCase();

    if (t.contains('hábito') || t.contains('habito')) {
      await _completeHabitFromCommand(text);
    } else if (t.contains('tarea')) {
      await _completeTaskFromCommand(text);
    } else {
      // Sin tipo específico, buscar en ambas colecciones
      await _completeAnyFromCommand(text);
    }
  }

  void _processVoiceCommand(String text) async {
    if (_inFlow) {
      _handleFlowStep(text);
      return;
    }

    final t = text.toLowerCase().trim();

    if (_isCompleteCommand(t)) {
      await _handleCompleteCommand(text);
      return;
    }
    // Detectar comando completo de creación
    if (_isCreateCommand(t)) {
      await _handleSmartCreate(text);
      return;
    }

    // Comandos de navegación normales
    final command = VoiceCommandService.parse(text);
    final desc = VoiceCommandService.description(command);

    setState(() {
      _isListening = false;

      _pulseCtrl.stop();
      _pulseCtrl.reset();
    });
    _voiceTextNotifier.value = desc;
    await _speech.stop();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    switch (command) {
      case VoiceCommand.newTask:
        _startTaskFlow();
        break;
      case VoiceCommand.newHabit:
        _startHabitFlow();
        break;
      case VoiceCommand.newReminder:
        _startReminderFlow();
        break;
      case VoiceCommand.goHome:
        setState(() => _selectedTab = 0);
        break;
      case VoiceCommand.goTasks:
        setState(() => _selectedTab = 1);
        break;
      case VoiceCommand.goHabits:
        setState(() => _selectedTab = 2);
        break;
      case VoiceCommand.goReminders:
        setState(() => _selectedTab = 3);
        break;
      case VoiceCommand.goStats:
        setState(() => _selectedTab = 4);
        break;
      case VoiceCommand.signOut:
        await NotificationService().cancelAllUserNotifications();
        await AuthService().signOut();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        break;
      case VoiceCommand.unknown:
        _speak('Comando no reconocido');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) _voiceTextNotifier.value = 'Toca el micrófono para hablar...';
        break;
    }
  }

  Future<void> _createTaskFromCommand(String text) async {
    _voiceTextNotifier.value = '📋 Creando tarea...';

    String title = _extractTitle(text, ['llamada', 'llamado', 'titulada', 'titulado', 'llamar']);
    if (title.isEmpty) title = _extractFallbackTitle(text);

    final t = text.toLowerCase();
    String priority = 'Media';
    if (t.contains('alta') || t.contains('urgente') || t.contains('importante')) priority = 'Alta';
    else if (t.contains('baja')) priority = 'Baja';

    DateTime? dueDate = _parseDateFromText(text);
    // Si no hay fecha explícita, default a mañana
    dueDate ??= DateTime.now().add(const Duration(days: 1));

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final docRef = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('tasks')
          .add({
        'title': title.isNotEmpty ? title : 'Tarea',
        'description': '',
        'priority': priority,
        'dueDate': Timestamp.fromDate(dueDate),
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await NotificationService().scheduleTaskReminder(
        id: docRef.id.hashCode.abs(),
        title: title.isNotEmpty ? title : 'Tarea',
        dueDate: dueDate,
      );

      final dateLabel = _formatDateLabel(dueDate);
      final dateFormatted = '${dueDate.day.toString().padLeft(2,'0')}/${dueDate.month.toString().padLeft(2,'0')}/${dueDate.year}';
      _endFlow('✅ Tarea "$title" creada para el día $dateFormatted con prioridad $priority.');
    } catch (e) {
      _endFlow('❌ Error al crear la tarea.');
    }
  }

  Future<void> _createHabitFromCommand(String text) async {
    _voiceTextNotifier.value = '🔄 Creando hábito...';

    String title = _extractTitle(text, ['llamada', 'llamado', 'titulada', 'titulado', 'llamar']);
    if (title.isEmpty) title = _extractFallbackTitle(text);

    final t = text.toLowerCase();
    String frequency = 'Diario'; // default
    if (t.contains('semanal')) frequency = 'Semanal';
    else if (t.contains('mensual')) frequency = 'Mensual';

    List<int>? time = _parseTimeFromTextNullable(text);
    int hour = time?[0] ?? 8; // default 8am
    int minute = time?[1] ?? 0;

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final docRef = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('habits')
          .add({
        'title': title.isNotEmpty ? title : 'Hábito',
        'description': '',
        'frequency': frequency,
        'icon': '💪',
        'days': [0, 1, 2, 3, 4, 5, 6],
        'streak': 0,
        'completedDates': [],
        'active': true,
        'notifHour': hour,
        'notifMinute': minute,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await NotificationService().scheduleHabitReminder(
        id: docRef.id.hashCode.abs(),
        title: title.isNotEmpty ? title : 'Hábito',
        icon: '💪',
        hour: hour,
        minute: minute,
      );

      _endFlow('✅ Hábito "$title" creado con frecuencia $frequency a las ${hour.toString().padLeft(2,'0')}:${minute.toString().padLeft(2,'0')}.');    } catch (e) {
      _endFlow('❌ Error al crear el hábito.');

    }
  }

  bool _isCompleteCommand(String t) {
    final verbs = ['completa', 'completar', 'marca', 'marcar', 'termina', 'terminar', 'hecho', 'hice', 'ya hice'];
    return verbs.any((v) => t.contains(v));
  }

  bool _isCreateCommand(String t) {
    final verbs = ['crea', 'crear', 'agrega', 'agregar', 'añade', 'añadir', 'pon', 'poner', 'nueva', 'nuevo'];
    final types = ['tarea', 'hábito', 'habito', 'recordatorio', 'alerta'];
    final hasVerb = verbs.any((v) => t.contains(v));
    final hasType = types.any((ty) => t.contains(ty));
    // Solo es comando completo si tiene más contenido que solo "crea tarea"
    return hasVerb && hasType && t.split(' ').length > 3;
  }

  void _startTaskFlow() {
    setState(() {
      _inFlow = true;
      _voiceFlowType = 'task';
      _voiceFlowStep = 0;
      _voiceFlowData = {};

    });
    _voiceTextNotifier.value = '¿Cuál es el título de la tarea?';
    _speak('¿Cuál es el título de la tarea?');
    _listenForFlow();
  }

  void _startHabitFlow() {
    setState(() {
      _inFlow = true;
      _voiceFlowType = 'habit';
      _voiceFlowStep = 0;
      _voiceFlowData = {};
      _speak('¿Cuál es el nombre del hábito?');
    });
    _voiceTextNotifier.value = '¿Cuál es el nombre del hábito?';
    _listenForFlow();
  }

  void _startReminderFlow() {
    setState(() {
      _inFlow = true;
      _voiceFlowType = 'reminder';
      _voiceFlowStep = 0;
      _voiceFlowData = {};
      _speak('¿Cuál es el título del recordatorio?');
    });
    _voiceTextNotifier.value = '¿Cuál es el título del recordatorio?';
    _listenForFlow();
  }

  void _listenForFlow() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    await _playStartSound();
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _isListening = true;
      _isProcessingCommand = false;
      _pulseCtrl.repeat(reverse: true);
    });

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _handleFlowStep(result.recognizedWords);
        }
      },
      localeId: 'es_CO',
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _handleFlowStep(String text) async {
    await _playStopSound();
    await _speech.stop();
    setState(() {
      _isListening = false;
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    });

    switch (_voiceFlowType) {
      case 'task':
        await _handleTaskFlow(text);
        break;
      case 'habit':
        await _handleHabitFlow(text);
        break;
      case 'reminder':
        await _handleReminderFlow(text);
        break;
    }
  }

  //flujo de tareas
  Future<void> _handleTaskFlow(String text) async {
    switch (_voiceFlowStep) {
      case 0: // Título
        _voiceFlowData['title'] = text;
        _voiceFlowStep = 1;
        _voiceTextNotifier.value = '¿Qué prioridad tiene? Di alta, media o baja.';
        _speak('¿Qué prioridad tiene? Di alta, media o baja.');
        _listenForFlow();
        break;

      case 1: // Prioridad
        final t = text.toLowerCase();
        String priority = 'Media';
        if (t.contains('alta')) priority = 'Alta';
        else if (t.contains('baja')) priority = 'Baja';
        _voiceFlowData['priority'] = priority;
        _voiceFlowStep = 2;
        _voiceTextNotifier.value = '¿Tiene fecha límite? Di sí o no.';
        _speak('¿Tiene fecha límite? Di sí o no.');
        _listenForFlow();
        break;

      case 2: // ¿Tiene fecha?
        final t = text.toLowerCase();
        if (t.contains('sí') || t.contains('si')) {
          _voiceFlowStep = 3;
          _voiceTextNotifier.value = 'Di la fecha: por ejemplo "15 de julio".';
          _speak('Di la fecha: por ejemplo "15 de julio".');
          _listenForFlow();
        } else {
          _voiceFlowData['dueDate'] = null;
          await _saveTaskFromVoice();
        }
        break;

      case 3: // Fecha
        final date = _parseDateFromText(text);
        _voiceFlowData['dueDate'] = date;
        await _saveTaskFromVoice();
        break;
    }
  }

  Future<void> _saveTaskFromVoice() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final dueDate = _voiceFlowData['dueDate'] as DateTime?;

      final docRef = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('tasks')
          .add({
        'title': _voiceFlowData['title'],
        'description': '',
        'priority': _voiceFlowData['priority'] ?? 'Media',
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (dueDate != null) {
        await NotificationService().scheduleTaskReminder(
          id: docRef.id.hashCode.abs(),
          title: _voiceFlowData['title'],
          dueDate: dueDate,
        );
      }

      _endFlow('✅ Tarea "${_voiceFlowData['title']}" creada.');
    } catch (e) {
      _playErrorSound();
      _endFlow('❌ Error al crear la tarea.');
    }
  }

  //flujo de hábitos
  Future<void> _handleHabitFlow(String text) async {
    switch (_voiceFlowStep) {
      case 0: // Nombre
        _voiceFlowData['title'] = text;
        _voiceFlowStep = 1;
        _voiceTextNotifier.value = '¿Con qué frecuencia? Di diario, semanal o mensual.';
        _speak('¿Con qué frecuencia? Di diario, semanal o mensual.');
        _listenForFlow();
        break;

      case 1: // Frecuencia
        final t = text.toLowerCase();
        String freq = 'Diario';
        if (t.contains('semanal')) freq = 'Semanal';
        else if (t.contains('mensual')) freq = 'Mensual';
        _voiceFlowData['frequency'] = freq;
        _voiceFlowStep = 2;
        _voiceTextNotifier.value = '¿A qué hora quieres el recordatorio? Di por ejemplo "ocho de la mañana".';
        _speak('¿A qué hora quieres el recordatorio? Di por ejemplo "ocho de la mañana".');
        _listenForFlow();
        break;

      case 2: // Hora
        final time = _parseTimeFromText(text);
        _voiceFlowData['hour'] = time[0];
        _voiceFlowData['minute'] = time[1];
        await _saveHabitFromVoice();
        break;
    }
  }

  Future<void> _saveHabitFromVoice() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final hour = _voiceFlowData['hour'] as int;
      final minute = _voiceFlowData['minute'] as int;

      final docRef = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('habits')
          .add({
        'title': _voiceFlowData['title'],
        'description': '',
        'frequency': _voiceFlowData['frequency'] ?? 'Diario',
        'icon': '💪',
        'days': [0, 1, 2, 3, 4, 5, 6],
        'streak': 0,
        'completedDates': [],
        'active': true,
        'notifHour': hour,
        'notifMinute': minute,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await NotificationService().scheduleHabitReminder(
        id: docRef.id.hashCode.abs(),
        title: _voiceFlowData['title'],
        icon: '💪',
        hour: hour,
        minute: minute,
      );

      _endFlow('✅ Hábito "${_voiceFlowData['title']}" creado.');
    } catch (e) {
      _playErrorSound();
      _endFlow('❌ Error al crear el hábito.');
    }
  }

  //flujo de recordatorios
  Future<void> _handleReminderFlow(String text) async {
    switch (_voiceFlowStep) {
      case 0: // Título
        _voiceFlowData['title'] = text;
        _voiceFlowStep = 1;
        _voiceTextNotifier.value = 'Di la fecha: por ejemplo "mañana" o "15 de julio".';
        _speak('Di la fecha: por ejemplo "mañana" o "15 de julio".');
        _listenForFlow();
        break;

      case 1: // Fecha
        final date = _parseDateFromText(text);
        _voiceFlowData['date'] = date ?? DateTime.now().add(const Duration(days: 1));
        _voiceFlowStep = 2;
        _voiceTextNotifier.value = '¿A qué hora? Di por ejemplo "tres de la tarde".';
        _speak('¿A qué hora? Di por ejemplo "tres de la tarde".');
        _listenForFlow();
        break;

      case 2: // Hora
        final time = _parseTimeFromText(text);
        _voiceFlowData['hour'] = time[0];
        _voiceFlowData['minute'] = time[1];
        await _saveReminderFromVoice();
        break;
    }
  }

  Future<void> _saveReminderFromVoice() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final date = _voiceFlowData['date'] as DateTime;
      final dateTime = DateTime(
        date.year, date.month, date.day,
        _voiceFlowData['hour'], _voiceFlowData['minute'],
      );

      final docRef = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('reminders')
          .add({
        'title': _voiceFlowData['title'],
        'note': '',
        'dateTime': Timestamp.fromDate(dateTime),
        'repeat': 'No repetir',
        'active': true,
        'triggered': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await NotificationService().scheduleReminder(
        id: docRef.id.hashCode.abs(),
        title: _voiceFlowData['title'],
        body: 'Tienes un recordatorio',
        dateTime: dateTime,
        repeat: 'No repetir',
      );

      _endFlow('✅ Recordatorio "${_voiceFlowData['title']}" creado.');
    } catch (e) {
      _playErrorSound();
      _endFlow('❌ Error al crear el recordatorio.');
    }
  }

  Future<void> _updateHomeWidget() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final todayWeekday = now.weekday - 1;
    final prefs = await SharedPreferences.getInstance();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('habits')
          .where('active', isEqualTo: true).get();

      final habits = snap.docs.where((d) {
        final days = List<int>.from(d.data()['days'] ?? [0,1,2,3,4,5,6]);
        return days.contains(todayWeekday);
      }).toList()
        ..sort((a, b) => (a.data()['startHour'] as int? ?? 0)
            .compareTo(b.data()['startHour'] as int? ?? 0));

      final timeStr = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
      await prefs.setString('current_time', timeStr);

      print('📦 habit_count guardado: ${prefs.getInt('habit_count')}');
      print('📦 current_time guardado: ${prefs.getString('current_time')}');
      print('📦 habit_title_1 guardado: ${prefs.getString('habit_title_1')}');

      // Separar activos y próximos — FUERA del loop
      final active = habits.where((d) {
        final data = d.data();
        final startH = data['startHour'] as int? ?? 0;
        final startM = data['startMinute'] as int? ?? 0;
        final endH = data['endHour'] as int? ?? 23;
        final endM = data['endMinute'] as int? ?? 59;
        return nowMin >= startH * 60 + startM && nowMin < endH * 60 + endM;
      }).toList();

      final upcoming = habits.where((d) {
        final data = d.data();
        final startH = data['startHour'] as int? ?? 0;
        final startM = data['startMinute'] as int? ?? 0;
        return startH * 60 + startM > nowMin;
      }).toList();

      final sorted = [...active, ...upcoming];

      await prefs.setInt('habit_count', sorted.length > 2 ? 2 : sorted.length);

// Loop usa sorted
      for (int i = 0; i < sorted.length && i < 2; i++) {
        final data = sorted[i].data();
        final startH = data['startHour'] as int? ?? 0;
        final startM = data['startMinute'] as int? ?? 0;
        final endH = data['endHour'] as int? ?? 23;
        final endM = data['endMinute'] as int? ?? 59;
        final isActive = nowMin >= startH * 60 + startM && nowMin < endH * 60 + endM;
        final n = i + 1;

        await prefs.setString('habit_id_$n', sorted[i].id);
        await prefs.setString('habit_title_$n', '${data['icon'] ?? ''} ${data['title'] ?? ''}');
        await prefs.setString('habit_start_$n', '${startH.toString().padLeft(2,'0')}:${startM.toString().padLeft(2,'0')}');
        await prefs.setString('habit_end_$n', '${endH.toString().padLeft(2,'0')}:${endM.toString().padLeft(2,'0')}');
        await prefs.setBool('habit_active_$n', isActive);

      }

      print('📡 Llamando invokeMethod updateWidget...');
      await _widgetChannel.invokeMethod('updateWidget');
      print('📡 invokeMethod completado');
      print('✅ Widget actualizado: ${habits.length} hábitos');
    } catch (e) {
      print('❌ Error widget: $e');
    }
  }

  //helpers para parsing
  void _endFlow(String message) async {
    setState(() {
      _inFlow = false;
      _voiceFlowType = '';
      _voiceFlowStep = 0;
      _voiceFlowData = {};
      _isProcessingCommand = false;
    });
    _voiceTextNotifier.value = message;
    // Hablar el mensaje
    final spokenText = message.replaceAll(RegExp(r'[✅❌🔔📋🔄]'), '').trim();
    await _speak(spokenText);

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) _voiceTextNotifier.value = 'Toca el micrófono para hablar...';
  }

  DateTime? _parseDateFromText(String text) {
    final t = text.toLowerCase();
    final now = DateTime.now();

    if (t.contains('hoy')) return now;
    if (t.contains('mañana')) return now.add(const Duration(days: 1));
    if (t.contains('pasado')) return now.add(const Duration(days: 2));

    // Intentar parsear "15 de julio"
    const months = {
      'enero': 1, 'febrero': 2, 'marzo': 3, 'abril': 4,
      'mayo': 5, 'junio': 6, 'julio': 7, 'agosto': 8,
      'septiembre': 9, 'octubre': 10, 'noviembre': 11, 'diciembre': 12,
    };

    for (final entry in months.entries) {
      if (t.contains(entry.key)) {
        final regex = RegExp(r'(\d+)');
        final match = regex.firstMatch(t);
        if (match != null) {
          final day = int.tryParse(match.group(1) ?? '') ?? 1;
          int year = now.year;
          if (entry.value < now.month) year++;
          return DateTime(year, entry.value, day);
        }
      }
    }

    return null;
  }

  List<int> _parseTimeFromText(String text) {
    final t = text.toLowerCase();

    // Detectar AM/PM
    bool isPM = t.contains('tarde') || t.contains('noche') || t.contains('pm');
    bool isAM = t.contains('mañana') || t.contains('am');

    // Palabras a números
    const wordNumbers = {
      'una': 1, 'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5,
      'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9, 'diez': 10,
      'once': 11, 'doce': 12, 'cero': 0,
    };

    int hour = 8;
    int minute = 0;

    // Buscar número en palabras
    for (final entry in wordNumbers.entries) {
      if (t.contains(entry.key)) {
        hour = entry.value;
        break;
      }
    }

    // Buscar número directo: "3:30" o "15"
    final timeRegex = RegExp(r'(\d{1,2})(?::(\d{2}))?');
    final match = timeRegex.firstMatch(t);
    if (match != null) {
      hour = int.tryParse(match.group(1) ?? '') ?? hour;
      minute = int.tryParse(match.group(2) ?? '') ?? 0;
    }

    // Ajustar AM/PM
    if (isPM && hour < 12) hour += 12;
    if (isAM && hour == 12) hour = 0;
    if (hour > 23) hour = 23;

    // Buscar minutos en palabras
    if (t.contains('y media')) minute = 30;
    if (t.contains('y cuarto')) minute = 15;
    if (t.contains('menos cuarto')) { hour--; minute = 45; }

    return [hour, minute];
  }

  String _extractTitle(String text, List<String> keywords) {
    final t = text.toLowerCase();
    for (final kw in keywords) {
      final idx = t.indexOf(kw);
      if (idx != -1) {
        final after = text.substring(idx + kw.length).trim();
        // Cortar en la primera palabra de fecha/hora si existe
        return _cleanTitle(after);
      }
    }
    return '';
  }

  String _extractFallbackTitle(String text) {
    // Quita verbos, tipos, fechas y horas comunes para quedarse con lo esencial
    String t = text;
    final removeWords = [
      'crea', 'crear', 'agrega', 'agregar', 'añade', 'añadir', 'pon', 'poner',
      'nueva', 'nuevo', 'una', 'un', 'tarea', 'hábito', 'habito', 'recordatorio',
      'alerta', 'para', 'mañana', 'hoy', 'pasado mañana', 'a las',
    ];
    for (final w in removeWords) {
      t = t.replaceAll(RegExp(w, caseSensitive: false), '');
    }
    // Quitar patrones de hora como "2:00pm", "dos de la tarde"
    t = t.replaceAll(RegExp(r'\d{1,2}:\d{2}\s*(am|pm)?', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\d{1,2}\s*(am|pm)', caseSensitive: false), '');

    return _cleanTitle(t);
  }

  String _extractItemName(String text) {
    final t = text.toLowerCase();
    String cleaned = t;

    final removeWords = [
      'completa', 'completar', 'marca', 'marcar', 'termina', 'terminar',
      'hecho', 'hice', 'ya hice', 'la tarea', 'el hábito', 'el habito',
      'tarea', 'hábito', 'habito', 'como', 'de',
    ];

    for (final w in removeWords) {
      cleaned = cleaned.replaceAll(w, ' ');
    }

    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _cleanTitle(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(6) // máximo 6 palabras como título
        .join(' ')
        .trim();
  }

  List<int>? _parseTimeFromTextNullable(String text) {
    final t = text.toLowerCase();
    if (!RegExp(r'\d{1,2}(:\d{2})?\s*(am|pm)?|de la (mañana|tarde|noche)').hasMatch(t)) {
      return null; // No se mencionó hora
    }
    return _parseTimeFromText(text);
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final diff = DateTime(date.year, date.month, date.day)
        .difference(DateTime(now.year, now.month, now.day)).inDays;

    if (diff == 0) return 'hoy';
    if (diff == 1) return 'mañana';
    if (diff == 2) return 'pasado mañana';

    const months = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
    return '${date.day} de ${months[date.month - 1]}';
  }

  QueryDocumentSnapshot? _findBestMatch(List<QueryDocumentSnapshot> docs, String searchName) {
    final search = searchName.toLowerCase().trim();
    if (search.isEmpty || docs.isEmpty) return null;

    // 1. Coincidencia exacta
    for (final doc in docs) {
      final title = ((doc.data() as Map)['title'] ?? '').toString().toLowerCase();
      if (title == search) return doc;
    }

    // 2. El título contiene la búsqueda completa
    for (final doc in docs) {
      final title = ((doc.data() as Map)['title'] ?? '').toString().toLowerCase();
      if (title.contains(search)) return doc;
    }

    // 3. La búsqueda contiene el título
    for (final doc in docs) {
      final title = ((doc.data() as Map)['title'] ?? '').toString().toLowerCase();
      if (search.contains(title) && title.isNotEmpty) return doc;
    }

    // 4. Coincidencia por palabras compartidas (al menos 1 palabra en común de 3+ letras)
    final searchWords = search.split(' ').where((w) => w.length >= 3).toSet();
    QueryDocumentSnapshot? bestMatch;
    int bestScore = 0;

    for (final doc in docs) {
      final title = ((doc.data() as Map)['title'] ?? '').toString().toLowerCase();
      final titleWords = title.split(' ').where((w) => w.length >= 3).toSet();
      final commonWords = searchWords.intersection(titleWords).length;
      if (commonWords > bestScore) {
        bestScore = commonWords;
        bestMatch = doc;
      }
    }

    return bestScore > 0 ? bestMatch : null;
  }

  // Voz
  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  // Sonidos para feedback
  Future<void> _playStartSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/start_listening.mp3'));
    } catch (e) {
      print('Error reproduciendo sonido: $e');
    }
  }

  Future<void> _playStopSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/stop_listening.mp3'));
    } catch (e) {
      print('Error reproduciendo sonido: $e');
    }
  }

  Future<void> _playErrorSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/error_sound.mp3'));
    } catch (e) {
      print('Error reproduciendo sonido: $e');
    }
  }

  //acciones
  Future<void> _updateHabitStreaks() async {
    final uid = widget.user.uid;
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('habits')
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final List completedDates = List.from(data['completedDates'] ?? []);
      final newStreak = _calculateStreak(completedDates);
      final currentStreak = data['streak'] ?? 0;

      if (newStreak != currentStreak) {
        await doc.reference.update({'streak': newStreak});
      }
    }
  }

  int _calculateStreak(List dates) {
    if (dates.isEmpty) return 0;
    try {
      final sorted = dates
          .map((d) => DateTime.parse(d.toString()))
          .toList()
        ..sort((a, b) => b.compareTo(a));

      int streak = 0;
      DateTime check = DateTime.now();
      for (final d in sorted) {
        final day = DateTime(d.year, d.month, d.day);
        final checkDay = DateTime(check.year, check.month, check.day);
        final diff = checkDay.difference(day).inDays;
        if (diff <= 1) {
          streak++;
          check = day;
        } else {
          break;
        }
      }
      return streak;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _completeTaskFromCommand(String text) async {
    final searchName = _extractItemName(text);
    if (searchName.isEmpty) {
      _endFlow('❓ No entendí qué tarea marcar.');
      return;
    }

    _voiceTextNotifier.value = '🔍 Buscando tarea "$searchName"...';

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('tasks')
          .where('completed', isEqualTo: false)
          .get();

      final match = _findBestMatch(snap.docs, searchName);

      if (match == null) {
        _endFlow('❌ No encontré ninguna tarea pendiente llamada "$searchName".');
        return;
      }

      await match.reference.update({'completed': true});

      // Cancelar notificaciones de esa tarea
      await NotificationService().cancelTaskReminder(
        NotificationService().idFromDocId(match.id),
      );

      final title = (match.data() as Map)['title'] ?? searchName;
      _endFlow('✅ Tarea "$title" marcada como completada.');
    } catch (e) {
      _endFlow('❌ Error al completar la tarea.');
    }
  }

  Future<void> _completeHabitFromCommand(String text) async {
    final searchName = _extractItemName(text);
    if (searchName.isEmpty) {
      _endFlow('❓ No entendí qué hábito marcar.');
      return;
    }

    _voiceTextNotifier.value = '🔍 Buscando hábito "$searchName"...';

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('habits')
          .get();

      final match = _findBestMatch(snap.docs, searchName);

      if (match == null) {
        _endFlow('❌ No encontré ningún hábito llamado "$searchName".');
        return;
      }

      final data = match.data() as Map<String, dynamic>;
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
      final List dates = List.from(data['completedDates'] ?? []);

      if (dates.contains(dateStr)) {
        _endFlow('ℹ️ El hábito "${data['title']}" ya estaba marcado hoy.');
        return;
      }

      dates.add(dateStr);
      final streak = _calculateStreak(dates);

      await match.reference.update({
        'completedDates': dates,
        'streak': streak,
      });

      final title = data['title'] ?? searchName;
      _endFlow('✅ Hábito "$title" completado. Racha de $streak días.');
    } catch (e) {
      _endFlow('❌ Error al completar el hábito.');
    }
  }

  Future<void> _completeAnyFromCommand(String text) async {
    final searchName = _extractItemName(text);
    if (searchName.isEmpty) {
      _endFlow('❓ No entendí qué quieres marcar.');
      return;
    }

    _voiceTextNotifier.value = '🔍 Buscando "$searchName"...';

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;

      // Buscar primero en tareas
      final tasksSnap = await db.collection('users').doc(uid).collection('tasks')
          .where('completed', isEqualTo: false).get();
      final taskMatch = _findBestMatch(tasksSnap.docs, searchName);

      if (taskMatch != null) {
        await taskMatch.reference.update({'completed': true});
        await NotificationService().cancelTaskReminder(
          NotificationService().idFromDocId(taskMatch.id),
        );
        final title = (taskMatch.data() as Map)['title'] ?? searchName;
        _endFlow('✅ Tarea "$title" marcada como completada.');
        return;
      }

      // Si no, buscar en hábitos
      final habitsSnap = await db.collection('users').doc(uid).collection('habits').get();
      final habitMatch = _findBestMatch(habitsSnap.docs, searchName);

      if (habitMatch != null) {
        final data = habitMatch.data() as Map<String, dynamic>;
        final today = DateTime.now();
        final dateStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
        final List dates = List.from(data['completedDates'] ?? []);

        if (dates.contains(dateStr)) {
          _endFlow('ℹ️ El hábito "${data['title']}" ya estaba marcado hoy.');
          return;
        }

        dates.add(dateStr);
        final streak = _calculateStreak(dates);
        await habitMatch.reference.update({'completedDates': dates, 'streak': streak});

        final title = data['title'] ?? searchName;
        _endFlow('✅ Hábito "$title" completado. Racha de $streak días.');
        return;
      }

      _endFlow('❌ No encontré ninguna tarea ni hábito llamado "$searchName".');
    } catch (e) {
      _endFlow('❌ Error al buscar el elemento.');
    }
  }

  // UI
  Widget _buildTabBar() {
    final tabs = [
      (Icons.home_rounded, 'Inicio'),
      (Icons.check_circle_outline_rounded, 'Tareas'),
      (Icons.loop_rounded, 'Hábitos'),
      (Icons.notifications_none_rounded, 'Alertas'),
      (Icons.bar_chart_rounded, 'Stats'),
    ];
    final colors = [
      _accent,
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _selectedTab == i;
          final color = colors[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? color.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(tabs[i].$1, color: selected ? color : const Color(0xFF4B5563), size: 20),
                    const Gap(4),
                    Text(tabs[i].$2, style: GoogleFonts.sora(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected ? color : const Color(0xFF4B5563),
                    )),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildListTab({
    required String collection,
    required Color color,
    required IconData icon,
    required String emptyMsg,
    required Widget Function(Map<String, dynamic>, String) itemBuilder,
  }) {
    final uid = widget.user.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).collection(collection)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: color, strokeWidth: 2));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color.withOpacity(0.3), size: 56),
                const Gap(16),
                Text(emptyMsg, style: GoogleFonts.sora(color: const Color(0xFF4B5563), fontSize: 15)),
              ],
            ),
          );
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) => itemBuilder(docs[i].data() as Map<String, dynamic>, docs[i].id),
        );
      },
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> data, String id) {
    final completed = data['completed'] ?? false;
    final priority = data['priority'] ?? 'Media';
    final priorityColors = {'Alta': const Color(0xFFEF4444), 'Media': const Color(0xFFF59E0B), 'Baja': const Color(0xFF10B981)};
    final color = priorityColors[priority] ?? const Color(0xFFF59E0B);
    final dt = (data['dueDate'] as Timestamp?)?.toDate();
    final dateStr = dt != null
        ? '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
        : '';

    return
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => TaskDetailScreen(taskId: id, data: data),
        )),
        child:
        Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('users').doc(widget.user.uid).collection('tasks').doc(id)
                    .update({'completed': !completed});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: completed ? _accent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: completed ? _accent : const Color(0xFF4B5563), width: 2),
                ),
                child: completed ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
              ),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title'] ?? '', style: GoogleFonts.sora(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: completed ? const Color(0xFF4B5563) : Colors.white,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  )),
                  if ((data['description'] ?? '').isNotEmpty) ...[
                    const Gap(3),
                    Text(data['description'], style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFF6B7280))),
                  ],
                ],
              ),
            ),
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(priority, style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitItem(Map<String, dynamic> data, String id) {
    final streak = data['streak'] ?? 0;
    final icon = data['icon'] ?? '💪';
    final frequency = data['frequency'] ?? 'Diario';
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
    final completedDates = List.from(data['completedDates'] ?? []);
    final isDone = completedDates.contains(todayStr);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => HabitDetailScreen(habitId: id, data: data))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDone
                ? const Color(0xFF10B981).withOpacity(0.3)
                : const Color(0xFF1F2937),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 1.5),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title'] ?? '', style: GoogleFonts.sora(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: isDone ? const Color(0xFF6B7280) : Colors.white,
                      decoration: isDone ? TextDecoration.lineThrough : null)),
                  const Gap(3),
                  Text(frequency, style: GoogleFonts.sora(
                      fontSize: 12, color: const Color(0xFF6B7280))),
                ],
              ),
            ),
            const Gap(8),
            Column(
              children: [
                Text('$streak', style: GoogleFonts.sora(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: const Color(0xFF10B981))),
                Text('racha', style: GoogleFonts.sora(
                    fontSize: 10, color: const Color(0xFF6B7280))),
              ],
            ),
            const Gap(12),
            // ← Botón check
            GestureDetector(
              onTap: () async {
                final List dates = List.from(data['completedDates'] ?? []);
                if (isDone) {
                  dates.remove(todayStr);
                } else {
                  dates.add(todayStr);
                }
                final streak = _calculateStreak(dates);
                await FirebaseFirestore.instance
                    .collection('users').doc(widget.user.uid)
                    .collection('habits').doc(id)
                    .update({'completedDates': dates, 'streak': streak});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFF10B981) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone ? const Color(0xFF10B981) : const Color(0xFF4B5563),
                    width: 1.5,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderItem(Map<String, dynamic> data, String id) {
    final dt = (data['dateTime'] as Timestamp?)?.toDate();
    final repeat = data['repeat'] ?? 'No repetir';
    final active = data['active'] ?? true;
    final dateStr = dt != null
        ? '${dt.day}/${dt.month}/${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';

    return
      GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ReminderDetailScreen(reminderId: id, data: data),
          )),
            child:
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? const Color(0xFFF59E0B).withOpacity(0.3) : const Color(0xFF1F2937),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(Icons.notifications_none_rounded, color: Color(0xFFF59E0B), size: 22),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['title'] ?? '', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                    const Gap(3),
                    Text(dateStr.isNotEmpty ? '$dateStr  •  $repeat' : repeat,
                        style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFF6B7280))),
                  ],
                ),
              ),
              const Gap(8),
              GestureDetector(
                onTap: () async {
                  await FirebaseFirestore.instance
                      .collection('users').doc(widget.user.uid).collection('reminders').doc(id)
                      .update({'active': !active});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36, height: 20,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFF59E0B) : const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: active ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 16, height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildFAB() {
    final screens = [null, const AddTaskScreen(), const AddHabitScreen(), const AddReminderScreen()];
    final colors = [_accent, const Color(0xFF6366F1), const Color(0xFF10B981), const Color(0xFFF59E0B)];
    final screen = screens[_selectedTab];
    if (screen == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors[_selectedTab], colors[_selectedTab].withOpacity(0.7)]),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: colors[_selectedTab].withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildCompletedTaskItem(Map<String, dynamic> data, String id) {
    final priority = data['priority'] ?? 'Media';
    final priorityColors = {
      'Alta': const Color(0xFFEF4444),
      'Media': const Color(0xFFF59E0B),
      'Baja': const Color(0xFF10B981),
    };
    final color = priorityColors[priority] ?? const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF6366F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title'] ?? '',
                    style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                        decoration: TextDecoration.lineThrough,
                        decorationColor: const Color(0xFF6B7280))),
                if ((data['description'] ?? '').isNotEmpty) ...[
                  const Gap(3),
                  Text(data['description'], style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFF4B5563))),
                ],
              ],
            ),
          ),
          const Gap(8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(priority, style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: color.withOpacity(0.6))),
              ),
              const Gap(8),
              // Restaurar tarea
              GestureDetector(
                onTap: () async {
                  await FirebaseFirestore.instance
                      .collection('users').doc(widget.user.uid).collection('tasks').doc(id)
                      .update({'completed': false});
                },
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.undo_rounded, color: Color(0xFF9CA3AF), size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPastReminderItem(Map<String, dynamic> data, String id) {
    final dt = (data['dateTime'] as Timestamp?)?.toDate();
    final repeat = data['repeat'] ?? 'No repetir';
    final dateStr = dt != null
        ? '${dt.day}/${dt.month}/${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.15), width: 1.5),
            ),
            child: const Icon(Icons.notifications_off_outlined, color: Color(0xFF6B7280), size: 20),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title'] ?? '',
                    style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280))),
                const Gap(3),
                Text(dateStr.isNotEmpty ? '$dateStr  •  $repeat' : repeat,
                    style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFF4B5563))),
              ],
            ),
          ),
          const Gap(8),
          // Eliminar
          GestureDetector(
            onTap: () async {
              await FirebaseFirestore.instance
                  .collection('users').doc(widget.user.uid).collection('reminders').doc(id)
                  .delete();
            },
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    final uid = widget.user.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).collection('tasks')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1), strokeWidth: 2));
        }
        final docs = snap.data?.docs ?? [];
        final pending = docs.where((d) => (d.data() as Map)['completed'] != true).toList();
        final completed = docs.where((d) => (d.data() as Map)['completed'] == true).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline_rounded, color: const Color(0xFF6366F1).withOpacity(0.3), size: 56),
              const Gap(16),
              Text('No tienes tareas', style: GoogleFonts.sora(color: const Color(0xFF4B5563), fontSize: 15)),
            ]),
          );
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Pendientes
            if (pending.isNotEmpty) ...[
              _historyLabel('PENDIENTES', const Color(0xFF6366F1)),
              const Gap(10),
              ...pending.map((d) => _buildTaskItem(d.data() as Map<String, dynamic>, d.id)),
            ],

            // Completadas (ocultas)
            if (completed.isNotEmpty) ...[
              const Gap(16),
              _buildCollapsibleSection(
                label: 'COMPLETADAS (${completed.length})',
                color: const Color(0xFF4B5563),
                children: completed.map((d) => _buildCompletedTaskItem(d.data() as Map<String, dynamic>, d.id)).toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRemindersTab() {
    final uid = widget.user.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).collection('reminders')
          .orderBy('dateTime', descending: false)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B), strokeWidth: 2));
        }
        final now = DateTime.now();
        final docs = snap.data?.docs ?? [];
        final upcoming = docs.where((d) {
          final dt = ((d.data() as Map)['dateTime'] as Timestamp?)?.toDate();
          return dt != null && dt.isAfter(now);
        }).toList();
        final past = docs.where((d) {
          final dt = ((d.data() as Map)['dateTime'] as Timestamp?)?.toDate();
          return dt != null && dt.isBefore(now);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.notifications_none_rounded, color: const Color(0xFFF59E0B).withOpacity(0.3), size: 56),
              const Gap(16),
              Text('No tienes recordatorios', style: GoogleFonts.sora(color: const Color(0xFF4B5563), fontSize: 15)),
            ]),
          );
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (upcoming.isNotEmpty) ...[
              _historyLabel('PRÓXIMOS', const Color(0xFFF59E0B)),
              const Gap(10),
              ...upcoming.map((d) => _buildReminderItem(d.data() as Map<String, dynamic>, d.id)),
            ],
            if (past.isNotEmpty) ...[
              const Gap(16),
              _buildCollapsibleSection(
                label: 'PASADOS (${past.length})',
                color: const Color(0xFF4B5563),
                children: past.map((d) => _buildPastReminderItem(d.data() as Map<String, dynamic>, d.id)).toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildActiveHabitsWidget() {
    final uid = widget.user.uid;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).collection('habits')
          .where('active', isEqualTo: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const SizedBox.shrink();

        // Filtrar hábitos relevantes para hoy
        final todayWeekday = now.weekday - 1; // 0=Lunes
        final todayStr = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';

        final habits = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final days = List<int>.from(data['days'] ?? [0,1,2,3,4,5,6]);
          final endH = data['endHour'] as int? ?? 23;
          final endM = data['endMinute'] as int? ?? 59;
          final endMin = endH * 60 + endM;
          // Mostrar si es día activo y no ha terminado hace más de 1 hora
          return days.contains(todayWeekday) && endMin >= nowMin - 60;
        }).toList();

        if (habits.isEmpty) return const SizedBox.shrink();

        // Ordenar por hora de inicio
        habits.sort((a, b) {
          final aH = (a.data() as Map)['startHour'] as int? ?? 0;
          final bH = (b.data() as Map)['startHour'] as int? ?? 0;
          return aH.compareTo(bH);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('HÁBITOS DE HOY'),
            const Gap(12),
            Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
              ),
              child: Column(
                children: [
                  // Banner hora actual
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.2), width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          'Ahora — ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
                          style: GoogleFonts.sora(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ),
                  const Gap(8),
                  // Lista de hábitos
                  ...habits.asMap().entries.map((entry) {
                    final data = entry.value.data() as Map<String, dynamic>;
                    final docId = entry.value.id;
                    final startH = data['startHour'] as int? ?? 8;
                    final startM = data['startMinute'] as int? ?? 0;
                    final endH = data['endHour'] as int? ?? 9;
                    final endM = data['endMinute'] as int? ?? 0;
                    final startMin = startH * 60 + startM;
                    final endMin = endH * 60 + endM;
                    final isActive = nowMin >= startMin && nowMin < endMin;
                    final isNext = !isActive && startMin > nowMin && startMin - nowMin <= 60;
                    final isPast = endMin < nowMin;
                    final completedDates = List.from(data['completedDates'] ?? []);
                    final isDone = completedDates.contains(todayStr);

                    final startStr = '${startH.toString().padLeft(2,'0')}:${startM.toString().padLeft(2,'0')}';
                    final endStr = '${endH.toString().padLeft(2,'0')}:${endM.toString().padLeft(2,'0')}';
                    final diffMin = endMin - startMin;
                    final durStr = diffMin < 60
                        ? '${diffMin}min'
                        : '${diffMin ~/ 60}h${diffMin % 60 != 0 ? ' ${diffMin % 60}min' : ''}';

                    final colors = [
                      const Color(0xFF6366F1), const Color(0xFF10B981),
                      const Color(0xFFF59E0B), const Color(0xFFEC4899),
                      const Color(0xFF3B82F6),
                    ];
                    final color = colors[entry.key % colors.length];

                    return Opacity(
                      opacity: isPast && !isDone ? 0.5 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: entry.key < habits.length - 1
                                  ? const Color(0xFF1F2937)
                                  : Colors.transparent,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Hora
                            SizedBox(
                              width: 52,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(startStr, style: GoogleFonts.sora(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                                  Text(endStr, style: GoogleFonts.sora(
                                      fontSize: 11,
                                      color: const Color(0xFF6B7280))),
                                ],
                              ),
                            ),
                            const Gap(10),
                            // Barra de color
                            Container(
                              width: 3,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDone
                                    ? const Color(0xFF10B981)
                                    : isActive
                                    ? color
                                    : isNext
                                    ? color.withOpacity(0.5)
                                    : const Color(0xFF1F2937),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const Gap(10),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${data['icon'] ?? '💪'} ${data['title'] ?? ''}',
                                    style: GoogleFonts.sora(
                                        fontSize: 14, fontWeight: FontWeight.w600,
                                        color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Gap(2),
                                  Text(
                                    '${data['frequency'] ?? 'Diario'} · $durStr',
                                    style: GoogleFonts.sora(
                                        fontSize: 11,
                                        color: const Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                            const Gap(8),
                            // Badge activo/próximo
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: color.withOpacity(0.4), width: 1),
                                ),
                                child: Text('Ahora',
                                    style: GoogleFonts.sora(
                                        fontSize: 10, fontWeight: FontWeight.w700,
                                        color: color)),
                              )
                            else if (isNext)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFF59E0B).withOpacity(0.3),
                                      width: 1),
                                ),
                                child: Text('En breve',
                                    style: GoogleFonts.sora(
                                        fontSize: 10, fontWeight: FontWeight.w700,
                                        color: const Color(0xFFF59E0B))),
                              ),
                            const Gap(8),
                            // Botón check
                            GestureDetector(
                              onTap: () async {
                                final List dates = List.from(data['completedDates'] ?? []);
                                if (isDone) {
                                  dates.remove(todayStr);
                                } else {
                                  dates.add(todayStr);
                                }
                                final streak = _calculateStreak(dates);
                                await FirebaseFirestore.instance
                                    .collection('users').doc(uid)
                                    .collection('habits').doc(docId)
                                    .update({
                                  'completedDates': dates,
                                  'streak': streak,
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 30, height: 30,
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? const Color(0xFF10B981)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDone
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF4B5563),
                                    width: 1.5,
                                  ),
                                ),
                                child: isDone
                                    ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ).animate().fadeIn(delay: 350.ms, duration: 500.ms);
      },
    );
  }

  Widget _historyLabel(String label, Color color) {
    return Text(label,
        style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700,
            color: color, letterSpacing: 1.2));
  }

  Widget _buildCollapsibleSection({
    required String label,
    required Color color,
    required List<Widget> children,
  }) {
    return _CollapsibleSection(label: label, color: color, children: children);
  }

  Widget _buildFullList({
    required String collection,
    required Color color,
    required IconData icon,
    required String emptyMsg,
    required Widget Function(Map<String, dynamic>, String) itemBuilder,
    bool Function(Map<String, dynamic>)? filter,
  }) {
    final uid = widget.user.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).collection(collection)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ));
        }
        var docs = snap.data?.docs ?? [];
        if (filter != null) {
          docs = docs.where((d) => filter(d.data() as Map<String, dynamic>)).toList();
        }
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
            ),
            child: Center(child: Text(emptyMsg,
                style: GoogleFonts.sora(color: const Color(0xFF4B5563), fontSize: 13))),
          );
        }
        return Column(
          children: docs.map((d) =>
              itemBuilder(d.data() as Map<String, dynamic>, d.id)).toList(),
        );
      },
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.sora(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF6B7280),
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildHomeContent() {
    final displayName = widget.user.email?.split('@').first ?? 'Usuario';
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(32),
          _buildGreeting(displayName),
          const Gap(28),
          _sectionLabel('TAREAS PENDIENTES'),
          const Gap(12),
          _buildFullList(
            collection: 'tasks',
            color: const Color(0xFF6366F1),
            icon: Icons.check_circle_outline_rounded,
            emptyMsg: 'Sin tareas pendientes',
            itemBuilder: _buildTaskItem,
            filter: (data) => data['completed'] != true,
          ),
          const Gap(24),
          _sectionLabel('HÁBITOS'),
          const Gap(12),
          _buildFullList(
            collection: 'habits',
            color: const Color(0xFF10B981),
            icon: Icons.loop_rounded,
            emptyMsg: 'Sin hábitos',
            itemBuilder: _buildHabitItem,
          ),
          const Gap(24),
          _sectionLabel('RECORDATORIOS'),
          const Gap(12),
          _buildFullList(
            collection: 'reminders',
            color: const Color(0xFFF59E0B),
            icon: Icons.notifications_none_rounded,
            emptyMsg: 'Sin recordatorios',
            itemBuilder: _buildReminderItem,
            filter: (data) => data['active'] == true,
          ),
          const Gap(12),
          _buildSectionLabel('¿Qué quieres hacer?'),
          const Gap(20),
          _buildCards(),
          const Gap(36),
          _buildSectionLabel('Resumen de hoy'),
          const Gap(16),
          _buildSummaryRow(),
          const Gap(32),
          _buildSignOutButton(),
          const Gap(32),
        ],
      ),
    );
  }

  // ── Barra de voz ─────────────────────────────────────────────────────────────
  Widget _buildVoiceBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isListening ? _accent.withOpacity(0.6) : const Color(0xFF1F2937),
          width: 1.5,
        ),
        boxShadow: _isListening
            ? [BoxShadow(color: _accent.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)]
            : [],
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
          ),
          const Gap(12),

          // Solo este Text se reconstruye con cada palabra, no toda la pantalla
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _voiceTextNotifier,
              builder: (_, text, __) => Text(
                text,
                style: GoogleFonts.sora(
                  fontSize: 13,
                  color: _isListening ? Colors.white : const Color(0xFF6B7280),
                  fontWeight: _isListening ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ),

          if (_isListening) ...[
            _WaveIndicator(controller: _pulseCtrl),
            const Gap(10),
          ],

          GestureDetector(
            onTap: _toggleListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _isListening ? _accent : const Color(0xFF1F2937),
                shape: BoxShape.circle,
                boxShadow: _isListening
                    ? [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 12, spreadRadius: 1)]
                    : [],
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isListening ? Colors.white : const Color(0xFF9CA3AF),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.3, curve: Curves.easeOut);
  }

  // ── Saludo ────────────────────────────────────────────────────────────────────
  Widget _buildGreeting(String name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Buenos días' : hour < 18 ? 'Buenas tardes' : 'Buenas noches';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting,',
          style: GoogleFonts.sora(fontSize: 16, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w400),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
        const Gap(4),
        Text(
          name,
          style: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5),
        ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideX(begin: -0.1),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280), letterSpacing: 1.1),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }

  // ── Cards de secciones ────────────────────────────────────────────────────────
  Widget _buildCards() {
    return Column(
      children: List.generate(_sections.length, (i) {
        final s = _sections[i];
        return Padding(
          padding: EdgeInsets.only(bottom: i < _sections.length - 1 ? 16 : 0),
          child: _SectionCard(data: s, index: i),
        );
      }),
    );
  }

  // ── Resumen rápido ────────────────────────────────────────────────────────────s
  Widget _buildSummaryRow() {
    final uid = widget.user.uid;
    final db = FirebaseFirestore.instance;

    return StreamBuilder<List<int>>(
      stream: Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
        final results = await Future.wait([
          db.collection('users').doc(uid).collection('tasks')
              .where('completed', isEqualTo: false).get(),
          db.collection('users').doc(uid).collection('habits').get(),
          db.collection('users').doc(uid).collection('reminders')
              .where('active', isEqualTo: true).get(),
        ]);
        return results.map((r) => r.docs.length).toList();
      }),
      builder: (context, snapshot) {
        final counts = snapshot.data ?? [0, 0, 0];
        return Row(
          children: [
            _StatChip(label: 'Tareas', value: '${counts[0]}', color: const Color(0xFF6366F1)),
            const Gap(12),
            _StatChip(label: 'Hábitos', value: '${counts[1]}', color: const Color(0xFF10B981)),
            const Gap(12),
            _StatChip(label: 'Alertas', value: '${counts[2]}', color: const Color(0xFFF59E0B)),
          ],
        );
      },
    ).animate().fadeIn(delay: 700.ms, duration: 500.ms).slideY(begin: 0.2);
  }

  // ── Botón cerrar sesión ───────────────────────────────────────────────────────
  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () async {
          await PersistentNotificationService().stop();
          await NotificationService().cancelAllUserNotifications();
          await AuthService().signOut();
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        },
        icon: const Icon(Icons.logout_rounded, color: Color(0xFF6B7280), size: 18),
        label: Text('Cerrar sesión', style: GoogleFonts.sora(color: const Color(0xFF6B7280), fontSize: 14, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF1F2937), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ).animate().fadeIn(delay: 800.ms, duration: 400.ms);
  }

  Widget _buildStatsTab() {
    final uid = widget.user.uid;
    final db = FirebaseFirestore.instance;

    return FutureBuilder<List<QuerySnapshot>>(
      future: Future.wait([
        db.collection('users').doc(uid).collection('tasks').get(),
        db.collection('users').doc(uid).collection('habits').get(),
        db.collection('users').doc(uid).collection('reminders').get(),
      ]),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFEC4899),
              strokeWidth: 2,
            ),
          );
        }

        if (snap.hasError || !snap.hasData) {
          return Center(
            child: Text('Error al cargar datos',
                style: GoogleFonts.sora(color: const Color(0xFF6B7280))),
          );
        }

        final tasks = snap.data![0].docs;
        final habits = snap.data![1].docs;
        final reminders = snap.data![2].docs;

        // Construir mapa de actividad una sola vez
        final Map<String, List<String>> dayActivity = {};

        for (final d in tasks) {
          final data = d.data() as Map<String, dynamic>;
          final dt = (data['dueDate'] as Timestamp?)?.toDate();
          if (dt != null) {
            dayActivity.putIfAbsent(_dayKey(dt), () => []).add('task');
          }
        }

        for (final d in habits) {
          final data = d.data() as Map<String, dynamic>;
          for (final dateStr in List.from(data['completedDates'] ?? [])) {
            try {
              final dt = DateTime.parse(dateStr.toString());
              dayActivity.putIfAbsent(_dayKey(dt), () => []).add('habit');
            } catch (_) {}
          }
        }

        for (final d in reminders) {
          final data = d.data() as Map<String, dynamic>;
          final dt = (data['dateTime'] as Timestamp?)?.toDate();
          if (dt != null) {
            dayActivity.putIfAbsent(_dayKey(dt), () => []).add('reminder');
          }
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGlobalStats(tasks, habits, reminders)
                  .animate().fadeIn(duration: 400.ms),
              const Gap(24),
              _buildCalendarSection(dayActivity)
                  .animate().fadeIn(delay: 150.ms, duration: 400.ms),
              const Gap(24),
              _buildDayDetail(
                selectedDay: _selectedDay,
                tasks: tasks,
                habits: habits,
                reminders: reminders,
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
              const Gap(32),
            ],
          ),
        );
      },
    );
  }

  String _dayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Widget _buildGlobalStats(List tasks, List habits, List reminders) {
    final completedTasks = tasks.where((d) => (d.data() as Map)['completed'] == true).length;
    final pendingTasks = tasks.length - completedTasks;
    final totalStreak = habits.fold<int>(0, (sum, d) => sum + ((d.data() as Map)['streak'] as int? ?? 0));
    final activeReminders = reminders.where((d) => (d.data() as Map)['active'] == true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RESUMEN GLOBAL', style: GoogleFonts.sora(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(12),
        Row(
          children: [
            _globalStatCard('$completedTasks', 'Completadas', Icons.check_circle_rounded, const Color(0xFF6366F1)),
            const Gap(10),
            _globalStatCard('$pendingTasks', 'Pendientes', Icons.pending_rounded, const Color(0xFFF59E0B)),
          ],
        ),
        const Gap(10),
        Row(
          children: [
            _globalStatCard('$totalStreak', 'Racha total', Icons.local_fire_department_rounded, const Color(0xFFEF4444)),
            const Gap(10),
            _globalStatCard('$activeReminders', 'Alertas', Icons.notifications_active_rounded, const Color(0xFF10B981)),
          ],
        ),
      ],
    );
  }

  Widget _globalStatCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Gap(12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                Text(label, style: GoogleFonts.sora(fontSize: 11, color: const Color(0xFF6B7280))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection(Map<String, List<String>> dayActivity) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startWeekday = firstDay.weekday - 1;
    const months = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CALENDARIO', style: GoogleFonts.sora(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
          ),
          child: Column(
            children: [
              // Navegación mes
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() {
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                    }),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.chevron_left_rounded, color: Color(0xFF9CA3AF), size: 20),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${months[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                    }),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 20),
                    ),
                  ),
                ],
              ),
              const Gap(16),

              // Encabezado días
              Row(
                children: ['L','M','X','J','V','S','D'].map((d) => Expanded(
                  child: Center(child: Text(d, style: GoogleFonts.sora(
                      fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF4B5563)))),
                )).toList(),
              ),
              const Gap(8),

              // Grid de días
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
                itemCount: startWeekday + daysInMonth,
                itemBuilder: (_, i) {
                  if (i < startWeekday) return const SizedBox.shrink();
                  final day = i - startWeekday + 1;
                  final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
                  final key = _dayKey(date);
                  final activity = dayActivity[key] ?? [];
                  final isSelected = _selectedDay.year == date.year &&
                      _selectedDay.month == date.month &&
                      _selectedDay.day == date.day;
                  final isToday = now.year == date.year &&
                      now.month == date.month &&
                      now.day == date.day;
                  final hasTasks = activity.contains('task');
                  final hasHabits = activity.contains('habit');
                  final hasReminders = activity.contains('reminder');

                  return GestureDetector(
                    onTap: () => setState(() => _selectedDay = date),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEC4899)
                            : isToday
                            ? const Color(0xFFEC4899).withOpacity(0.15)
                            : const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFEC4899)
                              : isToday
                              ? const Color(0xFFEC4899).withOpacity(0.5)
                              : const Color(0xFF1F2937),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$day', style: GoogleFonts.sora(
                            fontSize: 12,
                            fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
                            color: isSelected ? Colors.white : isToday ? const Color(0xFFEC4899) : const Color(0xFF9CA3AF),
                          )),
                          if (hasTasks || hasHabits || hasReminders) ...[
                            const Gap(2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (hasTasks) _dot(const Color(0xFF6366F1)),
                                if (hasHabits) _dot(const Color(0xFF10B981)),
                                if (hasReminders) _dot(const Color(0xFFF59E0B)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),

              const Gap(12),
              // Leyenda
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendItem(const Color(0xFF6366F1), 'Tareas'),
                  const Gap(16),
                  _legendItem(const Color(0xFF10B981), 'Hábitos'),
                  const Gap(16),
                  _legendItem(const Color(0xFFF59E0B), 'Alertas'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dot(Color color) => Container(
    width: 5, height: 5,
    margin: const EdgeInsets.symmetric(horizontal: 1),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _legendItem(Color color, String label) => Row(
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const Gap(4),
      Text(label, style: GoogleFonts.sora(fontSize: 11, color: const Color(0xFF6B7280))),
    ],
  );

  Widget _buildDayDetail({
    required DateTime selectedDay,
    required List tasks,
    required List habits,
    required List reminders,
  }) {
    final key = _dayKey(selectedDay);
    const months = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];

    // Filtrar por día seleccionado
    final dayTasks = tasks.where((d) {
      final data = d.data() as Map<String, dynamic>;
      final dt = (data['dueDate'] as Timestamp?)?.toDate();
      return dt != null && _dayKey(dt) == key;
    }).toList();

    final dayHabits = habits.where((d) {
      final data = d.data() as Map<String, dynamic>;
      final dates = List.from(data['completedDates'] ?? []);
      return dates.any((ds) {
        try { return _dayKey(DateTime.parse(ds.toString())) == key; } catch (_) { return false; }
      });
    }).toList();

    final dayReminders = reminders.where((d) {
      final data = d.data() as Map<String, dynamic>;
      final dt = (data['dateTime'] as Timestamp?)?.toDate();
      return dt != null && _dayKey(dt) == key;
    }).toList();

    final hasAnything = dayTasks.isNotEmpty || dayHabits.isNotEmpty || dayReminders.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${selectedDay.day} ${months[selectedDay.month - 1]} ${selectedDay.year}'.toUpperCase(),
          style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700,
              color: const Color(0xFFEC4899), letterSpacing: 1.2),
        ),
        const Gap(12),

        if (!hasAnything)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
            ),
            child: Center(child: Text('Sin actividad este día',
                style: GoogleFonts.sora(color: const Color(0xFF4B5563), fontSize: 14))),
          ),

        // Tareas del día
        if (dayTasks.isNotEmpty) ...[
          _dayDetailLabel('TAREAS', const Color(0xFF6366F1)),
          const Gap(8),
          ...dayTasks.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final completed = data['completed'] ?? false;
            return _dayDetailItem(
              icon: completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              iconColor: completed ? const Color(0xFF10B981) : const Color(0xFF6366F1),
              title: data['title'] ?? '',
              subtitle: data['priority'] ?? '',
              borderColor: const Color(0xFF6366F1),
            );
          }),
          const Gap(12),
        ],

        // Hábitos del día
        if (dayHabits.isNotEmpty) ...[
          _dayDetailLabel('HÁBITOS COMPLETADOS', const Color(0xFF10B981)),
          const Gap(8),
          ...dayHabits.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return _dayDetailItem(
              icon: Icons.loop_rounded,
              iconColor: const Color(0xFF10B981),
              title: '${data['icon'] ?? ''} ${data['title'] ?? ''}',
              subtitle: data['frequency'] ?? '',
              borderColor: const Color(0xFF10B981),
            );
          }),
          const Gap(12),
        ],

        // Recordatorios del día
        if (dayReminders.isNotEmpty) ...[
          _dayDetailLabel('RECORDATORIOS', const Color(0xFFF59E0B)),
          const Gap(8),
          ...dayReminders.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final dt = (data['dateTime'] as Timestamp?)?.toDate();
            final timeStr = dt != null
                ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                : '';
            return _dayDetailItem(
              icon: Icons.notifications_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: data['title'] ?? '',
              subtitle: timeStr,
              borderColor: const Color(0xFFF59E0B),
            );
          }),
        ],
      ],
    );
  }

  Widget _dayDetailLabel(String label, Color color) => Text(label,
      style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 1.1));

  Widget _dayDetailItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color borderColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Definición de secciones ──────────────────────────────────────────────────
  final List<_SectionData> _sections = const [
    _SectionData(
      icon: Icons.check_circle_outline_rounded,
      label: 'Tareas',
      description: 'Organiza tus pendientes y completa tus metas diarias.',
      gradient: [Color(0xFF6366F1), Color(0xFF4F46E5)],
      glowColor: Color(0xFF6366F1),
      tag: 'tasks',
    ),
    _SectionData(
      icon: Icons.loop_rounded,
      label: 'Hábitos',
      description: 'Construye rutinas poderosas día a día.',
      gradient: [Color(0xFF10B981), Color(0xFF059669)],
      glowColor: Color(0xFF10B981),
      tag: 'habits',
    ),
    _SectionData(
      icon: Icons.notifications_none_rounded,
      label: 'Recordatorios',
      description: 'No olvides nada importante con alertas a tiempo.',
      gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
      glowColor: Color(0xFFF59E0B),
      tag: 'reminders',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BgPainter())),
          SafeArea(
            child: Column(
              children: [
                _buildVoiceBar(),
                const Gap(8),
                _buildTabBar(),
                Expanded(
                  child: _selectedTab == 0
                      ? _buildHomeContent()
                      : _selectedTab == 1
                      ? _buildTasksTab()
                      : _selectedTab == 2
                      ? _buildListTab(
                    collection: 'habits',
                    color: const Color(0xFF10B981),
                    icon: Icons.loop_rounded,
                    emptyMsg: 'No tienes hábitos registrados.',
                    itemBuilder: _buildHabitItem,
                  )
                      : _selectedTab == 3
                      ? _buildRemindersTab()
                      : _buildStatsTab(),
                ),

              ],
            ),
          ),
        ],
      ),
      floatingActionButton: (_selectedTab != 0 && _selectedTab != 4) ? _buildFAB() : null,
    );
  }


}

// ── Card de sección ───────────────────────────────────────────────────────────
class _SectionCard extends StatefulWidget {
  final _SectionData data;
  final int index;
  const _SectionCard({required this.data, required this.index});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Widget screen;
        switch (d.tag) {
          case 'tasks':
            screen = const AddTaskScreen();
            break;
          case 'habits':
            screen = const AddHabitScreen();
            break;
          case 'reminders':
            screen = const AddReminderScreen();
            break;
          default:
            return;
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: d.glowColor.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Ícono con gradiente
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: d.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: d.glowColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(d.icon, color: Colors.white, size: 26),
              ),
              const Gap(16),

              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.label,
                      style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const Gap(4),
                    Text(
                      d.description,
                      style: GoogleFonts.sora(fontSize: 13, color: const Color(0xFF6B7280), height: 1.4),
                    ),
                  ],
                ),
              ),
              const Gap(12),

              // Flecha
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.arrow_forward_ios_rounded, color: d.glowColor, size: 14),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 450 + widget.index * 100), duration: 500.ms).slideX(begin: 0.1, curve: Curves.easeOut);
  }
}

// ── Chip de estadística ───────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: color),
            ),
            const Gap(4),
            Text(
              label,
              style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Indicador de onda ─────────────────────────────────────────────────────────
class _WaveIndicator extends StatelessWidget {
  final AnimationController controller;
  const _WaveIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          children: List.generate(3, (i) {
            final offset = i * 0.25;
            final val = (controller.value + offset).clamp(0.0, 1.0);
            final height = 8.0 + val * 14.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Datos de sección ──────────────────────────────────────────────────────────
class _SectionData {
  final IconData icon;
  final String label;
  final String description;
  final List<Color> gradient;
  final Color glowColor;
  final String tag;

  const _SectionData({
    required this.icon,
    required this.label,
    required this.description,
    required this.gradient,
    required this.glowColor,
    required this.tag,
  });
}

// ── Fondo decorativo ──────────────────────────────────────────────────────────
class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF6366F1).withOpacity(0.08), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width, 0), radius: size.width * 0.8));
    canvas.drawCircle(Offset(size.width, 0), size.width * 0.8, p1);

    final p2 = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF10B981).withOpacity(0.06), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(0, size.height), radius: size.width * 0.7));
    canvas.drawCircle(Offset(0, size.height), size.width * 0.7, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CollapsibleSection extends StatefulWidget {
  final String label;
  final Color color;
  final List<Widget> children;
  const _CollapsibleSection({required this.label, required this.color, required this.children});

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Text(widget.label,
                  style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700,
                      color: widget.color, letterSpacing: 1.2)),
              const Gap(8),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: widget.color, size: 18),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              const Gap(10),
              ...widget.children,
            ],
          ),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}