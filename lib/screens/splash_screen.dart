import 'package:flutter/material.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _lockController;
  late AnimationController _glowController;
  late AnimationController _fadeController;

  late Animation<double> _lockAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _fadeOutAnimation;

  @override
  void initState() {
    super.initState();

    _lockController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _lockAnimation = CurvedAnimation(
      parent: _lockController,
      curve: Curves.easeOutCubic,
    );

    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );

    _fadeOutAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 200));
    await _lockController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _glowController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    await _fadeController.forward();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  void dispose() {
    _lockController.dispose();
    _glowController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_fadeOutAnimation),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_lockAnimation, _glowAnimation]),
                builder: (context, child) {
                  return _PLocketLogo(
                    lockProgress: _lockAnimation.value,
                    glowOpacity: _glowAnimation.value,
                  );
                },
              ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _lockAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _lockAnimation.value.clamp(0.0, 1.0),
                    child: const Text(
                      'pLOCKet',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 6,
                        color: Color(0xFFE8E8EC),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PLocketLogo extends StatelessWidget {
  final double lockProgress;
  final double glowOpacity;

  const _PLocketLogo({
    required this.lockProgress,
    required this.glowOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (glowOpacity > 0)
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4A90D9).withValues(alpha: 0.3 * glowOpacity),
                    const Color(0xFF4A90D9).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          CustomPaint(
            size: const Size(140, 140),
            painter: _PocketLockPainter(lockProgress: lockProgress),
          ),
        ],
      ),
    );
  }
}

class _PocketLockPainter extends CustomPainter {
  final double lockProgress;

  _PocketLockPainter({required this.lockProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    _drawPocket(canvas, center, size);
    _drawLock(canvas, center, size);
  }

  void _drawPocket(Canvas canvas, Offset center, Size size) {
    final pocketPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2A2A32),
          const Color(0xFF1A1A22),
        ],
      ).createShader(Rect.fromCenter(
        center: center,
        width: size.width * 0.7,
        height: size.height * 0.8,
      ))
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF3A3A44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final pocketPath = Path();
    final w = size.width * 0.65;
    final h = size.height * 0.75;
    final left = center.dx - w / 2;
    final top = center.dy - h / 2 + 5;

    pocketPath.moveTo(left + 12, top);
    pocketPath.lineTo(left + w - 12, top);
    pocketPath.quadraticBezierTo(left + w, top, left + w, top + 12);
    pocketPath.lineTo(left + w, top + h - 12);
    pocketPath.quadraticBezierTo(left + w, top + h, left + w - 12, top + h);
    pocketPath.lineTo(left + 12, top + h);
    pocketPath.quadraticBezierTo(left, top + h, left, top + h - 12);
    pocketPath.lineTo(left, top + 12);
    pocketPath.quadraticBezierTo(left, top, left + 12, top);
    pocketPath.close();

    canvas.drawPath(pocketPath, pocketPaint);
    canvas.drawPath(pocketPath, borderPaint);

    final flapPaint = Paint()
      ..color = const Color(0xFF222230)
      ..style = PaintingStyle.fill;

    final flapPath = Path();
    flapPath.moveTo(left + 8, top + h * 0.3);
    flapPath.quadraticBezierTo(center.dx, top + h * 0.22, left + w - 8, top + h * 0.3);
    flapPath.lineTo(left + w - 8, top + h * 0.32);
    flapPath.quadraticBezierTo(center.dx, top + h * 0.24, left + 8, top + h * 0.32);
    flapPath.close();

    canvas.drawPath(flapPath, flapPaint);
  }

  void _drawLock(Canvas canvas, Offset center, Size size) {
    final lockCenter = Offset(center.dx, center.dy + 8);
    final bodyWidth = 28.0;
    final bodyHeight = 22.0;
    final bodyTop = lockCenter.dy - 2;

    final bodyGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF5A8EC4),
          const Color(0xFF3A6EA4),
        ],
      ).createShader(Rect.fromLTWH(
        lockCenter.dx - bodyWidth / 2,
        bodyTop,
        bodyWidth,
        bodyHeight,
      ))
      ..style = PaintingStyle.fill;

    final bodyBorder = Paint()
      ..color = const Color(0xFF6A9ED4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        lockCenter.dx - bodyWidth / 2,
        bodyTop,
        bodyWidth,
        bodyHeight,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(bodyRect, bodyGradient);
    canvas.drawRRect(bodyRect, bodyBorder);

    final keyholePaint = Paint()
      ..color = const Color(0xFF1A2A3A)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(lockCenter.dx, bodyTop + bodyHeight * 0.4),
      3.5,
      keyholePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(lockCenter.dx - 1.5, bodyTop + bodyHeight * 0.4, 3, 6),
      keyholePaint,
    );

    final shacklePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF7AB4E8),
          const Color(0xFF4A84B8),
        ],
      ).createShader(Rect.fromLTWH(
        lockCenter.dx - 10,
        bodyTop - 18,
        20,
        20,
      ))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final shackleBorderPaint = Paint()
      ..color = const Color(0xFF8AC4F8).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final openAngle = lockProgress * 0.85;
    final shackleRadius = 10.0;
    final pivotX = lockCenter.dx + shackleRadius - 2;
    final pivotY = bodyTop + 2;

    canvas.save();
    canvas.translate(pivotX, pivotY);
    canvas.rotate(-openAngle);
    canvas.translate(-pivotX, -pivotY);

    final shacklePath = Path();
    shacklePath.moveTo(lockCenter.dx + shackleRadius - 2, bodyTop + 2);
    shacklePath.lineTo(lockCenter.dx + shackleRadius - 2, bodyTop - 10);
    shacklePath.arcToPoint(
      Offset(lockCenter.dx - shackleRadius + 2, bodyTop - 10),
      radius: const Radius.circular(10),
      clockwise: false,
    );
    shacklePath.lineTo(lockCenter.dx - shackleRadius + 2, bodyTop + 2);

    canvas.drawPath(shacklePath, shacklePaint);
    canvas.drawPath(shacklePath, shackleBorderPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PocketLockPainter oldDelegate) {
    return oldDelegate.lockProgress != lockProgress;
  }
}
