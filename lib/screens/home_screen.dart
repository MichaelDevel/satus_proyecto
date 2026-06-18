import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:satus_proyecto/screens/habit_detail_screen.dart';
import 'package:satus_proyecto/screens/reminder_detail_screen.dart';
import 'package:satus_proyecto/screens/task_detail_screen.dart';
import 'package:satus_proyecto/services/notification_service.dart';
import '../services/voice_command_service.dart';
import 'adds/add_habit_screen.dart';
import 'adds/add_reminder_screen.dart';
import 'adds/add_task_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ── Colores ──────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF060A12);
  static const _surface = Color(0xFF0D1117);
  static const _accent = Color(0xFF6366F1);

  // ── Estado del micrófono ─────────────────────────────────────────────────────
  bool _isListening = false;
  String _voiceText = 'Toca el micrófono para hablar...';
  late AnimationController _pulseCtrl;
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;

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
    _updateHabitStreaks();
    NotificationService().rescheduleAll();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() {
            _isListening = false;
            _pulseCtrl.stop();
            _pulseCtrl.reset();
          });
        }
      },
      onError: (error) {
        if (mounted) setState(() {
          _isListening = false;
          _voiceText = 'Error: ${error.errorMsg}';
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        });
      },
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    if (!_speechAvailable) {
      setState(() => _voiceText = 'Micrófono no disponible.');
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _voiceText = 'Toca el micrófono para hablar...';
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      });
    } else {
      setState(() {
        _isListening = true;
        _voiceText = 'Escuchando...';
        _pulseCtrl.repeat(reverse: true);
      });

      await _speech.listen(
        onResult: (result) {
          setState(() => _voiceText = result.recognizedWords.isNotEmpty
              ? result.recognizedWords
              : 'Escuchando...');

          // Procesar cuando el reconocimiento es final
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _processVoiceCommand(result.recognizedWords);
          }
        },
        localeId: 'es_CO',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  void _processVoiceCommand(String text) async {
    final command = VoiceCommandService.parse(text);
    final desc = VoiceCommandService.description(command);

    setState(() {
      _isListening = false;
      _voiceText = desc;
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    });

    await _speech.stop();

    // Pequeña pausa para mostrar el feedback
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    switch (command) {
      case VoiceCommand.newTask:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTaskScreen()));
        break;
      case VoiceCommand.newHabit:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHabitScreen()));
        break;
      case VoiceCommand.newReminder:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddReminderScreen()));
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
      // Mostrar mensaje y resetear después de 2 segundos
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() => _voiceText = 'Toca el micrófono para hablar...');
        }
        break;
    }

    // Resetear texto después de ejecutar comando
    if (command != VoiceCommand.unknown && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _voiceText = 'Toca el micrófono para hablar...');
    }
  }

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

    return
      GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => HabitDetailScreen(habitId: id, data: data),
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
                    Text(data['title'] ?? '', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                    const Gap(3),
                    Text(frequency, style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFF6B7280))),
                  ],
                ),
              ),
              const Gap(8),
              Column(
                children: [
                  Text('$streak', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                  Text('racha', style: GoogleFonts.sora(fontSize: 10, color: const Color(0xFF6B7280))),
                ],
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
          const Gap(36),
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
          color: _isListening
              ? _accent.withOpacity(0.6)
              : const Color(0xFF1F2937),
          width: 1.5,
        ),
        boxShadow: _isListening
            ? [BoxShadow(color: _accent.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)]
            : [],
      ),
      child: Row(
        children: [
          // Ícono de asistente
          Container(
            width: 36,
            height: 36,
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

          // Texto de estado
          Expanded(
            child: Text(
              _voiceText,
              style: GoogleFonts.sora(
                fontSize: 13,
                color: _isListening
                    ? Colors.white
                    : const Color(0xFF6B7280),
                fontWeight: _isListening ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),

          // Indicador de onda cuando escucha
          if (_isListening) ...[
            _WaveIndicator(controller: _pulseCtrl),
            const Gap(10),
          ],

          // Botón micrófono
          GestureDetector(
            onTap: _toggleListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isListening
                    ? _accent
                    : const Color(0xFF1F2937),
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