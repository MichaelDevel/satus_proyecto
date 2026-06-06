import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  static const _bg = Color(0xFF060A12);
  static const _accent = Color(0xFF10B981);
  static const _surface = Color(0xFF0D1117);

  String _frequency = 'Diario';
  String _selectedIcon = '💪';
  bool _isLoading = false;

  final List<String> _frequencies = ['Diario', 'Semanal', 'Mensual'];
  final List<String> _icons = ['💪', '📚', '🏃', '💧', '🧘', '🍎', '😴', '✍️', '🎯', '🧠', '🎵', '🌿'];

  final List<String> _days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  final Set<int> _selectedDays = {0, 1, 2, 3, 4};

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('habits')
          .add({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'frequency': _frequency,
        'icon': _selectedIcon,
        'days': _selectedDays.toList()..sort(),
        'streak': 0,
        'completedDates': [],
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSuccess('Hábito creado exitosamente.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _showError('Error al guardar el hábito.');
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
                          _buildIconPicker()
                              .animate().fadeIn(delay: 200.ms, duration: 500.ms).slideX(begin: -0.1),
                          const Gap(20),
                          _buildField(
                            label: 'NOMBRE DEL HÁBITO',
                            hint: 'Ej: Leer 30 minutos...',
                            controller: _titleCtrl,
                            icon: Icons.loop_rounded,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
                          ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideX(begin: -0.1),
                          const Gap(20),
                          _buildField(
                            label: 'DESCRIPCIÓN',
                            hint: 'Detalla tu hábito (opcional)...',
                            controller: _descCtrl,
                            icon: Icons.notes_rounded,
                            maxLines: 3,
                          ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideX(begin: -0.1),
                          const Gap(20),
                          _buildFrequencySelector()
                              .animate().fadeIn(delay: 500.ms, duration: 500.ms).slideX(begin: -0.1),
                          const Gap(20),
                          if (_frequency == 'Diario' || _frequency == 'Semanal')
                            _buildDaySelector()
                                .animate().fadeIn(delay: 600.ms, duration: 500.ms).slideX(begin: -0.1),
                          const Gap(40),
                          _buildSaveButton()
                              .animate().fadeIn(delay: 700.ms, duration: 500.ms).slideY(begin: 0.3),
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
          Text('Nuevo Hábito', style: GoogleFonts.sora(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
            gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.loop_rounded, color: Colors.white, size: 26),
        ),
        const Gap(16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Añadir Hábito', style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Construye rutinas positivas', style: GoogleFonts.sora(fontSize: 13, color: const Color(0xFF9CA3AF))),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2);
  }

  Widget _buildIconPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ÍCONO', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const Gap(10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _icons.map((icon) {
            final selected = _selectedIcon == icon;
            return GestureDetector(
              onTap: () => setState(() => _selectedIcon = icon),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: selected ? _accent.withOpacity(0.15) : _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? _accent : const Color(0xFF1F2937), width: 1.5),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
              ),
            );
          }).toList(),
        ),
      ],
    );
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
                  onTap: () => setState(() => _frequency = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? _accent.withOpacity(0.15) : _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: selected ? _accent : const Color(0xFF1F2937), width: 1.5),
                    ),
                    child: Text(
                      f,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? _accent : const Color(0xFF6B7280)),
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
              onTap: () => setState(() => selected ? _selectedDays.remove(i) : _selectedDays.add(i)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: selected ? _accent : _surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? _accent : const Color(0xFF1F2937), width: 1.5),
                ),
                child: Center(
                  child: Text(_days[i], style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : const Color(0xFF6B7280))),
                ),
              ),
            );
          }),
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
          gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
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
              : Text('Guardar Hábito', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
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