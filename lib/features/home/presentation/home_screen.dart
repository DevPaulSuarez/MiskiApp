import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/theme_toggle.dart';
import '../../recipes/presentation/providers/recipe_providers.dart';
import '../../recipes/presentation/widgets/recipe_showcase.dart';
import '../../social/presentation/providers/social_providers.dart';
import '../../social/presentation/widgets/notifications_action.dart';
import 'widgets/dashboard_shortcuts.dart';
import 'widgets/upcoming_birthdays.dart';

/// Summary dashboard: shortcuts, upcoming birthdays and the best rated dishes.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(userByIdProvider(ref.watch(currentUserIdProvider)));
    final featured = ref.watch(featuredRecipesProvider).take(3).toList();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Inicio', style: text.headlineSmall),
                        Text('Tu resumen, ${me.firstName}', style: text.bodyMedium),
                      ],
                    ),
                  ),
                  const ThemeToggleButton(),
                  const NotificationsAction(),
                ],
              ),
            ),
            const SectionHeader('Accesos rápidos'),
            const DashboardShortcuts(),
            const UpcomingBirthdays(),
            if (featured.isNotEmpty) ...[
              SectionHeader('Recetas destacadas', action: 'Ver todas', onAction: () => context.go('/recipes')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FeaturedRecipeCard(recipe: featured.first, imageHeight: 190),
              ),
              if (featured.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: CompactRecipeCard(recipe: featured[1])),
                      const SizedBox(width: 12),
                      Expanded(child: featured.length > 2 ? CompactRecipeCard(recipe: featured[2]) : const SizedBox()),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
