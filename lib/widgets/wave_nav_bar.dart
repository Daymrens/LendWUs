import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class WaveNavBar extends StatefulWidget implements PreferredSizeWidget {
  final int currentIndex;
  final ValueChanged<int> onItemTapped;

  const WaveNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemTapped,
  });

  @override
  Size get preferredSize => const Size.fromHeight(88);

  @override
  State<WaveNavBar> createState() => _WaveNavBarState();
}

class _WaveNavBarState extends State<WaveNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const _items = [
    _NavItemData(Icons.home_rounded, 'Home'),
    _NavItemData(Icons.savings_rounded, 'Contribs'),
    _NavItemData(Icons.account_balance_rounded, 'Loans'),
    _NavItemData(Icons.receipt_long_rounded, 'Requests'),
    _NavItemData(Icons.person_rounded, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final itemWidth = screenWidth / _items.length;
    final indicatorWidth = itemWidth * 0.7;

    return SizedBox(
      height: 88 + bottomPad,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 8 + bottomPad,
            left: 16,
            right: 16,
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A6CF7).withOpacity(0.12),
                    blurRadius: 32,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CustomPaint(
                  painter: _GlassmorphismPainter(),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutBack,
                        left: widget.currentIndex * itemWidth +
                            (itemWidth - indicatorWidth) / 2,
                        top: 8,
                        width: indicatorWidth,
                        height: 52,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, _) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color.lerp(
                                      const Color(0xFF4A6CF7),
                                      const Color(0xFF6C63FF),
                                      _pulseAnimation.value,
                                    )!,
                                    Color.lerp(
                                      const Color(0xFF7C5CFC),
                                      const Color(0xFF4A6CF7),
                                      _pulseAnimation.value,
                                    )!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.lerp(
                                      const Color(0xFF4A6CF7),
                                      const Color(0xFF7C5CFC),
                                      _pulseAnimation.value,
                                    )!.withOpacity(0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      ...List.generate(_items.length, (i) {
                        final isActive = widget.currentIndex == i;
                        return Positioned(
                          left: i * itemWidth,
                          top: 0,
                          width: itemWidth,
                          height: 68,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onItemTapped(i);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, _) {
                                final glow = isActive
                                    ? _pulseAnimation.value * 0.3
                                    : 0.0;
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedScale(
                                      scale: isActive ? 1.2 : 1.0,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOutBack,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: isActive
                                            ? BoxDecoration(
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                            0xFF4A6CF7)
                                                        .withOpacity(glow),
                                                    blurRadius: 12,
                                                  ),
                                                ],
                                              )
                                            : null,
                                        child: Icon(
                                          _items[i].icon,
                                          color: isActive
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.35),
                                          size: isActive ? 26 : 22,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    AnimatedDefaultTextStyle(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isActive
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isActive
                                            ? Colors.white
                                            : Colors.transparent,
                                        letterSpacing: 0.3,
                                      ),
                                      child: Text(_items[i].label),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassmorphismPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1A1A2E).withOpacity(0.92),
          const Color(0xFF16162A).withOpacity(0.95),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(24),
        ),
      );

    canvas.drawPath(path, paint);

    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.06),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.5),
      );

    canvas.drawPath(path, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData(this.icon, this.label);
}
