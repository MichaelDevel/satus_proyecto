import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import '../../services/notification_service.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  static const _bg = Color(0xFF060A12);
  static const _accent = Color(0xFF6366F1);
  static const _surface = Color(0xFF0D1117);

  String _priority = 'Media';
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _isLoading = false;

  final List<String> _priorities = ['Alta', 'Media', 'Baja'];

  final Map<String, Color> _priorityColors = {
    'Alta': Color(0xFFEF4444),
    'Media': Color(0xFFF59E0B),
    'Baja': Color(0xFF10B981),
  };

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
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
            primary: Color(0xFF6366F1),
            surface: Color(0xFF0D1117),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6366F1),
            surface: Color(0xFF0D1117),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      DateTime? dueDateWithTime;
      if (_dueDate != null) {
        final time = _dueTime ?? const TimeOfDay(hour: 9, minute: 0);
        dueDateWithTime = DateTime(
          _dueDate!.year, _dueDate!.month, _dueDate!.day,
          time.hour, time.minute,
        );
      }

      final docRef = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('tasks')
          .add({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'priority': _priority,
        'dueDate': dueDateWithTime != null ? Timestamp.fromDate(dueDateWithTime) : null,
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (dueDateWithTime != null) {
        await NotificationService().scheduleTaskReminder(
          id: docRef.id.hashCode.abs(),
          title: _titleCtrl.text.trim(),
          dueDate: dueDateWithTime,
        );
      }

      if (mounted) {
        _showSuccess('Tarea creada exitosamente.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _showError('Error al guardar la tarea: $e');
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
      backgroundColor: const Color(0xFF10B981),
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
          Positioned.fill(child: CustomPaint(painter: _BgPainter(const Color(0xFF6366F1)))),
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
                            hint: 'Ej: Terminar el reporte...',
                            controller: _titleCtrl,
                            icon: Icons.title_rounded,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un título' : null,
                          ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideX(begin: -0.1),
                          const Gap(20),
                          _buildField(
                            label: 'DESCRIPCIÓN',
                            hint: 'Detalles de la tarea (opcional)...',
                            controller: _descCtrl,
                            icon: Icons.notes_rounded,
                            maxLines: 3,
                          ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideX(begin: -0.1),
                          const Gap(20),
                          _buildPrioritySelector()
                              .animate().fadeIn(delay: 400.ms, duration: 500.ms).slideX(begin: -0.1),
                          const Gap(20),
                          _buildDatePicker()
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
          Text('Nueva Tarea', style: GoogleFonts.sora(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 26),
        ),
        const Gap(16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Añadir Tarea', style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Completa los campos a continuación', style: GoogleFonts.sora(fontSize: 13, color: const Color(0xFF9CA3AF))),
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
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
            errorStyle: GoogleFonts.sora(color: const Color(0xFFEF4444), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PRIORIDAD', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(10),
        Row(
          children: _priorities.map((p) {
            final selected = _priority == p;
            final color = _priorityColors[p]!;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: p != _priorities.last ? 10 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _priority = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.15) : _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: selected ? color : const Color(0xFF1F2937), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.flag_rounded, color: selected ? color : const Color(0xFF4B5563), size: 20),
                        const Gap(6),
                        Text(p, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? color : const Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FECHA Y HORA LÍMITE',
            style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600,
                color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(8),
        Row(
          children: [
            // Fecha
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _dueDate != null ? _accent : const Color(0xFF1F2937),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          color: _dueDate != null ? _accent : const Color(0xFF6B7280),
                          size: 18),
                      const Gap(10),
                      Expanded(
                        child: Text(
                          _dueDate != null
                              ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                              : 'Fecha',
                          style: GoogleFonts.sora(
                              fontSize: 14,
                              color: _dueDate != null
                                  ? Colors.white
                                  : const Color(0xFF4B5563)),
                        ),
                      ),
                      if (_dueDate != null)
                        GestureDetector(
                          onTap: () => setState(() {
                            _dueDate = null;
                            _dueTime = null;
                          }),
                          child: const Icon(Icons.close_rounded,
                              color: Color(0xFF6B7280), size: 16),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Gap(10),
            // Hora
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _dueDate != null ? _pickTime : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: _dueDate != null ? _surface : _surface.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _dueTime != null ? _accent : const Color(0xFF1F2937),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          color: _dueTime != null
                              ? _accent
                              : _dueDate != null
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF2D3748),
                          size: 18),
                      const Gap(8),
                      Text(
                        _dueTime != null
                            ? _dueTime!.format(context)
                            : 'Hora',
                        style: GoogleFonts.sora(
                            fontSize: 14,
                            color: _dueTime != null
                                ? Colors.white
                                : _dueDate != null
                                ? const Color(0xFF4B5563)
                                : const Color(0xFF2D3748)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_dueDate != null && _dueTime == null) ...[
          const Gap(6),
          Text('Opcional — sin hora, la alerta es a las 9:00 AM',
              style: GoogleFonts.sora(fontSize: 11, color: const Color(0xFF4B5563))),
        ],
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
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
              : Text('Guardar Tarea', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
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