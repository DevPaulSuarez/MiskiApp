import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../../social/presentation/widgets/notifications_action.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/services/recipe_filters.dart';
import '../providers/recipe_providers.dart';
import '../widgets/recipe_showcase.dart';

class CookbookFiltersNotifier extends Notifier<RecipeFilters> {
  @override
  RecipeFilters build() => const RecipeFilters();

  void setCategory(String? id) => state = state.copyWith(categoryId: () => id);
  void setSize(SizeFilter size) => state = state.copyWith(size: size);
  void setTime(TimeFilter time) => state = state.copyWith(time: time);
  void setSort(RecipeSort sort) => state = state.copyWith(sort: sort);
  void reset() => state = RecipeFilters(sort: state.sort);
}

final cookbookFiltersProvider = NotifierProvider<CookbookFiltersNotifier, RecipeFilters>(CookbookFiltersNotifier.new);

/// Every active dish after applying the cookbook filters and sort.
final filteredRecipesProvider = Provider<List<Recipe>>((ref) {
  final filters = ref.watch(cookbookFiltersProvider);
  return applyRecipeFilters(
    ref.watch(activeRecipesProvider),
    filters,
    mainVersionOf: (r) => ref.watch(versionByIdProvider(r.mainVersionId)),
    ratingOf: (r) {
      final s = ref.watch(recipeRatingSummaryProvider(r.id));
      return (average: s.average, count: s.count, reliable: s.isReliable);
    },
  );
});

/// Dishes ready in this many minutes or less appear under "Rápidas y fáciles".
const quickRecipeMinutes = 30;

