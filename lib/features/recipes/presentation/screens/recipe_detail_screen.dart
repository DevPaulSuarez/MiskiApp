import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/async_action.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../domain/entities/recipe.dart';
import '../providers/preparation_providers.dart';
import '../providers/recipe_providers.dart';
import '../widgets/recipe_card.dart';

/// Shows a recipe through one selected version. Also used as "version detail".
class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required String this.recipeId}) : versionId = null;
  const RecipeDetailScreen.forVersion({super.key, required String this.versionId}) : recipeId = null;

  final String? recipeId;
  final String? versionId;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  String? _versionId;
  int? _servings;

  @override
  Widget build(BuildContext context) {
    final fixedVersion = widget.versionId == null ? null : ref.watch(versionByIdProvider(widget.versionId!));
    final recipeId = widget.recipeId ?? fixedVersion?.recipeId;
    final recipe = recipeId == null ? null : ref.watch(recipeByIdProvider(recipeId));
    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: 'Receta no encontrada',
          message: 'Puede que haya sido eliminada.',
        ),
      );
    }

    final versions = ref.watch(versionsOfRecipeProvider(recipe.id));
    final version = ref.watch(versionByIdProvider(_versionId ?? widget.versionId ?? recipe.mainVersionId))!;
    final servings = _servings ?? version.servings;
    final factor = ref
        .read(servingCalculatorProvider)
        .factor(originalServings: version.servings, desiredServings: servings);
    final costs = ref.watch(costCalculatorProvider).breakdown(version, servings: servings);
    final rating = ref.watch(ratingSummaryProvider(version.id));
    final comments = ref.watch(commentsOfVersionProvider(version.id));
    final category = ref.watch(categoriesProvider).where((c) => c.id == recipe.categoryId).firstOrNull;
    final isMain = recipe.mainVersionId == version.id;
    final isOwner = recipe.authorId == ref.watch(currentUserIdProvider);
    // Viewing someone else's version while having my own in this dish: ask where to start from.
    final myLatest = ref.watch(myLatestVersionProvider(recipe.id));
    final askBase = myLatest != null && version.createdBy != ref.watch(currentUserIdProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            actions: [
              FavoriteButton(recipeId: recipe.id),
              PopupMenuButton<String>(
                iconColor: AppColors.textPrimary,
                onSelected: (v) => _onMenu(v, recipe, version),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'history', child: Text('Árbol de versiones')),
                  if (versions.length > 1) const PopupMenuItem(value: 'compare', child: Text('Comparar versiones')),
                  // Main version and archiving belong to the dish's author only.
                  if (isOwner && !isMain)
                    const PopupMenuItem(value: 'main', child: Text('Marcar como versión principal')),
                  if (isOwner)
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(recipe.status == RecipeStatus.active ? 'Archivar receta' : 'Restaurar receta'),
                    ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(background: RecipeImage(url: recipe.imageUrl, radius: 0)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category != null)
                    Text(
                      '${category.emoji} ${category.name}'.toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(recipe.name, style: text.headlineSmall),
                  const SizedBox(height: 8),
                  Text(recipe.description, style: text.bodyMedium?.copyWith(height: 1.4)),
                  const SizedBox(height: 16),
                  // Version selector
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // First, so it stays visible however many versions there are.
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: Icon(Icons.account_tree_rounded, size: 18, color: AppColors.accent),
                            label: const Text('Árbol de versiones'),
                            onPressed: () => context.push('/recipe/${recipe.id}/versions'),
                          ),
                        ),
                        for (final v in versions)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                'V${v.number} · ${ref.watch(userByIdProvider(v.createdBy)).firstName}'
                                '${v.id == recipe.mainVersionId ? ' ★' : ''}',
                              ),
                              selected: v.id == version.id,
                              onSelected: (_) => setState(() {
                                _versionId = v.id;
                                _servings = null;
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _VersionBanner(version: version, isMain: isMain),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoPill(icon: Icons.timer_outlined, label: 'Prep. ${Fmt.minutes(version.prepMinutes)}'),
                      if (version.cookMinutes > 0)
                        InfoPill(
                          icon: Icons.local_fire_department_outlined,
                          label: 'Cocción ${Fmt.minutes(version.cookMinutes)}',
                        ),
                      InfoPill(icon: Icons.signal_cellular_alt_rounded, label: version.difficulty.label),
                      InfoPill(icon: Icons.people_outline_rounded, label: 'Original: ${version.servings} pers.'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Servings adjuster
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _ServingsCard(
                servings: servings,
                original: version.servings,
                onChanged: (s) => setState(() => _servings = s),
              ),
            ),
          ),
          SliverToBoxAdapter(child: SectionHeader('Ingredientes (${version.ingredients.length})')),
          SliverList.separated(
            itemCount: version.ingredients.length,
            separatorBuilder: (_, _) => const Divider(indent: 20, endIndent: 20),
            itemBuilder: (_, i) {
              final line = version.ingredients[i];
              final ing = ref.watch(ingredientByIdProvider(line.ingredientId));
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                dense: true,
                leading: const Icon(Icons.circle, size: 8, color: AppColors.gold),
                minLeadingWidth: 8,
                title: Text(ing?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: line.note.isEmpty ? null : Text(line.note),
                trailing: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '${Fmt.qty(line.quantity * factor)} ${line.unit.symbol}',
                    key: ValueKey(servings),
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 15),
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SectionHeader('Preparación')),
          SliverList.builder(
            itemCount: version.steps.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.surfaceHigh,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(version.steps[i], style: text.bodyMedium?.copyWith(height: 1.4)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Costs summary
          SliverToBoxAdapter(
            child: SectionHeader(
              'Costos',
              action: 'Ver desglose',
              onAction: () => context.push('/version/${version.id}/costs?servings=$servings'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Total ($servings pers.)',
                      value: Fmt.money(costs.total),
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Por persona',
                      value: Fmt.money(costs.perServing),
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Ratings
          SliverToBoxAdapter(
            child: SectionHeader(
              'Valoraciones de V${version.number}',
              action: 'Calificar',
              onAction: () => context.push('/version/${version.id}/rate'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: rating.count == 0
                      ? const Text('Esta versión aún no tiene valoraciones.')
                      : Row(
                          children: [
                            Column(
                              children: [
                                Text(rating.average.toStringAsFixed(1), style: text.headlineMedium),
                                StarRating(value: rating.average),
                                const SizedBox(height: 4),
                                Text('${rating.count} valoraciones', style: text.bodySmall),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                children: [
                                  _CriterionBar('Sabor', rating.flavor),
                                  _CriterionBar('Presentación', rating.presentation),
                                  _CriterionBar('Facilidad', rating.ease),
                                  _CriterionBar('Costo/calidad', rating.value),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: OutlinedButton.icon(
                onPressed: () => context.push('/version/${version.id}/comments'),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: Text('Comentarios (${comments.length})'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _OtherPreparations(
              recipe: recipe,
              currentVersionId: version.id,
              onSelect: (id) {
                if (widget.versionId != null) {
                  context.pushReplacement('/version/$id');
                } else {
                  setState(() {
                    _versionId = id;
                    _servings = null;
                  });
                }
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.surfaceHigh)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/version/${version.id}/invite'),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Invitar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () =>
                      askBase ? _chooseBase(version, myLatest) : context.push('/version/${version.id}/derive'),
                  icon: const Icon(Icons.call_split_rounded, size: 18),
                  label: Text(askBase ? 'Nueva versión' : 'Nueva versión desde V${version.number}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lets the user continue their own latest version or branch from the one on screen.
  Future<void> _chooseBase(RecipeVersion viewing, RecipeVersion mine) async {
    final other = ref.read(userByIdProvider(viewing.createdBy));
    final baseId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('¿Desde qué versión partes?', style: Theme.of(ctx).textTheme.titleLarge),
            ),
            ListTile(
              leading: Icon(Icons.person_rounded, color: AppColors.accent),
              title: Text(
                'Continuar mi versión · V${mine.number}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('Tu última modificación: ${mine.title}'),
              trailing: StatusBadge('Recomendado', color: AppColors.success),
              onTap: () => Navigator.pop(ctx, mine.id),
            ),
            ListTile(
              leading: const Icon(Icons.call_split_rounded, color: AppColors.gold),
              title: Text('Partir de la versión de ${other.firstName} · V${viewing.number}'),
              subtitle: const Text('La que estás viendo ahora'),
              onTap: () => Navigator.pop(ctx, viewing.id),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (baseId != null && mounted) context.push('/version/$baseId/derive');
  }

  Future<void> _onMenu(String action, Recipe recipe, RecipeVersion version) async {
    final notifier = ref.read(recipesProvider.notifier);
    switch (action) {
      case 'history':
        context.push('/recipe/${recipe.id}/versions');
      case 'compare':
        final vs = ref.read(versionsOfRecipeProvider(recipe.id));
        final other = vs.firstWhere((v) => v.id != version.id);
        context.push('/recipe/${recipe.id}/compare?a=${other.id}&b=${version.id}');
      case 'main':
        await runAction(
          context,
          () => notifier.setMainVersion(recipe.id, version.id),
          success: 'V${version.number} es ahora la versión principal',
        );
      case 'archive':
        final archiving = recipe.status == RecipeStatus.active;
        if (archiving &&
            !await confirmDialog(
              context,
              'Archivar receta',
              'La receta se ocultará del recetario pero conservará todas sus versiones y valoraciones.',
              confirm: 'Archivar',
            )) {
          return;
        }
        if (!mounted) return;
        await runAction(
          context,
          () => notifier.toggleArchive(recipe.id),
          success: archiving ? 'Receta archivada' : 'Receta restaurada',
        );
    }
  }
}

class _VersionBanner extends ConsumerWidget {
  const _VersionBanner({required this.version, required this.isMain});
  final RecipeVersion version;
  final bool isMain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = ref.watch(userByIdProvider(version.createdBy));
    final owner = versionOwnerLabel(author, ref.watch(currentUserIdProvider));
    final basedOn = ref.watch(basedOnLabelProvider(version.id));
    return GestureDetector(
      onTap: () => context.push('/user/${author.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppTheme.radiusM)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
              child: Text(
                'V${version.number}',
                style: TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$owner${isMain ? ' · Principal' : ''}',
                    style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    version.title,
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    [?basedOn, Fmt.date(version.createdAt)].join(' · '),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// "Otras formas de prepararlo": one card per person, best rated first.
class _OtherPreparations extends ConsumerStatefulWidget {
  const _OtherPreparations({required this.recipe, required this.currentVersionId, required this.onSelect});
  final Recipe recipe;
  final String currentVersionId;
  final ValueChanged<String> onSelect;

  @override
  ConsumerState<_OtherPreparations> createState() => _OtherPreparationsState();
}

class _OtherPreparationsState extends ConsumerState<_OtherPreparations> {
  bool _friendsOnly = false;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider);
    final friends = ref.watch(friendIdsProvider);
    final all = ref.watch(preparationsProvider(widget.recipe.id));
    if (all.length < 2) return const SizedBox.shrink();
    final shown = _friendsOnly ? all.where((p) => friends.contains(p.authorId) || p.authorId == me).toList() : all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Otras formas de prepararlo (${all.length})',
          action: 'Ver árbol',
          onAction: () => context.push('/recipe/${widget.recipe.id}/versions'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: !_friendsOnly,
                onSelected: (_) => setState(() => _friendsOnly = false),
              ),
              ChoiceChip(
                label: const Text('De mis amigos'),
                selected: _friendsOnly,
                onSelected: (_) => setState(() => _friendsOnly = true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text('Ninguno de tus amigos ha preparado este plato todavía.'),
          ),
        for (final p in shown)
          Builder(
            builder: (context) {
              final author = ref.watch(userByIdProvider(p.authorId));
              final basedOn = ref.watch(basedOnLabelProvider(p.version.id));
              final current = p.version.id == widget.currentVersionId;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                selected: current,
                selectedTileColor: AppColors.surfaceHigh,
                leading: UserAvatar(initials: author.initials),
                title: Text(
                  '${versionOwnerLabel(author, me)} · V${p.version.number}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                subtitle: Text([p.version.title, ?basedOn].join(' · ')),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.ratingCount == 0 ? '–' : '${p.average.toStringAsFixed(1)} ★',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold),
                    ),
                    Text('${p.ratingCount} val.', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                onTap: current ? null : () => widget.onSelect(p.version.id),
              );
            },
          ),
      ],
    );
  }
}

class _ServingsCard extends StatelessWidget {
  const _ServingsCard({required this.servings, required this.original, required this.onChanged});
  final int servings;
  final int original;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.people_alt_rounded, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Porciones', style: TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  servings == original
                      ? 'Cantidades originales'
                      : 'x${Fmt.qty(servings / original)} de la receta original',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: servings > 1 ? () => onChanged(servings - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$servings',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onAccent),
            onPressed: servings < 99 ? () => onChanged(servings + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppTheme.radiusM)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    ),
  );
}

class _CriterionBar extends StatelessWidget {
  const _CriterionBar(this.label, this.value);
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 5,
              minHeight: 6,
              backgroundColor: AppColors.surfaceHigh,
              color: AppColors.gold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
