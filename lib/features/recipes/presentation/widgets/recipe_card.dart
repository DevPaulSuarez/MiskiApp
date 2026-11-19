import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
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
      color: onImage ? AppColors.night.withValues(alpha: 0.55) : Colors.transparent,
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
            color: AppColors.danger,
          ),
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
                    Text(
                      recipe.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${category?.emoji ?? ''} ${category?.name ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StarRating(value: rating.average, size: 14),
                        Text('  ${rating.count}', style: Theme.of(context).textTheme.bodySmall),
                        if (recipe.status == RecipeStatus.archived) ...[
                          const SizedBox(width: 8),
                          StatusBadge('Archivada', color: AppColors.textMuted),
                        ],
                      ],
                    ),
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
