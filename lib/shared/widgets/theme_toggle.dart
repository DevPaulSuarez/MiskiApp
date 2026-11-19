import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme_mode_provider.dart';

/// Sun/moon button that switches between light and dark theme.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(appBrightnessProvider) == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Tema claro' : 'Tema oscuro',
      onPressed: ref.read(appBrightnessProvider.notifier).toggle,
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
    );
  }
}

/// Settings row with a switch for the dark theme.
class ThemeSwitchTile extends ConsumerWidget {
  const ThemeSwitchTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(appBrightnessProvider) == Brightness.dark;
    return SwitchListTile(
      secondary: Icon(dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
      title: const Text('Tema oscuro'),
      subtitle: Text(dark ? 'Fondo negro' : 'Fondo claro'),
      value: dark,
      onChanged: (_) => ref.read(appBrightnessProvider.notifier).toggle(),
    );
  }
}
