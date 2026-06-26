import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

class HabitDetailScreen extends StatefulWidget {
  final String habitId;
  final Map<String, dynamic> data;
  const HabitDetailScreen({super.key, required this.habitId, required this.data});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;

  static const _bg = Color(0xFF060A12);
  static const _surface = Color(0xFF0D1117);
  static const _accent = Color(0xFF10B981);

  late String _frequency;
  late String _selectedIcon;
  late Set<int> _selectedDays;
  bool _isLoading = false;
  bool _editing = false;

  final List<String> _frequencies = ['Diario', 'Semanal', 'Mensual'];
  final List<String> _icons = ['💪', '📚', '🏃', '💧', '🧘', '🍎', '😴', '✍️', '🎯', '🧠', '🎵', '🌿'];
  final List<String> _days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.data['title'] ?? '');
    _descCtrl = TextEditingController(text: widget.data['description'] ?? '');
    _frequency = widget.data['frequency'] ?? 'Diario';
    _selectedIcon = widget.data['icon'] ?? '💪';
    final rawDays = widget.data['days'];
    _selectedDays = rawDays != null ? Set<int>.from(rawDays) : {0, 1, 2, 3, 4};
    _startTime = TimeOfDay(
      hour: widget.data['startHour'] as int? ?? widget.data['notifHour'] as int? ?? 8,
      minute: widget.data['startMinute'] as int? ?? widget.data['notifMinute'] as int? ?? 0,
    );
    _endTime = TimeOfDay(
      hour: widget.data['endHour'] as int? ?? 9,
      minute: widget.data['endMinute'] as int? ?? 0,
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  CollectionReference get _col => FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .collection('habits');

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _col.doc(widget.habitId).update({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'frequency': _frequency,
        'icon': _selectedIcon,
        'days': _selectedDays.toList()..sort(),
        'notifHour': _startTime.hour,
        'notifMinute': _startTime.minute,
        'startHour': _startTime.hour,
        'startMinute': _startTime.minute,
        'endHour': _endTime.hour,
        'endMinute': _endTime.minute,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() => _editing = false);
        _showSuccess('Hábito actualizado.');
      }
    } catch (_) {
      _showError('Error al actualizar.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await _confirmDialog('¿Eliminar hábito?', 'Esta acción no se puede deshacer.');
    if (!confirm) return;
    setState(() => _isLoading = true);
    try {
      await _col.doc(widget.habitId).delete();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showError('Error al eliminar.');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markToday() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Leer datos actuales de Firestore en lugar de widget.data
      final snap = await _col.doc(widget.habitId).get();
      final data = snap.data() as Map<String, dynamic>;
      final List dates = List.from(data['completedDates'] ?? []);

      if (dates.contains(dateStr)) {
        dates.remove(dateStr);
      } else {
        dates.add(dateStr);
      }

      final streak = _calculateStreak(dates);
      await _col.doc(widget.habitId).update({
        'completedDates': dates,
        'streak': streak,
      });
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calculateStreak(List dates) {
    if (dates.isEmpty) return 0;
    final sorted = dates.map((d) => DateTime.parse(d)).toList()..sort((a, b) => b.compareTo(a));
    int streak = 0;
    DateTime check = DateTime.now();
    for (final d in sorted) {
      final diff = check.difference(DateTime(d.year, d.month, d.day)).inDays;
      if (diff <= 1) { streak++; check = d; }
      else break;
    }
    return streak;
  }

  Future<bool> _confirmDialog(String title, String msg) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(msg, style: GoogleFonts.sora(color: const Color(0xFF9CA3AF))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: GoogleFonts.sora(color: const Color(0xFF6B7280)))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Confirmar', style: GoogleFonts.sora(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700))),
        ],
      ),
    ) ?? false;
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: GoogleFonts.sora(color: Colors.white)),
    backgroundColor: const Color(0xFFEF4444),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(16),
  ));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: GoogleFonts.sora(color: Colors.white)),
    backgroundColor: _accent,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(16),
  ));

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context, initialTime: _startTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(
            primary: Color(0xFF10B981), surface: Color(0xFF0D1117))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context, initialTime: _endTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(
            primary: Color(0xFF10B981), surface: Color(0xFF0D1117))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _col.doc(widget.habitId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(
          backgroundColor: Color(0xFF060A12),
          body: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
        );

        final data = snap.data!.data() as Map<String, dynamic>;
        final streak = data['streak'] ?? 0;
        final completedDates = List.from(data['completedDates'] ?? []);
        final today = DateTime.now();
        final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final doneToday = completedDates.contains(todayStr);

        return Scaffold(
          backgroundColor: _bg,
          body: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _BgPainter(_accent))),
              SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStreakCard(streak, doneToday, data).animate().fadeIn(delay: 150.ms),
                              const Gap(24),
                              _buildCalendar(completedDates).animate().fadeIn(delay: 200.ms),
                              const Gap(20),
                              _buildIconPicker().animate().fadeIn(delay: 250.ms),
                              const Gap(16),
                              _buildField(label: 'NOMBRE', controller: _titleCtrl, enabled: _editing,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                              const Gap(16),
                              _buildField(label: 'DESCRIPCIÓN', controller: _descCtrl, enabled: _editing, maxLines: 3),
                              const Gap(16),
                              _buildFrequencySelector().animate().fadeIn(delay: 400.ms),
                              const Gap(16),
                              if (_frequency != 'Mensual') _buildDaySelector().animate().fadeIn(delay: 500.ms),
                              const Gap(32),
                              _buildTimeRangeSelector().animate().fadeIn(delay: 550.ms),
                              const Gap(32),
                              _buildActions(doneToday, completedDates).animate().fadeIn(delay: 600.ms),
                              const Gap(24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeRangeSelector() {
    final startStr = '${_startTime.hour.toString().padLeft(2,'0')}:${_startTime.minute.toString().padLeft(2,'0')}';
    final endStr = '${_endTime.hour.toString().padLeft(2,'0')}:${_endTime.minute.toString().padLeft(2,'0')}';
    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = _endTime.hour * 60 + _endTime.minute;
    final diff = endMin - startMin;
    final duration = diff <= 0 ? '' : diff < 60 ? '${diff}min' : '${diff ~/ 60}h ${diff % 60 == 0 ? '' : '${diff % 60}min'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HORARIO', style: GoogleFonts.sora(fontSize: 11,
            fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF),
            letterSpacing: 1.2)),
        const Gap(10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _editing ? _pickStartTime : null,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.5), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inicio', style: GoogleFonts.sora(
                          fontSize: 11, color: const Color(0xFF6B7280))),
                      const Gap(4),
                      Text(startStr, style: GoogleFonts.sora(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981))),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.arrow_forward_rounded,
                  color: Color(0xFF10B981), size: 18),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _editing ? _pickEndTime : null,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.3), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fin', style: GoogleFonts.sora(
                          fontSize: 11, color: const Color(0xFF6B7280))),
                      const Gap(4),
                      Text(endStr, style: GoogleFonts.sora(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (duration.isNotEmpty) ...[
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timelapse_rounded,
                    color: Color(0xFF10B981), size: 14),
                const Gap(6),
                Text('Duración: $duration', style: GoogleFonts.sora(
                    fontSize: 12, color: const Color(0xFF10B981))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(width: 42, height: 42,
                decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937), width: 1.5)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF9CA3AF), size: 18)),
          ),
          const Spacer(),
          Text('Detalle de Hábito', style: GoogleFonts.sora(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: _editing ? _update : () => setState(() => _editing = true),
            child: Container(width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _editing ? _accent : _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _editing ? _accent : const Color(0xFF1F2937), width: 1.5),
                ),
                child: Icon(_editing ? Icons.check_rounded : Icons.edit_outlined,
                    color: _editing ? Colors.white : const Color(0xFF9CA3AF), size: 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(List completedDates) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final firstDay = DateTime(now.year, now.month, 1);
    final startWeekday = firstDay.weekday - 1; // 0=Lunes

    final completedSet = completedDates.map((d) => d.toString()).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HISTORIAL — ${_monthName(now.month).toUpperCase()} ${now.year}',
            style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(12),
        // Encabezado días semana
        Row(
          children: ['L','M','X','J','V','S','D'].map((d) => Expanded(
            child: Center(child: Text(d, style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF4B5563)))),
          )).toList(),
        ),
        const Gap(8),
        // Grid de días
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
          itemCount: startWeekday + daysInMonth,
          itemBuilder: (_, i) {
            if (i < startWeekday) return const SizedBox.shrink();
            final day = i - startWeekday + 1;
            final date = DateTime(now.year, now.month, day);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final done = completedSet.contains(dateStr);
            final isToday = day == now.day;
            final isFuture = date.isAfter(now);

            return GestureDetector(
              onTap: isFuture ? null : () => _toggleDate(dateStr, done),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: done
                      ? _accent
                      : isToday
                      ? _accent.withOpacity(0.2)
                      : const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isToday ? _accent : done ? _accent : const Color(0xFF1F2937),
                    width: isToday ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: isToday || done ? FontWeight.w700 : FontWeight.w400,
                      color: done ? Colors.white : isFuture ? const Color(0xFF2D3748) : isToday ? _accent : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _monthName(int month) {
    const months = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
    return months[month - 1];
  }

  Future<void> _toggleDate(String dateStr, bool currentlyDone) async {
    final snap = await _col.doc(widget.habitId).get();
    final data = snap.data() as Map<String, dynamic>;
    final List dates = List.from(data['completedDates'] ?? []);

    if (currentlyDone) {
      dates.remove(dateStr);
    } else {
      dates.add(dateStr);
    }

    final streak = _calculateStreak(dates);
    await _col.doc(widget.habitId).update({
      'completedDates': dates,
      'streak': streak,
    });
  }

  Widget _buildStreakCard(int streak, bool doneToday, Map<String, dynamic> data) {
    final completedDates = List.from(data['completedDates'] ?? []);
    final totalDays = completedDates.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(_selectedIcon, style: const TextStyle(fontSize: 36)),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['title'] ?? '', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(data['frequency'] ?? 'Diario', style: GoogleFonts.sora(fontSize: 13, color: const Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: doneToday ? _accent.withOpacity(0.2) : const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: doneToday ? _accent : const Color(0xFF2D3748), width: 1.5),
                ),
                child: Text(doneToday ? '✓ Hoy' : 'Hoy',
                    style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600,
                        color: doneToday ? _accent : const Color(0xFF6B7280))),
              ),
            ],
          ),
          const Gap(16),
          Row(
            children: [
              _streakStat('$streak', 'Racha', Icons.local_fire_department_rounded, const Color(0xFFF59E0B)),
              const Gap(12),
              _streakStat('$totalDays', 'Total días', Icons.calendar_today_rounded, _accent),
              const Gap(12),
              _streakStat(
                streak > 0 ? '${((totalDays / (DateTime.now().difference(DateTime.now().subtract(Duration(days: 30))).inDays + 1)) * 100).round()}%' : '0%',
                'Este mes',
                Icons.trending_up_rounded,
                const Color(0xFF6366F1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _streakStat(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const Gap(4),
            Text(value, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: GoogleFonts.sora(fontSize: 10, color: const Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _buildIconPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ÍCONO', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(10),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: _icons.map((icon) {
            final selected = _selectedIcon == icon;
            return GestureDetector(
              onTap: _editing ? () => setState(() => _selectedIcon = icon) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: selected ? _accent.withOpacity(0.15) : _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? _accent : const Color(0xFF1F2937), width: 1.5),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildField({required String label, required TextEditingController controller, bool enabled = true, int maxLines = 1, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(8),
        TextFormField(
          controller: controller, enabled: enabled, maxLines: maxLines, validator: validator,
          style: GoogleFonts.sora(color: enabled ? Colors.white : const Color(0xFF6B7280), fontSize: 15),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            filled: true,
            fillColor: enabled ? _surface : _surface.withOpacity(0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1F2937), width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _accent, width: 1.5)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1A1F2B), width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
            errorStyle: GoogleFonts.sora(color: const Color(0xFFEF4444), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FRECUENCIA', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(10),
        Row(
          children: _frequencies.map((f) {
            final selected = _frequency == f;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: f != _frequencies.last ? 10 : 0),
                child: GestureDetector(
                  onTap: _editing ? () => setState(() => _frequency = f) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? _accent.withOpacity(0.15) : _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? _accent : const Color(0xFF1F2937), width: 1.5),
                    ),
                    child: Text(f, textAlign: TextAlign.center,
                        style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600,
                            color: selected ? _accent : const Color(0xFF6B7280))),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DÍAS', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_days.length, (i) {
            final selected = _selectedDays.contains(i);
            return GestureDetector(
              onTap: _editing ? () => setState(() => selected ? _selectedDays.remove(i) : _selectedDays.add(i)) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: selected ? _accent : _surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? _accent : const Color(0xFF1F2937), width: 1.5),
                ),
                child: Center(child: Text(_days[i],
                    style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : const Color(0xFF6B7280)))),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildActions(bool doneToday, List completedDates) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity, height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: doneToday
                    ? [const Color(0xFF1F2937), const Color(0xFF1F2937)]
                    : [_accent, const Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: doneToday ? [] : [BoxShadow(color: _accent.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _markToday,
              icon: Icon(doneToday ? Icons.undo_rounded : Icons.check_rounded, color: Colors.white, size: 18),
              label: Text(doneToday ? 'Desmarcar hoy' : '¡Completar hoy!',
                  style: GoogleFonts.sora(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
        const Gap(12),
        SizedBox(
          width: double.infinity, height: 52,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
            label: Text('Eliminar hábito', style: GoogleFonts.sora(color: const Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.w500)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

class _BgPainter extends CustomPainter {
  final Color color;
  _BgPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..shader = RadialGradient(colors: [color.withOpacity(0.1), Colors.transparent])
          .createShader(Rect.fromCircle(center: Offset(size.width, 0), radius: size.width * 0.8));
    canvas.drawCircle(Offset(size.width, 0), size.width * 0.8, p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}