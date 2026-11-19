import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../social/domain/social_entities.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/services/recipe_filters.dart';
import '../providers/recipe_providers.dart';
import 'recipe_card.dart';

/// Active dishes ordered by how well they are rated: reliable averages first,
/// then higher average, then more reviews.
final featuredRecipesProvider = Provider<List<Recipe>>((ref) {
  final recipes = [...ref.watch(activeRecipesProvider)];
  final summary = {for (final r in recipes) r.id: ref.watch(recipeRatingSummaryProvider(r.id))};
  recipes.sort((a, b) {
    final sa = summary[a.id]!, sb = summary[b.id]!;
    if (sa.isReliable != sb.isReliable) return sa.isReliable ? -1 : 1;
    final byAvg = sb.average.compareTo(sa.average);
    return byAvg != 0 ? byAvg : sb.count.compareTo(sa.count);
  });
  return recipes;
});

/// Best dishes by this week's reviews, with that week's average and count.
final weeklyBestProvider = Provider<List<({Recipe recipe, double average, int count})>>((ref) {
  final active = {for (final r in ref.watch(activeRecipesProvider)) r.id: r};
  final ranked = bestOfPeriod(
    ref.watch(ratingsProvider).map((r) => (recipeId: r.recipeId, stars: r.stars, createdAt: r.createdAt)),
    now: DateTime.now(),
  );
  return [
    for (final e in ranked)
      if (active[e.recipeId] case final recipe?) (recipe: recipe, average: e.average, count: e.count),
  ];
});

/// Rating, reviews, versions and time of a dish (through its main version).
class _DishStats {
  _DishStats(WidgetRef ref, Recipe recipe)
    : rating = ref.watch(recipeRatingSummaryProvider(recipe.id)),
      versions = ref.watch(versionsOfRecipeProvider(recipe.id)).length,
      minutes = ref.watch(versionByIdProvider(recipe.mainVersionId))?.totalMinutes;

  final RatingSummary rating;
  final int versions;
  final int? minutes;

  String get ratingLabel =>
      rating.count == 0 ? 'Sin reseñas' : '${rating.average.toStringAsFixed(1)} (${rating.count})';
  String get reviewsLabel => rating.count == 1 ? '1 reseña' : '${rating.count} reseñas';
  String get versionsLabel => versions == 1 ? '1 versión' : '$versions versiones';
}

class _StarsAndVersions extends StatelessWidget {
  const _StarsAndVersions(this.stats, {this.compact = false});
  final _DishStats stats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.w700, color: AppColors.textMuted);
    return Row(
      children: [
        Icon(Icons.star_rounded, size: compact ? 14 : 16, color: AppColors.gold),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            compact
                ? stats.ratingLabel
                : (stats.rating.count == 0
                      ? 'Sin reseñas'
                      : '${stats.rating.average.toStringAsFixed(1)} · ${stats.reviewsLabel}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.account_tree_rounded, size: compact ? 12 : 14, color: AppColors.textMuted),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            compact ? '${stats.versions}' : stats.versionsLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// Small uppercase time label shown under photos ("20 MINUTOS").
class _TimeLabel extends StatelessWidget {
  const _TimeLabel(this.minutes);
  final int? minutes;

  @override
  Widget build(BuildContext context) => minutes == null
      ? const SizedBox.shrink()
      : Text(
          Fmt.minutes(minutes!).toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        );
}

BoxDecoration _cardDecoration() =>
    BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppTheme.radiusL));

/// Big featured card: photo, time, name, description, rating and versions.
class FeaturedRecipeCard extends ConsumerWidget {
  const FeaturedRecipeCard({super.key, required this.recipe, this.imageHeight = 180, this.badge});
  final Recipe recipe;
  final double imageHeight;

  /// Optional label over the photo, e.g. "#1 · ★ 5.0 esta semana".
  final String? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = _DishStats(ref, recipe);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        onTap: () => context.push('/recipe/${recipe.id}'),
        child: Ink(
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  RecipeImage(url: recipe.imageUrl, height: imageHeight, radius: AppTheme.radiusL),
                  Positioned(top: 10, right: 10, child: FavoriteButton(recipeId: recipe.id)),
                  if (badge != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          badge!,
                          style: TextStyle(color: AppColors.onAccent, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TimeLabel(stats.minutes),
                    const SizedBox(height: 4),
                    Text(
                      recipe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    _StarsAndVersions(stats),
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

/// Small card: photo, time, name, rating and versions.
class CompactRecipeCard extends ConsumerWidget {
  const CompactRecipeCard({super.key, required this.recipe, this.imageHeight = 110});
  final Recipe recipe;
  final double imageHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = _DishStats(ref, recipe);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        onTap: () => context.push('/recipe/${recipe.id}'),
        child: Ink(
          decoration: _cardDecoration().copyWith(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecipeImage(url: recipe.imageUrl, height: imageHeight, radius: AppTheme.radiusM),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TimeLabel(stats.minutes),
                    const SizedBox(height: 2),
                    Text(
                      recipe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    _StarsAndVersions(stats, compact: true),
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

/// List row like "Populares": thumbnail, name, rating (reviews) · versions, time, favorite.
class RecipeRow extends ConsumerWidget {
  const RecipeRow({super.key, required this.recipe, this.rank, this.note});
  final Recipe recipe;

  /// Position in a ranking (1 = first), shown over the photo.
  final int? rank;

  /// Extra line under the stats, e.g. "★ 5.0 · 2 reseñas esta semana".
  final String? note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = _DishStats(ref, recipe);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        onTap: () => context.push('/recipe/${recipe.id}'),
        child: Ink(
          padding: const EdgeInsets.all(8),
          decoration: _cardDecoration().copyWith(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  children: [
                    RecipeImage(url: recipe.imageUrl, radius: AppTheme.radiusS),
                    if (rank != null)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: rank == 1 ? AppColors.accent : AppColors.surfaceHigh,
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              color: rank == 1 ? AppColors.onAccent : AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    _StarsAndVersions(stats),
                    if (note != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FavoriteButton(recipeId: recipe.id, onImage: false),
                  if (stats.minutes != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(Fmt.minutes(stats.minutes!), style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
