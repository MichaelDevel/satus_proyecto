import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import '../services/auth_service.dart';
import '../widgets/auth_text_field.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _selectedGender;
  String? _selectedCountry;

  static const _bg = Color(0xFF060A12);
  static const _accent = Color(0xFF6366F1);
  static const _accentLight = Color(0xFF818CF8);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFF9CA3AF);

  final List<String> _genders = ['Masculino', 'Femenino', 'No binario', 'Prefiero no decir'];

  final List<String> _countries = [
    'Argentina', 'Bolivia', 'Chile', 'Colombia', 'Costa Rica',
    'Cuba', 'Ecuador', 'El Salvador', 'España', 'Guatemala',
    'Honduras', 'México', 'Nicaragua', 'Panamá', 'Paraguay',
    'Perú', 'República Dominicana', 'Uruguay', 'Venezuela', 'Otro',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    _ageCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) { _showError('Selecciona un género.'); return; }
    if (_selectedCountry == null) { _showError('Selecciona un país.'); return; }

    setState(() => _isLoading = true);

    // 1️⃣ Crear usuario en Firebase Auth
    final result = await _authService.registerWithEmail(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _isLoading = false);
      _showError(result.error!);
      return;
    }

    // 2️⃣ Guardar datos extra en Firestore
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(result.user!.uid)
          .set({
        'uid': result.user!.uid,
        'email': _emailCtrl.text.trim(),
        'nombre': _nameCtrl.text.trim(),
        'nickname': _nicknameCtrl.text.trim(),
        'edad': int.parse(_ageCtrl.text.trim()),
        'genero': _selectedGender,
        'pais': _selectedCountry,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // El usuario se creó en Auth pero falló Firestore — informar sin bloquear
      if (mounted) _showError('Cuenta creada, pero no se guardaron todos los datos. ($e)');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(user: result.user!)),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: GoogleFonts.sora(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BackgroundPainter())),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Gap(20),
                    _buildBackButton(context),
                    const Gap(32),
                    _buildHeader(),
                    const Gap(40),
                    _buildFields(),
                    const Gap(32),
                    _buildSubmitButton(),
                    const Gap(24),
                    _buildGoToLogin(context),
                    const Gap(40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF9CA3AF), size: 18),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2);
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 26),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.3, curve: Curves.easeOut),
        const Gap(24),
        Text(
          'Crea tu\ncuenta.',
          style: GoogleFonts.sora(fontSize: 36, fontWeight: FontWeight.w700, color: _textPrimary, height: 1.15, letterSpacing: -0.5),
        ).animate().fadeIn(delay: 150.ms, duration: 600.ms).slideY(begin: 0.2, curve: Curves.easeOut),
        const Gap(8),
        Text(
          'Completa tu información para registrarte.',
          style: GoogleFonts.sora(fontSize: 15, color: _textSecondary, height: 1.5),
        ).animate().fadeIn(delay: 250.ms, duration: 600.ms).slideY(begin: 0.2, curve: Curves.easeOut),
      ],
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        AuthTextField(
          label: 'NOMBRE COMPLETO',
          hint: 'Juan Pérez',
          controller: _nameCtrl,
          prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF6B7280), size: 20),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa tu nombre';
            if (v.trim().length < 2) return 'Nombre muy corto';
            return null;
          },
        ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideX(begin: -0.1),
        const Gap(18),

        AuthTextField(
          label: 'NICKNAME',
          hint: '@juanp',
          controller: _nicknameCtrl,
          prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF6B7280), size: 20),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa un nickname';
            if (v.trim().length < 3) return 'Mínimo 3 caracteres';
            return null;
          },
        ).animate().fadeIn(delay: 350.ms, duration: 500.ms).slideX(begin: -0.1),
        const Gap(18),

        AuthTextField(
          label: 'EDAD',
          hint: '25',
          controller: _ageCtrl,
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.cake_outlined, color: Color(0xFF6B7280), size: 20),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa tu edad';
            final age = int.tryParse(v.trim());
            if (age == null) return 'Ingresa un número válido';
            if (age < 13 || age > 120) return 'Edad entre 13 y 120 años';
            return null;
          },
        ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideX(begin: -0.1),
        const Gap(18),

        _buildDropdown(
          label: 'GÉNERO',
          hint: 'Selecciona tu género',
          value: _selectedGender,
          items: _genders,
          icon: Icons.wc_rounded,
          onChanged: (v) => setState(() => _selectedGender = v),
        ).animate().fadeIn(delay: 450.ms, duration: 500.ms).slideX(begin: -0.1),
        const Gap(18),

        _buildDropdown(
          label: 'PAÍS',
          hint: 'Selecciona tu país',
          value: _selectedCountry,
          items: _countries,
          icon: Icons.public_rounded,
          onChanged: (v) => setState(() => _selectedCountry = v),
        ).animate().fadeIn(delay: 500.ms, duration: 500.ms).slideX(begin: -0.1),
        const Gap(18),

        AuthTextField(
          label: 'CORREO ELECTRÓNICO',
          hint: 'correo@ejemplo.com',
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF6B7280), size: 20),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v.trim())) return 'Correo inválido';
            return null;
          },
        ).animate().fadeIn(delay: 550.ms, duration: 500.ms).slideX(begin: -0.1),
        const Gap(18),

        AuthTextField(
          label: 'CONTRASEÑA',
          hint: '••••••••',
          controller: _passwordCtrl,
          isPassword: true,
          textInputAction: TextInputAction.done,
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6B7280), size: 20),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
            if (v.length < 6) return 'Mínimo 6 caracteres';
            return null;
          },
        ).animate().fadeIn(delay: 600.ms, duration: 500.ms).slideX(begin: -0.1),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: 1.2)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.sora(color: const Color(0xFF4B5563), fontSize: 15),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(icon, color: const Color(0xFF6B7280), size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 52),
            filled: true,
            fillColor: const Color(0xFF111827),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF1F2937), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
          ),
          dropdownColor: const Color(0xFF111827),
          style: GoogleFonts.sora(color: Colors.white, fontSize: 15),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item, style: GoogleFonts.sora(color: Colors.white, fontSize: 15)),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
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
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text('Crear cuenta', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.3)),
        ),
      ),
    ).animate().fadeIn(delay: 650.ms, duration: 500.ms).slideY(begin: 0.3, curve: Curves.easeOut);
  }

  Widget _buildGoToLogin(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('¿Ya tienes una cuenta? ', style: GoogleFonts.sora(color: _textSecondary, fontSize: 14)),
          GestureDetector(
            onTap: _isLoading ? null : () => Navigator.of(context).pop(),
            child: Text(
              'Inicia sesión',
              style: GoogleFonts.sora(
                color: _accentLight, fontSize: 14, fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline, decorationColor: _accentLight,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 750.ms, duration: 400.ms);
  }
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..shader = RadialGradient(colors: [const Color(0xFF8B5CF6).withOpacity(0.15), Colors.transparent])
          .createShader(Rect.fromCircle(center: Offset(size.width * 0.9, size.height * 0.05), radius: size.width * 0.7));
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.05), size.width * 0.7, p1);

    final p2 = Paint()
      ..shader = RadialGradient(colors: [const Color(0xFF6366F1).withOpacity(0.1), Colors.transparent])
          .createShader(Rect.fromCircle(center: Offset(size.width * 0.1, size.height * 0.85), radius: size.width * 0.6));
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.85), size.width * 0.6, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}