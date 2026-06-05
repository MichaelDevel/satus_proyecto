import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import 'login_screen.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ── Colores ──────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF060A12);
  static const _surface = Color(0xFF0D1117);
  static const _accent = Color(0xFF6366F1);

  // ── Estado del micrófono ─────────────────────────────────────────────────────
  bool _isListening = false;
  String _voiceText = 'Toca el micrófono para hablar...';
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _voiceText = 'Escuchando...';
        _pulseCtrl.repeat(reverse: true);
      } else {
        _voiceText = 'Toca el micrófono para hablar...';
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      }
    });
    // TODO: conectar speech_to_text cuando lo necesites
  }

  // ── Definición de secciones ──────────────────────────────────────────────────
  final List<_SectionData> _sections = const [
    _SectionData(
      icon: Icons.check_circle_outline_rounded,
      label: 'Tareas',
      description: 'Organiza tus pendientes y completa tus metas diarias.',
      gradient: [Color(0xFF6366F1), Color(0xFF4F46E5)],
      glowColor: Color(0xFF6366F1),
      tag: 'tasks',
    ),
    _SectionData(
      icon: Icons.loop_rounded,
      label: 'Hábitos',
      description: 'Construye rutinas poderosas día a día.',
      gradient: [Color(0xFF10B981), Color(0xFF059669)],
      glowColor: Color(0xFF10B981),
      tag: 'habits',
    ),
    _SectionData(
      icon: Icons.notifications_none_rounded,
      label: 'Recordatorios',
      description: 'No olvides nada importante con alertas a tiempo.',
      gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
      glowColor: Color(0xFFF59E0B),
      tag: 'reminders',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final displayName = widget.user.email?.split('@').first ?? 'Usuario';

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Fondo decorativo
          Positioned.fill(child: CustomPaint(painter: _BgPainter())),

          SafeArea(
            child: Column(
              children: [
                // ── Barra de voz superior ──────────────────────────────────
                _buildVoiceBar(),

                // ── Contenido scrollable ───────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Gap(32),
                        _buildGreeting(displayName),
                        const Gap(36),
                        _buildSectionLabel('¿Qué quieres hacer?'),
                        const Gap(20),
                        _buildCards(),
                        const Gap(36),
                        _buildSectionLabel('Resumen de hoy'),
                        const Gap(16),
                        _buildSummaryRow(),
                        const Gap(32),
                        _buildSignOutButton(),
                        const Gap(32),
                      ],
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

  // ── Barra de voz ─────────────────────────────────────────────────────────────
  Widget _buildVoiceBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isListening
              ? _accent.withOpacity(0.6)
              : const Color(0xFF1F2937),
          width: 1.5,
        ),
        boxShadow: _isListening
            ? [BoxShadow(color: _accent.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)]
            : [],
      ),
      child: Row(
        children: [
          // Ícono de asistente
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
          ),
          const Gap(12),

          // Texto de estado
          Expanded(
            child: Text(
              _voiceText,
              style: GoogleFonts.sora(
                fontSize: 13,
                color: _isListening
                    ? Colors.white
                    : const Color(0xFF6B7280),
                fontWeight: _isListening ? FontWeight.w500 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Indicador de onda cuando escucha
          if (_isListening) ...[
            _WaveIndicator(controller: _pulseCtrl),
            const Gap(10),
          ],

          // Botón micrófono
          GestureDetector(
            onTap: _toggleListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isListening
                    ? _accent
                    : const Color(0xFF1F2937),
                shape: BoxShape.circle,
                boxShadow: _isListening
                    ? [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 12, spreadRadius: 1)]
                    : [],
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isListening ? Colors.white : const Color(0xFF9CA3AF),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.3, curve: Curves.easeOut);
  }

  // ── Saludo ────────────────────────────────────────────────────────────────────
  Widget _buildGreeting(String name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Buenos días' : hour < 18 ? 'Buenas tardes' : 'Buenas noches';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting,',
          style: GoogleFonts.sora(fontSize: 16, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w400),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
        const Gap(4),
        Text(
          name,
          style: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5),
        ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideX(begin: -0.1),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280), letterSpacing: 1.1),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }

  // ── Cards de secciones ────────────────────────────────────────────────────────
  Widget _buildCards() {
    return Column(
      children: List.generate(_sections.length, (i) {
        final s = _sections[i];
        return Padding(
          padding: EdgeInsets.only(bottom: i < _sections.length - 1 ? 16 : 0),
          child: _SectionCard(data: s, index: i),
        );
      }),
    );
  }

  // ── Resumen rápido ────────────────────────────────────────────────────────────
  Widget _buildSummaryRow() {
    return Row(
      children: [
        _StatChip(label: 'Tareas', value: '0', color: const Color(0xFF6366F1)),
        const Gap(12),
        _StatChip(label: 'Hábitos', value: '0', color: const Color(0xFF10B981)),
        const Gap(12),
        _StatChip(label: 'Alertas', value: '0', color: const Color(0xFFF59E0B)),
      ],
    ).animate().fadeIn(delay: 700.ms, duration: 500.ms).slideY(begin: 0.2);
  }

  // ── Botón cerrar sesión ───────────────────────────────────────────────────────
  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () async {
          await AuthService().signOut();
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        },
        icon: const Icon(Icons.logout_rounded, color: Color(0xFF6B7280), size: 18),
        label: Text('Cerrar sesión', style: GoogleFonts.sora(color: const Color(0xFF6B7280), fontSize: 14, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF1F2937), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ).animate().fadeIn(delay: 800.ms, duration: 400.ms);
  }
}

