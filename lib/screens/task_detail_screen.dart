import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  final Map<String, dynamic> data;
  const TaskDetailScreen({super.key, required this.taskId, required this.data});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;

  static const _bg = Color(0xFF060A12);
  static const _surface = Color(0xFF0D1117);
  static const _accent = Color(0xFF6366F1);

  late String _priority;
  DateTime? _dueDate;
  bool _isLoading = false;
  bool _editing = false;

  final Map<String, Color> _priorityColors = {
    'Alta': Color(0xFFEF4444),
    'Media': Color(0xFFF59E0B),
    'Baja': Color(0xFF10B981),
  };

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.data['title'] ?? '');
    _descCtrl = TextEditingController(text: widget.data['description'] ?? '');
    _priority = widget.data['priority'] ?? 'Media';
    final ts = widget.data['dueDate'] as Timestamp?;
    _dueDate = ts?.toDate();
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
      .collection('tasks');

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _col.doc(widget.taskId).update({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'priority': _priority,
        'dueDate': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() => _editing = false);
        _showSuccess('Tarea actualizada.');
      }
    } catch (_) {
      _showError('Error al actualizar.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await _confirmDialog('¿Eliminar tarea?', 'Esta acción no se puede deshacer.');
    if (!confirm) return;
    setState(() => _isLoading = true);
    try {
      await _col.doc(widget.taskId).delete();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showError('Error al eliminar.');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleComplete() async {
    final current = widget.data['completed'] ?? false;
    await _col.doc(widget.taskId).update({'completed': !current});
    if (mounted) Navigator.of(context).pop();
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.sora(color: const Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirmar', style: GoogleFonts.sora(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1), surface: Color(0xFF0D1117))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
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
    backgroundColor: const Color(0xFF10B981),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(16),
  ));

  @override
  Widget build(BuildContext context) {
    final completed = widget.data['completed'] ?? false;

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
                          // Estado completado
                          _buildStatusBadge(completed),
                          const Gap(24),

                          // Título
                          _buildField(
                            label: 'TÍTULO',
                            controller: _titleCtrl,
                            enabled: _editing,
                            icon: Icons.title_rounded,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ).animate().fadeIn(delay: 200.ms),
                          const Gap(16),

                          // Descripción
                          _buildField(
                            label: 'DESCRIPCIÓN',
                            controller: _descCtrl,
                            enabled: _editing,
                            icon: Icons.notes_rounded,
                            maxLines: 3,
                          ).animate().fadeIn(delay: 300.ms),
                          const Gap(16),

                          // Prioridad
                          _buildPrioritySelector().animate().fadeIn(delay: 400.ms),
                          const Gap(16),

                          // Fecha
                          _buildDatePicker().animate().fadeIn(delay: 500.ms),
                          const Gap(32),

                          // Botones acción
                          _buildActions(completed).animate().fadeIn(delay: 600.ms),
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
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937), width: 1.5)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF9CA3AF), size: 18),
            ),
          ),
          const Spacer(),
          Text('Detalle de Tarea', style: GoogleFonts.sora(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          // Editar / Guardar
          GestureDetector(
            onTap: _editing ? _update : () => setState(() => _editing = true),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _editing ? _accent : _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _editing ? _accent : const Color(0xFF1F2937), width: 1.5),
              ),
              child: Icon(_editing ? Icons.check_rounded : Icons.edit_outlined,
                  color: _editing ? Colors.white : const Color(0xFF9CA3AF), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool completed) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: completed ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFF6366F1).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: completed ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFF6366F1).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: completed ? const Color(0xFF10B981) : const Color(0xFF6366F1), size: 16),
              const Gap(6),
              Text(completed ? 'Completada' : 'Pendiente',
                  style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600,
                      color: completed ? const Color(0xFF10B981) : const Color(0xFF6366F1))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
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
          enabled: enabled,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.sora(color: enabled ? Colors.white : const Color(0xFF6B7280), fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: maxLines == 1
                ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Icon(icon, color: const Color(0xFF6B7280), size: 20))
                : null,
            prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 52),
            contentPadding: EdgeInsets.symmetric(horizontal: maxLines > 1 ? 20 : 0, vertical: 18),
            filled: true,
            fillColor: enabled ? _surface : _surface.withOpacity(0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1F2937), width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1A1F2B), width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
            errorStyle: GoogleFonts.sora(color: const Color(0xFFEF4444), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    final priorities = ['Alta', 'Media', 'Baja'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PRIORIDAD', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(10),
        Row(
          children: priorities.map((p) {
            final selected = _priority == p;
            final color = _priorityColors[p]!;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: p != priorities.last ? 10 : 0),
                child: GestureDetector(
                  onTap: _editing ? () => setState(() => _priority = p) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.15) : _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? color : const Color(0xFF1F2937), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.flag_rounded, color: selected ? color : const Color(0xFF4B5563), size: 18),
                        const Gap(4),
                        Text(p, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600,
                            color: selected ? color : const Color(0xFF6B7280))),
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
        Text('FECHA LÍMITE', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(8),
        GestureDetector(
          onTap: _editing ? _pickDate : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _dueDate != null ? _accent : const Color(0xFF1F2937), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: _dueDate != null ? _accent : const Color(0xFF6B7280), size: 18),
                const Gap(12),
                Text(
                  _dueDate != null ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}' : 'Sin fecha',
                  style: GoogleFonts.sora(fontSize: 14, color: _dueDate != null ? Colors.white : const Color(0xFF4B5563)),
                ),
                const Spacer(),
                if (_dueDate != null && _editing)
                  GestureDetector(
                    onTap: () => setState(() => _dueDate = null),
                    child: const Icon(Icons.close_rounded, color: Color(0xFF6B7280), size: 16),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(bool completed) {
    return Column(
      children: [
        // Marcar completada / pendiente
        SizedBox(
          width: double.infinity, height: 52,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _toggleComplete,
            icon: Icon(completed ? Icons.undo_rounded : Icons.check_rounded,
                color: completed ? const Color(0xFF9CA3AF) : const Color(0xFF10B981), size: 18),
            label: Text(completed ? 'Marcar como pendiente' : 'Marcar como completada',
                style: GoogleFonts.sora(color: completed ? const Color(0xFF9CA3AF) : const Color(0xFF10B981),
                    fontSize: 14, fontWeight: FontWeight.w500)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: completed ? const Color(0xFF1F2937) : const Color(0xFF10B981).withOpacity(0.4), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const Gap(12),
        // Eliminar
        SizedBox(
          width: double.infinity, height: 52,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
            label: Text('Eliminar tarea', style: GoogleFonts.sora(color: const Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.w500)),
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