/// The screen the app opens on: greeting, search and filters, then four sections:
/// Destacadas, Rápidas y fáciles, Populares de la semana and Todas las recetas.
class CookbookScreen extends ConsumerWidget {
  const CookbookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(cookbookFiltersProvider);
    final notifier = ref.read(cookbookFiltersProvider.notifier);
    final me = ref.watch(userByIdProvider(ref.watch(currentUserIdProvider)));
    final categories = ref.watch(categoriesProvider);
    final recipes = ref.watch(filteredRecipesProvider);
    final featured = ref.watch(featuredRecipesProvider).take(5).toList();
    final weekly = ref.watch(weeklyBestProvider).take(3).toList();
    final browsing = filters.activeCount == 0;
    final quick = browsing
        ? recipes.where((r) {
            final v = ref.watch(versionByIdProvider(r.mainVersionId));
            return v != null && v.totalMinutes <= quickRecipeMinutes;
          }).toList()
        : const <Recipe>[];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Greeting
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hola, ${me.firstName} 👋', style: text.headlineSmall),
                          const SizedBox(height: 2),
                          Text('¿Qué cocinamos hoy?', style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const NotificationsAction(),
                    GestureDetector(
                      onTap: () => context.go('/profile'),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                        child: UserAvatar(initials: me.initials, radius: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Search + filters
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    const Expanded(child: SearchLauncher()),
                    const SizedBox(width: 10),
                    Badge(
                      isLabelVisible: filters.activeCount > 0,
                      label: Text('${filters.activeCount}'),
                      backgroundColor: AppColors.danger,
                      child: Material(
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
                        child: IconButton(
                          tooltip: 'Filtros',
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            showDragHandle: true,
                            isScrollControlled: true,
                            builder: (_) => const _FiltersSheet(),
                          ),
                          icon: Icon(Icons.tune_rounded, color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Category pills
            SliverToBoxAdapter(
              child: SizedBox(
                height: 64,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _Pill(
                      label: 'Todas',
                      selected: filters.categoryId == null,
                      onTap: () => notifier.setCategory(null),
                    ),
                    for (final c in categories)
                      _Pill(
                        label: '${c.emoji} ${c.name}',
                        selected: filters.categoryId == c.id,
                        onTap: () => notifier.setCategory(c.id),
                      ),
                  ],
                ),
              ),
            ),
            // Active size/time filters, removable
            if (filters.size != SizeFilter.any || filters.time != TimeFilter.any)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (filters.size != SizeFilter.any)
                        InputChip(label: Text(filters.size.label), onDeleted: () => notifier.setSize(SizeFilter.any)),
                      if (filters.time != TimeFilter.any)
                        InputChip(label: Text(filters.time.label), onDeleted: () => notifier.setTime(TimeFilter.any)),
                    ],
                  ),
                ),
              ),
            // 1. Destacadas: best rated overall.
            if (browsing && featured.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader('Destacadas')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 336,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: featured.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (_, i) => SizedBox(width: 280, child: FeaturedRecipeCard(recipe: featured[i])),
                  ),
                ),
              ),
            ],
            // 2. Rápidas y fáciles
            if (quick.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader('Rápidas y fáciles')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 196,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: quick.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => SizedBox(width: 150, child: CompactRecipeCard(recipe: quick[i])),
                  ),
                ),
              ),
            ],
            // 3. Populares de la semana: ranked by this week's reviews.
            if (browsing && weekly.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader('Populares de la semana 🔥')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: weekly.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final w = weekly[i];
                    return RecipeRow(
                      recipe: w.recipe,
                      rank: i + 1,
                      note:
                          '★ ${w.average.toStringAsFixed(1)} · '
                          '${w.count == 1 ? '1 reseña' : '${w.count} reseñas'} esta semana',
                    );
                  },
                ),
              ),
            ],
            // 4. Todas las recetas
            SliverToBoxAdapter(
              child: SectionHeader(
                'Todas las recetas (${recipes.length})',
                action: filters.sort.label,
                onAction: () => notifier.setSort(
                  filters.sort == RecipeSort.bestRated ? RecipeSort.mostVoted : RecipeSort.bestRated,
                ),
              ),
            ),
            if (recipes.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.filter_alt_off_rounded,
                  title: 'Ninguna receta coincide',
                  message: 'Prueba quitando algún filtro.',
                  action: OutlinedButton(onPressed: notifier.reset, child: const Text('Quitar filtros')),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.separated(
                  itemCount: recipes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => RecipeRow(recipe: recipes[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Search box look-alike that opens the search screen.
class SearchLauncher extends StatelessWidget {
  const SearchLauncher({super.key});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(AppTheme.radiusM),
    onTap: () => context.push('/search'),
    child: Ink(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppTheme.radiusM)),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.textMuted),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Buscar recetas o ingredientes…',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FiltersSheet extends ConsumerWidget {
  const _FiltersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(cookbookFiltersProvider);
    final n = ref.read(cookbookFiltersProvider.notifier);
    final count = ref.watch(filteredRecipesProvider).length;
    final categories = ref.watch(categoriesProvider);
    final title = Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800);

    Widget group<T>(String label, List<T> values, T selected, String Function(T) text, ValueChanged<T> onTap) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(label, style: title),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in values)
              _Pill(label: text(v), selected: v == selected, onTap: () => onTap(v), spaced: false),
          ],
        ),
      ],
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Filtros', style: Theme.of(context).textTheme.titleLarge)),
                  TextButton(onPressed: n.reset, child: const Text('Limpiar')),
                ],
              ),
              group<String?>('Categoría', [null, ...categories.map((c) => c.id)], f.categoryId, (id) {
                final c = categories.where((c) => c.id == id).firstOrNull;
                return c == null ? 'Todas' : '${c.emoji} ${c.name}';
              }, n.setCategory),
              group<SizeFilter>('Tamaño (porciones)', SizeFilter.values, f.size, (v) => v.label, n.setSize),
              group<TimeFilter>('Tiempo total', TimeFilter.values, f.time, (v) => v.label, n.setTime),
              group<RecipeSort>('Ordenar por', RecipeSort.values, f.sort, (v) => v.label, n.setSort),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(count == 1 ? 'Ver 1 receta' : 'Ver $count recetas'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap, this.spaced = true});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool spaced;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(right: spaced ? 8 : 0),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      shape: const StadiumBorder(),
      side: BorderSide.none,
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.surfaceHigh,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, color: selected ? AppColors.onAccent : AppColors.textPrimary),
    ),
  );
}
