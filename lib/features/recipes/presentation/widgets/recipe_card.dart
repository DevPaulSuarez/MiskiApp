import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../domain/entities/recipe.dart';
import '../providers/recipe_providers.dart';

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.recipeId, this.onImage = true});
  final String recipeId;
  final bool onImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = ref.watch(favoritesProvider).contains(recipeId);
    return Material(
      color: onImage ? Colors.white.withValues(alpha: 0.92) : Colors.transparent,
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () => ref.read(favoritesProvider.notifier).toggle(recipeId),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Icon(
            fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(fav),
            color: AppColors.wine,
          ),
        ),
      ),
    );
  }
}

/// Large photo card used in grids and carousels.
class RecipeCard extends ConsumerWidget {
  const RecipeCard({super.key, required this.recipe, this.imageHeight = 130});
  final Recipe recipe;
  final double imageHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(versionByIdProvider(recipe.mainVersionId));
    final rating = ref.watch(recipeRatingSummaryProvider(recipe.id));
    final versions = ref.watch(versionsOfRecipeProvider(recipe.id)).length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/recipe/${recipe.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                RecipeImage(url: recipe.imageUrl, height: imageHeight, radius: 0),
                Positioned(top: 6, right: 6, child: FavoriteButton(recipeId: recipe.id)),
                if (versions > 1)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: InfoPill(icon: Icons.account_tree_rounded, label: '$versions versiones', dark: true),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: AppColors.gold),
                      Text(
                        rating.count == 0 ? ' –' : ' ${rating.average.toStringAsFixed(1)} (${rating.count})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      if (version != null) ...[
                        const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textMuted),
                        Text(' ${Fmt.minutes(version.totalMinutes)}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact horizontal row used in lists.
class RecipeListTile extends ConsumerWidget {
  const RecipeListTile({super.key, required this.recipe, this.trailing});
  final Recipe recipe;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoriesProvider).where((c) => c.id == recipe.categoryId).firstOrNull;
    final rating = ref.watch(recipeRatingSummaryProvider(recipe.id));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/recipe/${recipe.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: RecipeImage(url: recipe.imageUrl, radius: AppTheme.radiusS),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('${category?.emoji ?? ''} ${category?.name ?? ''}', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Row(children: [
                      StarRating(value: rating.average, size: 14),
                      Text('  ${rating.count}', style: Theme.of(context).textTheme.bodySmall),
                      if (recipe.status == RecipeStatus.archived) ...[
                        const SizedBox(width: 8),
                        const StatusBadge('Archivada', color: AppColors.textMuted),
                      ],
                    ]),
                  ],
                ),
              ),
              trailing ?? FavoriteButton(recipeId: recipe.id, onImage: false),
            ],
          ),
        ),
      ),
    );
  }
}
