import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../domain/entities/recipe.dart';
import '../providers/preparation_providers.dart';
import '../providers/recipe_providers.dart';
import '../../../../core/config/app_config.dart';

/// Version tree: each version shows who derived it from which parent.
class VersionHistoryScreen extends ConsumerStatefulWidget {
  const VersionHistoryScreen({super.key, required this.recipeId});
  final String recipeId;

  @override
  ConsumerState<VersionHistoryScreen> createState() => _VersionHistoryScreenState();
}

class _VersionHistoryScreenState extends ConsumerState<VersionHistoryScreen> {
  final _selected = <String>[];

  List<(RecipeVersion, int)> _flatten(List<RecipeVersion> versions) {
    final ids = versions.map((v) => v.id).toSet();
    final children = <String?, List<RecipeVersion>>{};
    for (final v in versions) {
      final parent = ids.contains(v.parentVersionId) ? v.parentVersionId : null;
      children.putIfAbsent(parent, () => []).add(v);
    }
    final out = <(RecipeVersion, int)>[];
    void walk(String? parent, int depth) {
      for (final v in children[parent] ?? const <RecipeVersion>[]) {
        out.add((v, depth));
        walk(v.id, depth + 1);
      }
    }

    walk(null, 0);
    return out;
  }

  void _toggle(String id) => setState(() {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      if (_selected.length == 2) _selected.removeAt(0);
      _selected.add(id);
    }
  });

  @override
  Widget build(BuildContext context) {
    final recipe = ref.watch(recipeByIdProvider(widget.recipeId));
    final versions = ref.watch(versionsOfRecipeProvider(widget.recipeId));
    final tree = _flatten(versions);
    final costCalc = ref.watch(costCalculatorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Árbol de versiones')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          Text(recipe?.name ?? '', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Las versiones publicadas no se modifican: cada cambio crea una nueva versión. '
            'Selecciona dos para compararlas.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          for (final (v, depth) in tree)
            Padding(
              padding: EdgeInsets.only(left: depth * 22.0, bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (depth > 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 22, right: 4),
                      child: Icon(Icons.subdirectory_arrow_right_rounded, color: AppColors.gold, size: 20),
                    ),
                  Expanded(
                    child: _VersionTile(
                      version: v,
                      isMain: recipe?.mainVersionId == v.id,
                      selected: _selected.contains(v.id),
                      onSelect: () => _toggle(v.id),
                      costPerServing: costCalc.breakdown(v).perServing,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: _selected.length == 2
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/recipe/${widget.recipeId}/compare?a=${_selected[0]}&b=${_selected[1]}'),
              icon: const Icon(Icons.compare_arrows_rounded),
              label: const Text('Comparar', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }
}

class _VersionTile extends ConsumerWidget {
  const _VersionTile({
    required this.version,
    required this.isMain,
    required this.selected,
    required this.onSelect,
    required this.costPerServing,
  });

  final RecipeVersion version;
  final bool isMain;
  final bool selected;
  final VoidCallback onSelect;
  final double costPerServing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = ref.watch(userByIdProvider(version.createdBy));
    final rating = ref.watch(ratingSummaryProvider(version.id));
    final parent = version.parentVersionId == null ? null : ref.watch(versionByIdProvider(version.parentVersionId!));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? AppColors.accent : Colors.transparent, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/version/${version.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'V${version.number}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        if (isMain) const StatusBadge('Principal', color: AppColors.gold),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(version.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        UserAvatar(initials: author.initials, radius: 10),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${versionOwnerLabel(author, ref.watch(currentUserIdProvider))} · ${Fmt.date(version.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (parent != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          ref.watch(basedOnLabelProvider(version.id)) ?? 'Derivada de V${parent.number}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        InfoPill(
                          icon: Icons.star_rounded,
                          label: rating.count == 0
                              ? 'Sin valorar'
                              : '${rating.average.toStringAsFixed(1)} (${rating.count})',
                        ),
                        if (AppConfig.showCosts)
                          InfoPill(icon: Icons.payments_outlined, label: '${Fmt.money(costPerServing)}/pers.'),
                      ],
                    ),
                  ],
                ),
              ),
              Checkbox(value: selected, activeColor: AppColors.accent, onChanged: (_) => onSelect()),
            ],
          ),
        ),
      ),
    );
  }
}
