import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../recipes/presentation/providers/recipe_providers.dart';
import '../../recipes/presentation/screens/cookbook_screen.dart';
import '../../recipes/presentation/widgets/recipe_card.dart';
import '../../social/presentation/providers/social_providers.dart';
import '../../social/presentation/widgets/notifications_action.dart';
import 'widgets/dashboard_shortcuts.dart';
import 'widgets/upcoming_birthdays.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(userByIdProvider(ref.watch(currentUserIdProvider)));
    final recipes = ref.watch(activeRecipesProvider);
    final categories = ref.watch(categoriesProvider);
    final featured = recipes.where((r) => r.id == 'r1').firstOrNull ?? recipes.firstOrNull;
    final recent = [...recipes]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hola, ${me.name.split(' ').first} 👋', style: Theme.of(context).textTheme.bodyMedium),
                          Text('¿Qué cocinamos hoy?', style: Theme.of(context).textTheme.headlineSmall),
                        ],
                      ),
                    ),
                    const NotificationsAction(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  onTap: () => context.push('/search'),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      border: Border.all(color: AppColors.beige),
                    ),
                    child: const Row(children: [
                      Icon(Icons.search_rounded, color: AppColors.textMuted),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Buscar recetas o ingredientes…',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SectionHeader('Accesos rápidos')),
            const SliverToBoxAdapter(child: DashboardShortcuts()),
            const SliverToBoxAdapter(child: UpcomingBirthdays()),
            const SliverToBoxAdapter(child: SectionHeader('Categorías')),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 92,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final c = categories[i];
                    return GestureDetector(
                      onTap: () {
                        ref.read(cookbookCategoryProvider.notifier).select(c.id);
                        context.go('/recipes');
                      },
                      child: Column(children: [
                        Container(
                          width: 60,
                          height: 60,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.beigeSoft,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(c.emoji, style: const TextStyle(fontSize: 26)),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 72,
                          child: Text(
                            c.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
              ),
            ),
            if (featured != null) ...[
              const SliverToBoxAdapter(child: SectionHeader('Receta destacada')),
              SliverToBoxAdapter(child: _FeaturedCard(recipeId: featured.id)),
            ],
            SliverToBoxAdapter(
              child: SectionHeader('Recientes', action: 'Ver todas', onAction: () => context.go('/recipes')),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 228,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: recent.length.clamp(0, 6),
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => SizedBox(width: 170, child: RecipeCard(recipe: recent[i])),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _FeaturedCard extends ConsumerWidget {
  const _FeaturedCard({required this.recipeId});
  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeByIdProvider(recipeId))!;
    final versions = ref.watch(versionsOfRecipeProvider(recipeId));
    final rating = ref.watch(recipeRatingSummaryProvider(recipeId));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => context.push('/recipe/$recipeId'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: Stack(
            children: [
              RecipeImage(url: recipe.imageUrl, height: 220, radius: 0),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppColors.forest.withValues(alpha: 0.92)],
                      stops: const [0.35, 1],
                    ),
                  ),
                ),
              ),
              Positioned(top: 10, right: 10, child: FavoriteButton(recipeId: recipeId)),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      InfoPill(icon: Icons.star_rounded, label: '${rating.average.toStringAsFixed(1)} · ${rating.count} reseñas', dark: true),
                      InfoPill(icon: Icons.account_tree_rounded, label: '${versions.length} versiones', dark: true),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
