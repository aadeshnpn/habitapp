import 'dart:math' as math;
import 'package:flutter/material.dart';

enum CelebrationTier { minor, major, epic }

/// Full-screen or card-based celebration overlay shown on streak milestones.
///
/// - [minor]: subtle card slides up from bottom, auto-dismisses after 2 s
/// - [major]: confetti falls + card, tap to dismiss
/// - [epic]: full-screen animation + special message, tap to dismiss
class CelebrationOverlay extends StatefulWidget {
  final String message;
  final int streakCount;
  final VoidCallback onDismiss;
  final CelebrationTier tier;

  const CelebrationOverlay({
    super.key,
    required this.message,
    required this.streakCount,
    required this.onDismiss,
    required this.tier,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Confetti
  late AnimationController _confettiController;
  List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _fadeAnimation = _fadeController;

    if (widget.tier == CelebrationTier.major ||
        widget.tier == CelebrationTier.epic) {
      _confettiController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      );
      _particles = _generateParticles(
          widget.tier == CelebrationTier.epic ? 120 : 70);
      _confettiController.forward();
    } else {
      _confettiController = AnimationController(vsync: this);
    }

    _slideController.forward();

    // Auto-dismiss for minor tier
    if (widget.tier == CelebrationTier.minor) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _dismiss();
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _fadeController.reverse().then((_) => widget.onDismiss());
  }

  List<_Particle> _generateParticles(int count) {
    final rng = math.Random();
    const colors = [
      Color(0xFFFF5252),
      Color(0xFFFFEB3B),
      Color(0xFF69F0AE),
      Color(0xFF40C4FF),
      Color(0xFFE040FB),
      Color(0xFFFF6D00),
      Color(0xFF76FF03),
    ];
    return List.generate(count, (_) {
      return _Particle(
        x: rng.nextDouble(),
        startY: -rng.nextDouble() * 0.3,
        speed: 0.3 + rng.nextDouble() * 0.7,
        size: 5 + rng.nextDouble() * 8,
        color: colors[rng.nextInt(colors.length)],
        rotationSpeed: rng.nextDouble() * 4 - 2,
        sway: rng.nextDouble() * 0.04 - 0.02,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEpic = widget.tier == CelebrationTier.epic;
    final isMajor = widget.tier == CelebrationTier.major;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: widget.tier != CelebrationTier.minor ? _dismiss : null,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Background scrim for major/epic
            if (isMajor || isEpic)
              Container(
                color: Colors.black.withOpacity(isEpic ? 0.60 : 0.35),
              ),

            // Confetti layer
            if (isMajor || isEpic)
              AnimatedBuilder(
                animation: _confettiController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      particles: _particles,
                      progress: _confettiController.value,
                    ),
                    size: MediaQuery.of(context).size,
                  );
                },
              ),

            // Card
            Align(
              alignment: isEpic ? Alignment.center : Alignment.bottomCenter,
              child: SlideTransition(
                position: _slideAnimation,
                child: _CelebrationCard(
                  message: widget.message,
                  streakCount: widget.streakCount,
                  tier: widget.tier,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  final String message;
  final int streakCount;
  final CelebrationTier tier;

  const _CelebrationCard({
    required this.message,
    required this.streakCount,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String emoji;
    Color cardColor;
    double emojiSize;
    EdgeInsets padding;

    switch (tier) {
      case CelebrationTier.minor:
        emoji = '⭐';
        cardColor = theme.colorScheme.primaryContainer;
        emojiSize = 32;
        padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
        break;
      case CelebrationTier.major:
        emoji = '🎉';
        cardColor = theme.colorScheme.primaryContainer;
        emojiSize = 48;
        padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
        break;
      case CelebrationTier.epic:
        emoji = '🏆';
        cardColor = const Color(0xFF2C1654);
        emojiSize = 64;
        padding = const EdgeInsets.symmetric(horizontal: 40, vertical: 36);
        break;
    }

    final titleStyle = tier == CelebrationTier.epic
        ? theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          )
        : theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          );

    final subtitleStyle = tier == CelebrationTier.epic
        ? theme.textTheme.bodyLarge?.copyWith(color: Colors.white70)
        : theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
          );

    return Container(
      margin: tier == CelebrationTier.minor
          ? const EdgeInsets.all(16)
          : tier == CelebrationTier.major
              ? const EdgeInsets.all(24)
              : const EdgeInsets.all(32),
      padding: padding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: emojiSize)),
          const SizedBox(height: 10),
          Text(message, style: titleStyle, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            '$streakCount day streak!',
            style: subtitleStyle,
            textAlign: TextAlign.center,
          ),
          if (tier != CelebrationTier.minor) ...[
            const SizedBox(height: 16),
            Text(
              'Tap anywhere to continue',
              style: theme.textTheme.labelSmall?.copyWith(
                color: tier == CelebrationTier.epic
                    ? Colors.white38
                    : theme.colorScheme.onPrimaryContainer.withOpacity(0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Particle {
  final double x;         // 0..1 horizontal position
  final double startY;    // starting y (can be negative for off-screen)
  final double speed;     // 0..1 relative fall speed
  final double size;      // px
  final Color color;
  final double rotationSpeed;
  final double sway;      // horizontal sway per frame

  const _Particle({
    required this.x,
    required this.startY,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotationSpeed,
    required this.sway,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0..1

  const _ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final t = (progress * p.speed).clamp(0.0, 1.0);
      final y = (p.startY + t * 1.3) * size.height;
      final x = (p.x + math.sin(t * math.pi * 4) * p.sway) * size.width;

      if (y < 0 || y > size.height + p.size) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.rotationSpeed * math.pi * 2);

      paint.color = p.color.withOpacity((1.0 - t * 0.8).clamp(0, 1));

      // Draw a small rectangle (confetti piece)
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
