import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'start_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF060A12);
  static const _accent = Color(0xFF6366F1);

  late AnimationController _orbCtrl;

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Si ya hay sesión activa, salta directo al inicio
    Future.delayed(const Duration(milliseconds: 300), () {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => StartScreen(user: user)),
        );
      }
    });
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Fondo animado ────────────────────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _orbCtrl,
              builder: (_, __) => CustomPaint(
                painter: _OrbPainter(_orbCtrl.value),
              ),
            ),
          ),

          // ── Contenido ────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Logo
                  _buildLogo(),

                  const Gap(40),

                  // Título y subtítulo
                  _buildTexts(),

                  const Spacer(flex: 3),

                  // Indicadores de features
                  _buildFeatures(),

                  const Gap(48),

                  // Botones
                  _buildButtons(context),

                  const Gap(40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logo ───────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(0.5),
                blurRadius: 32,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 48),
        )
            .animate()
            .fadeIn(duration: 800.ms)
            .scale(begin: const Offset(0.6, 0.6), curve: Curves.elasticOut, duration: 900.ms),

        const Gap(20),

        Text(
          'SATUS',
          style: GoogleFonts.sora(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 6,
          ),
        ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.3, curve: Curves.easeOut),

        const Gap(6),

        Text(
          'Tu asistente personal',
          style: GoogleFonts.sora(
            fontSize: 14,
            color: const Color(0xFF6366F1),
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
      ],
    );
  }

  // ── Textos ─────────────────────────────────────────────────────────────────
  Widget _buildTexts() {
    return Column(
      children: [
        Text(
          'Organiza tu vida,\nalcanza tus metas.',
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.25,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(delay: 700.ms, duration: 600.ms).slideY(begin: 0.2, curve: Curves.easeOut),

        const Gap(14),

        Text(
          'Gestiona tareas, construye hábitos y\nnunca pierdas un recordatorio importante.',
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
            fontSize: 15,
            color: const Color(0xFF9CA3AF),
            height: 1.6,
          ),
        ).animate().fadeIn(delay: 850.ms, duration: 600.ms).slideY(begin: 0.2, curve: Curves.easeOut),
      ],
    );
  }

  // ── Features ───────────────────────────────────────────────────────────────
  Widget _buildFeatures() {
    final features = [
      (Icons.check_circle_outline_rounded, 'Tareas', const Color(0xFF6366F1)),
      (Icons.loop_rounded, 'Hábitos', const Color(0xFF10B981)),
      (Icons.notifications_none_rounded, 'Alertas', const Color(0xFFF59E0B)),
      (Icons.mic_none_rounded, 'Voz', const Color(0xFFEC4899)),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(features.length, (i) {
        final (icon, label, color) = features[i];
        return Padding(
          padding: EdgeInsets.only(right: i < features.length - 1 ? 16 : 0),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Gap(8),
              Text(
                label,
                style: GoogleFonts.sora(
                  fontSize: 12,
                  color: const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ).animate().fadeIn(delay: Duration(milliseconds: 1000 + i * 100), duration: 500.ms).slideY(begin: 0.3, curve: Curves.easeOut),
        );
      }),
    );
  }

  // ── Botones ────────────────────────────────────────────────────────────────
  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        // Botón principal — Comenzar
        SizedBox(
          width: double.infinity,
          height: 58,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (_, a, b) => const LoginScreen(),
                  transitionsBuilder: (_, anim, __, child) => FadeTransition(
                    opacity: anim,
                    child: child,
                  ),
                  transitionDuration: const Duration(milliseconds: 500),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Comenzar',
                    style: GoogleFonts.sora(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Gap(8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(delay: 1400.ms, duration: 500.ms).slideY(begin: 0.3, curve: Curves.easeOut),

        const Gap(16),

        // Botón secundario — Ya tengo cuenta
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (_, a, b) => const LoginScreen(),
                transitionsBuilder: (_, anim, __, child) => FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                transitionDuration: const Duration(milliseconds: 500),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1F2937), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: Text(
              'Ya tengo una cuenta',
              style: GoogleFonts.sora(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ).animate().fadeIn(delay: 1550.ms, duration: 500.ms).slideY(begin: 0.3, curve: Curves.easeOut),
      ],
    );
  }
}

// ── Orbes de fondo animados ───────────────────────────────────────────────────
class _OrbPainter extends CustomPainter {
  final double t;
  _OrbPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Orbe superior derecho
    final x1 = size.width * 0.85 + t * 20;
    final y1 = size.height * 0.08 + t * 15;
    final p1 = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF6366F1).withOpacity(0.18), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(x1, y1), radius: size.width * 0.65));
    canvas.drawCircle(Offset(x1, y1), size.width * 0.65, p1);

    // Orbe inferior izquierdo
    final x2 = size.width * 0.1 - t * 15;
    final y2 = size.height * 0.88 - t * 10;
    final p2 = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF8B5CF6).withOpacity(0.12), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(x2, y2), radius: size.width * 0.6));
    canvas.drawCircle(Offset(x2, y2), size.width * 0.6, p2);

    // Orbe central sutil
    final x3 = size.width * 0.5;
    final y3 = size.height * 0.45 + t * 12;
    final p3 = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF4F46E5).withOpacity(0.06), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(x3, y3), radius: size.width * 0.5));
    canvas.drawCircle(Offset(x3, y3), size.width * 0.5, p3);
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}