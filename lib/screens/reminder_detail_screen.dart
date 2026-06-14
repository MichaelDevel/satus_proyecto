import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import '../services/notification_service.dart';

class ReminderDetailScreen extends StatefulWidget {
  final String reminderId;
  final Map<String, dynamic> data;
  const ReminderDetailScreen({super.key, required this.reminderId, required this.data});

  @override
  State<ReminderDetailScreen> createState() => _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends State<ReminderDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl;

  static const _bg = Color(0xFF060A12);
  static const _surface = Color(0xFF0D1117);
  static const _accent = Color(0xFFF59E0B);

  DateTime? _reminderDate;
  TimeOfDay? _reminderTime;
  late String _repeat;
  late bool _active;
  bool _isLoading = false;
  bool _editing = false;

  final List<String> _repeatOptions = ['No repetir', 'Cada día', 'Cada semana', 'Cada mes'];
  final Map<String, IconData> _repeatIcons = {
    'No repetir': Icons.do_not_disturb_alt_rounded,
    'Cada día': Icons.today_rounded,
    'Cada semana': Icons.date_range_rounded,
    'Cada mes': Icons.calendar_month_rounded,
  };

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.data['title'] ?? '');
    _noteCtrl = TextEditingController(text: widget.data['note'] ?? '');
    _repeat = widget.data['repeat'] ?? 'No repetir';
    _active = widget.data['active'] ?? true;
    final ts = widget.data['dateTime'] as Timestamp?;
    if (ts != null) {
      final dt = ts.toDate();
      _reminderDate = DateTime(dt.year, dt.month, dt.day);
      _reminderTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  CollectionReference get _col => FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .collection('reminders');

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;
    if (_reminderDate == null || _reminderTime == null) {
      _showError('Selecciona fecha y hora.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dt = DateTime(_reminderDate!.year, _reminderDate!.month, _reminderDate!.day,
          _reminderTime!.hour, _reminderTime!.minute);
      await _col.doc(widget.reminderId).update({
        'title': _titleCtrl.text.trim(),
        'note': _noteCtrl.text.trim(),
        'dateTime': Timestamp.fromDate(dt),
        'repeat': _repeat,
        'active': _active,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!_active) {
        await NotificationService().cancelReminder(
          NotificationService().idFromDocId(widget.reminderId),
        );
      } else {
        await NotificationService().scheduleReminder(
          id: NotificationService().idFromDocId(widget.reminderId),
          title: _titleCtrl.text.trim(),
          body: _noteCtrl.text.trim(),
          dateTime: dt,
          repeat: _repeat,
        );
      }

      if (mounted) {
        setState(() => _editing = false);
        _showSuccess('Recordatorio actualizado.');
      }
    } catch (_) {
      _showError('Error al actualizar.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await _confirmDialog('¿Eliminar recordatorio?', 'Esta acción no se puede deshacer.');
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      // Antes del delete:
      await NotificationService().cancelReminder(
        NotificationService().idFromDocId(widget.reminderId),
      );
      await _col.doc(widget.reminderId).delete();
      await _col.doc(widget.reminderId).delete();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showError('Error al eliminar.');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reminderDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFF59E0B), surface: Color(0xFF0D1117))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _reminderDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFF59E0B), surface: Color(0xFF0D1117))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _reminderTime = picked);
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
                          _buildStatusCard().animate().fadeIn(delay: 150.ms),
                          const Gap(24),
                          _buildField(label: 'TÍTULO', controller: _titleCtrl, enabled: _editing,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null)
                              .animate().fadeIn(delay: 200.ms),
                          const Gap(16),
                          _buildField(label: 'NOTA', controller: _noteCtrl, enabled: _editing, maxLines: 3)
                              .animate().fadeIn(delay: 300.ms),
                          const Gap(16),
                          _buildDateTimePickers().animate().fadeIn(delay: 400.ms),
                          const Gap(16),
                          _buildRepeatSelector().animate().fadeIn(delay: 500.ms),
                          const Gap(16),
                          _buildActiveToggle().animate().fadeIn(delay: 550.ms),
                          const Gap(32),
                          _buildActions().animate().fadeIn(delay: 600.ms),
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
          Text('Detalle de Recordatorio', style: GoogleFonts.sora(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
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

  Widget _buildStatusCard() {
    final dt = _reminderDate != null && _reminderTime != null
        ? DateTime(_reminderDate!.year, _reminderDate!.month, _reminderDate!.day, _reminderTime!.hour, _reminderTime!.minute)
        : null;
    final isPast = dt != null && dt.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_active ? 'Activo' : 'Inactivo',
                    style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700,
                        color: _active ? _accent : const Color(0xFF6B7280))),
                if (isPast)
                  Text('Fecha pasada', style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFFEF4444))),
              ],
            ),
          ),
          if (dt != null)
            Text(
              '${dt.day}/${dt.month}\n${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, height: 1.4),
            ),
        ],
      ),
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

  Widget _buildDateTimePickers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FECHA Y HORA', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _editing ? _pickDate : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _reminderDate != null ? _accent : const Color(0xFF1F2937), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: _reminderDate != null ? _accent : const Color(0xFF6B7280), size: 16),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          _reminderDate != null ? '${_reminderDate!.day}/${_reminderDate!.month}/${_reminderDate!.year}' : 'Fecha',
                          style: GoogleFonts.sora(fontSize: 13, color: _reminderDate != null ? Colors.white : const Color(0xFF4B5563)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Gap(12),
            Expanded(
              child: GestureDetector(
                onTap: _editing ? _pickTime : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _reminderTime != null ? _accent : const Color(0xFF1F2937), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, color: _reminderTime != null ? _accent : const Color(0xFF6B7280), size: 16),
                      const Gap(8),
                      Text(
                        _reminderTime != null ? _reminderTime!.format(context) : 'Hora',
                        style: GoogleFonts.sora(fontSize: 13, color: _reminderTime != null ? Colors.white : const Color(0xFF4B5563)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRepeatSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('REPETICIÓN', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(10),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: _repeatOptions.map((opt) {
            final selected = _repeat == opt;
            return GestureDetector(
              onTap: _editing ? () => setState(() => _repeat = opt) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? _accent.withOpacity(0.15) : _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? _accent : const Color(0xFF1F2937), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_repeatIcons[opt], color: selected ? _accent : const Color(0xFF6B7280), size: 15),
                    const Gap(6),
                    Text(opt, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600,
                        color: selected ? _accent : const Color(0xFF6B7280))),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActiveToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_outlined, color: Color(0xFF9CA3AF), size: 20),
          const Gap(14),
          Text('Recordatorio activo', style: GoogleFonts.sora(fontSize: 15, color: Colors.white)),
          const Spacer(),
          GestureDetector(
            onTap: _editing ? () => setState(() => _active = !_active) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 24,
              decoration: BoxDecoration(
                color: _active ? _accent : const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _active ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20, height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity, height: 52,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
            label: Text('Eliminar recordatorio', style: GoogleFonts.sora(color: const Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.w500)),
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