// ── Card de sección ───────────────────────────────────────────────────────────
class _SectionCard extends StatefulWidget {
  final _SectionData data;
  final int index;
  const _SectionCard({required this.data, required this.index});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        // TODO: Navigator.push a la pantalla correspondiente según d.tag
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ir a ${d.label}', style: GoogleFonts.sora(color: Colors.white)),
            backgroundColor: d.gradient.first,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: d.glowColor.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Ícono con gradiente
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: d.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: d.glowColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(d.icon, color: Colors.white, size: 26),
              ),
              const Gap(16),

              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.label,
                      style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const Gap(4),
                    Text(
                      d.description,
                      style: GoogleFonts.sora(fontSize: 13, color: const Color(0xFF6B7280), height: 1.4),
                    ),
                  ],
                ),
              ),
              const Gap(12),

              // Flecha
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.arrow_forward_ios_rounded, color: d.glowColor, size: 14),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 450 + widget.index * 100), duration: 500.ms).slideX(begin: 0.1, curve: Curves.easeOut);
  }
}

// ── Chip de estadística ───────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: color),
            ),
            const Gap(4),
            Text(
              label,
              style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Indicador de onda ─────────────────────────────────────────────────────────
class _WaveIndicator extends StatelessWidget {
  final AnimationController controller;
  const _WaveIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          children: List.generate(3, (i) {
            final offset = i * 0.25;
            final val = (controller.value + offset).clamp(0.0, 1.0);
            final height = 8.0 + val * 14.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Datos de sección ──────────────────────────────────────────────────────────
class _SectionData {
  final IconData icon;
  final String label;
  final String description;
  final List<Color> gradient;
  final Color glowColor;
  final String tag;

  const _SectionData({
    required this.icon,
    required this.label,
    required this.description,
    required this.gradient,
    required this.glowColor,
    required this.tag,
  });
}

// ── Fondo decorativo ──────────────────────────────────────────────────────────
class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF6366F1).withOpacity(0.08), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width, 0), radius: size.width * 0.8));
    canvas.drawCircle(Offset(size.width, 0), size.width * 0.8, p1);

    final p2 = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF10B981).withOpacity(0.06), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(0, size.height), radius: size.width * 0.7));
    canvas.drawCircle(Offset(0, size.height), size.width * 0.7, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}