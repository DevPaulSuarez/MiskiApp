import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) context.go('/');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return Scaffold(
      backgroundColor: AppColors.forest,
      body: Center(
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(fade),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.wine,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.gold, width: 2),
                  ),
                  child: const Icon(Icons.restaurant_menu_rounded, color: AppColors.beige, size: 48),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Miski',
                  style: TextStyle(color: AppColors.beige, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tus recetas, sus versiones y tu mesa',
                  style: TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
