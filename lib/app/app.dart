import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_provider.dart';

class MiskiApp extends ConsumerWidget {
  const MiskiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(appBrightnessProvider);
    return MaterialApp.router(
      title: 'Miski',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(brightness),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
