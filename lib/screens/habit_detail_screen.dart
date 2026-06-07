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

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.data['title'] ?? '');
    _descCtrl = TextEditingController(text: widget.data['description'] ?? '');
    _frequency = widget.data['frequency'] ?? 'Diario';
    _selectedIcon = widget.data['icon'] ?? '💪';
    final rawDays = widget.data['days'];
    _selectedDays = rawDays != null ? Set<int>.from(rawDays) : {0, 1, 2, 3, 4};
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
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month}-${today.day}';
    final List completedDates = List.from(widget.data['completedDates'] ?? []);
    final alreadyDone = completedDates.contains(dateStr);

    if (alreadyDone) {
      completedDates.remove(dateStr);
    } else {
      completedDates.add(dateStr);
    }

    final streak = _calculateStreak(completedDates);
    await _col.doc(widget.habitId).update({
      'completedDates': completedDates,
      'streak': streak,
    });
    if (mounted) Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final streak = widget.data['streak'] ?? 0;
    final completedDates = List.from(widget.data['completedDates'] ?? []);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
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
                          _buildStreakCard(streak, doneToday).animate().fadeIn(delay: 150.ms),
                          const Gap(24),
                          _buildIconPicker().animate().fadeIn(delay: 200.ms),
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
                          _buildActions(doneToday).animate().fadeIn(delay: 600.ms),
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

  Widget _buildStreakCard(int streak, bool doneToday) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Text(_selectedIcon, style: const TextStyle(fontSize: 40)),
          const Gap(20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Racha actual', style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFF9CA3AF))),
                Row(
                  children: [
                    Text('$streak', style: GoogleFonts.sora(fontSize: 36, fontWeight: FontWeight.w800, color: _accent)),
                    const Gap(6),
                    Text('días', style: GoogleFonts.sora(fontSize: 16, color: _accent.withOpacity(0.7))),
                  ],
                ),
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

  Widget _buildActions(bool doneToday) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity, height: 52,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _markToday,
            icon: Icon(doneToday ? Icons.undo_rounded : Icons.check_rounded,
                color: doneToday ? const Color(0xFF9CA3AF) : _accent, size: 18),
            label: Text(doneToday ? 'Desmarcar hoy' : 'Marcar como hecho hoy',
                style: GoogleFonts.sora(color: doneToday ? const Color(0xFF9CA3AF) : _accent,
                    fontSize: 14, fontWeight: FontWeight.w500)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: doneToday ? const Color(0xFF1F2937) : _accent.withOpacity(0.4), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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