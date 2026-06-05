import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import '../services/auth_service.dart';
import '../widgets/auth_text_field.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  static const _bg = Color(0xFF060A12);
  static const _accent = Color(0xFF6366F1);
  static const _accentLight = Color(0xFF818CF8);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFF9CA3AF);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await _authService.signInWithEmail(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(user: result.user!)),
      );
    } else {
      _showError(result.error!);
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      _showError('Escribe tu correo primero.');
      return;
    }
    setState(() => _isLoading = true);
    final result = await _authService.sendPasswordResetEmail(_emailCtrl.text);
    if (!mounted) return;
    setState(() => _isLoading = false);
    result.isSuccess
        ? _showSuccess('Correo de restablecimiento enviado.')
        : _showError(result.error!);
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

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: GoogleFonts.sora(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: const Color(0xFF10B981),
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
                    const Gap(60),
                    _buildHeader(),
                    const Gap(48),
                    _buildFields(),
                    const Gap(32),
                    _buildSubmitButton(),
                    const Gap(24),
                    _buildGoToRegister(),
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
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.3, curve: Curves.easeOut),
        const Gap(28),
        Text(
          'Bienvenido\nde vuelta.',
          style: GoogleFonts.sora(fontSize: 36, fontWeight: FontWeight.w700, color: _textPrimary, height: 1.15, letterSpacing: -0.5),
        ).animate().fadeIn(delay: 150.ms, duration: 600.ms).slideY(begin: 0.2, curve: Curves.easeOut),
        const Gap(8),
        Text(
          'Ingresa tus credenciales para continuar.',
          style: GoogleFonts.sora(fontSize: 15, color: _textSecondary, height: 1.5),
        ).animate().fadeIn(delay: 250.ms, duration: 600.ms).slideY(begin: 0.2, curve: Curves.easeOut),
      ],
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
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
        ).animate().fadeIn(delay: 350.ms, duration: 500.ms).slideX(begin: -0.1),
        const Gap(20),
        AuthTextField(
          label: 'CONTRASEÑA',
          hint: '••••••••',
          controller: _passwordCtrl,
          isPassword: true,
          textInputAction: TextInputAction.done,
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6B7280), size: 20),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
            if (v.length < 8) return 'Mínimo 8 caracteres';
            return null;
          },
        ).animate().fadeIn(delay: 450.ms, duration: 500.ms).slideX(begin: -0.1),
        const Gap(12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : _forgotPassword,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text('¿Olvidaste tu contraseña?', style: GoogleFonts.sora(color: _accentLight, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
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
              : Text('Iniciar sesión', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.3)),
        ),
      ),
    ).animate().fadeIn(delay: 600.ms, duration: 500.ms).slideY(begin: 0.3, curve: Curves.easeOut);
  }

  Widget _buildGoToRegister() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('¿No tienes una cuenta? ', style: GoogleFonts.sora(color: _textSecondary, fontSize: 14)),
          GestureDetector(
            onTap: _isLoading
                ? null
                : () => Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (_, a, b) => const RegisterScreen(),
                transitionsBuilder: (_, anim, __, child) =>
                    SlideTransition(
                      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                      child: child,
                    ),
              ),
            ),
            child: Text(
              'Regístrate',
              style: GoogleFonts.sora(
                color: _accentLight, fontSize: 14, fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline, decorationColor: _accentLight,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 700.ms, duration: 400.ms);
  }
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..shader = RadialGradient(colors: [const Color(0xFF6366F1).withOpacity(0.15), Colors.transparent])
          .createShader(Rect.fromCircle(center: Offset(size.width * 0.1, size.height * 0.05), radius: size.width * 0.7));
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.05), size.width * 0.7, p1);

    final p2 = Paint()
      ..shader = RadialGradient(colors: [const Color(0xFF8B5CF6).withOpacity(0.1), Colors.transparent])
          .createShader(Rect.fromCircle(center: Offset(size.width * 0.9, size.height * 0.85), radius: size.width * 0.6));
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.85), size.width * 0.6, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}