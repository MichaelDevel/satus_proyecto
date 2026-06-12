import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import '../../services/notification_service.dart';

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  static const _bg = Color(0xFF060A12);
  static const _accent = Color(0xFFF59E0B);
  static const _surface = Color(0xFF0D1117);

  DateTime? _reminderDate;
  TimeOfDay? _reminderTime;
  String _repeat = 'No repetir';
  bool _isLoading = false;

  final List<String> _repeatOptions = ['No repetir', 'Cada día', 'Cada semana', 'Cada mes'];

  final Map<String, IconData> _repeatIcons = {
    'No repetir': Icons.do_not_disturb_alt_rounded,
    'Cada día': Icons.today_rounded,
    'Cada semana': Icons.date_range_rounded,
    'Cada mes': Icons.calendar_month_rounded,
  };

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFF59E0B),
            surface: Color(0xFF0D1117),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _reminderDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFF59E0B),
            surface: Color(0xFF0D1117),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _reminderTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_reminderDate == null) { _showError('Selecciona una fecha.'); return; }
    if (_reminderTime == null) { _showError('Selecciona una hora.'); return; }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final dateTime = DateTime(
        _reminderDate!.year, _reminderDate!.month, _reminderDate!.day,
        _reminderTime!.hour, _reminderTime!.minute,
      );

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('reminders')
          .add({
        'title': _titleCtrl.text.trim(),
        'note': _noteCtrl.text.trim(),
        'dateTime': Timestamp.fromDate(dateTime),
        'repeat': _repeat,
        'active': true,
        'triggered': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await NotificationService().scheduleReminder(
        id: docRef.id.hashCode.abs(),
        title: _titleCtrl.text.trim(),
        body: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : 'Tienes un recordatorio',
        dateTime: dateTime,
        repeat: _repeat,
      );
      print('📅 Fecha seleccionada: $_reminderDate');
      print('⏰ Hora seleccionada: $_reminderTime');
      print('🗓️ DateTime combinado: $dateTime');
      print('🌍 UTC: ${dateTime.toUtc()}');
      print('⏱️ Diferencia con ahora: ${dateTime.difference(DateTime.now()).inSeconds} segundos');
      if (mounted) {
        _showSuccess('Recordatorio creado.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _showError('Error al guardar el recordatorio.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: GoogleFonts.sora(color: Colors.white)),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ),
  );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: GoogleFonts.sora(color: Colors.white)),
      backgroundColor: _accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ),
  );

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
                          _buildHeader(),
                          const Gap(32),
                          _buildField(
                            label: 'TÍTULO',
                            hint: 'Ej: Tomar medicamento...',
                            controller: _titleCtrl,
                            icon: Icons.notifications_none_rounded,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un título' : null,
                          ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideX(begin: -0.1),
                          const Gap(20),
                          _buildField(
                            label: 'NOTA',
                            hint: 'Información adicional (opcional)...',
                            controller: _noteCtrl,
                            icon: Icons.sticky_note_2_outlined,
                            maxLines: 3,
                          ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideX(begin: -0.1),
                          const Gap(20),
                          _buildDateTimePickers()
                              .animate().fadeIn(delay: 400.ms, duration: 500.ms).slideX(begin: -0.1),
                          const Gap(20),
                          _buildRepeatSelector()
                              .animate().fadeIn(delay: 500.ms, duration: 500.ms).slideX(begin: -0.1),
                          const Gap(40),
                          _buildSaveButton()
                              .animate().fadeIn(delay: 600.ms, duration: 500.ms).slideY(begin: 0.3),
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
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF9CA3AF), size: 18),
            ),
          ),
          const Spacer(),
          Text('Nuevo Recordatorio', style: GoogleFonts.sora(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          const SizedBox(width: 42),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26),
        ),
        const Gap(16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Añadir Recordatorio', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Nunca olvides algo importante', style: GoogleFonts.sora(fontSize: 13, color: const Color(0xFF9CA3AF))),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2);
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.sora(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.sora(color: const Color(0xFF4B5563), fontSize: 15),
            prefixIcon: maxLines == 1
                ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Icon(icon, color: const Color(0xFF6B7280), size: 20))
                : null,
            prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 52),
            contentPadding: EdgeInsets.symmetric(horizontal: maxLines > 1 ? 20 : 0, vertical: 18),
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1F2937), width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _accent, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
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
            // Fecha
            Expanded(
              child: GestureDetector(
                onTap: _pickDate,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _reminderDate != null ? _accent : const Color(0xFF1F2937), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: _reminderDate != null ? _accent : const Color(0xFF6B7280), size: 18),
                      const Gap(10),
                      Expanded(
                        child: Text(
                          _reminderDate != null
                              ? '${_reminderDate!.day}/${_reminderDate!.month}/${_reminderDate!.year}'
                              : 'Fecha',
                          style: GoogleFonts.sora(fontSize: 14, color: _reminderDate != null ? Colors.white : const Color(0xFF4B5563)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Gap(12),
            // Hora
            Expanded(
              child: GestureDetector(
                onTap: _pickTime,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _reminderTime != null ? _accent : const Color(0xFF1F2937), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, color: _reminderTime != null ? _accent : const Color(0xFF6B7280), size: 18),
                      const Gap(10),
                      Text(
                        _reminderTime != null
                            ? _reminderTime!.format(context)
                            : 'Hora',
                        style: GoogleFonts.sora(fontSize: 14, color: _reminderTime != null ? Colors.white : const Color(0xFF4B5563)),
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
          spacing: 10,
          runSpacing: 10,
          children: _repeatOptions.map((opt) {
            final selected = _repeat == opt;
            return GestureDetector(
              onTap: () => setState(() => _repeat = opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? _accent.withOpacity(0.15) : _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? _accent : const Color(0xFF1F2937), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_repeatIcons[opt], color: selected ? _accent : const Color(0xFF6B7280), size: 16),
                    const Gap(8),
                    Text(opt, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? _accent : const Color(0xFF6B7280))),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _accent.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text('Guardar Recordatorio', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ),
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