import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../social/domain/social_entities.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../domain/entities/recipe.dart';
import '../providers/recipe_providers.dart';

class CompareVersionsScreen extends ConsumerStatefulWidget {
  const CompareVersionsScreen({super.key, required this.recipeId, this.initialA, this.initialB});
  final String recipeId;
  final String? initialA;
  final String? initialB;

  @override
  ConsumerState<CompareVersionsScreen> createState() => _CompareVersionsScreenState();
}

class _CompareVersionsScreenState extends ConsumerState<CompareVersionsScreen> {
  late String _a;
  late String _b;

  @override
  void initState() {
    super.initState();
    final vs = ref.read(versionsOfRecipeProvider(widget.recipeId));
    _a = widget.initialA ?? vs.first.id;
    _b = widget.initialB ?? vs.last.id;
  }

  @override
  Widget build(BuildContext context) {
    final versions = ref.watch(versionsOfRecipeProvider(widget.recipeId));
    final a = ref.watch(versionByIdProvider(_a))!;
    final b = ref.watch(versionByIdProvider(_b))!;
    final diff = ref.watch(versionComparatorProvider).compare(a, b);
    final costCalc = ref.watch(costCalculatorProvider);
    final costA = costCalc.breakdown(a);
    final costB = costCalc.breakdown(b);
    final rA = ref.watch(ratingSummaryProvider(a.id));
    final rB = ref.watch(ratingSummaryProvider(b.id));
    final cA = ref.watch(commentsOfVersionProvider(a.id)).length;
    final cB = ref.watch(commentsOfVersionProvider(b.id)).length;
    String name(String id) => ref.watch(ingredientByIdProvider(id))?.name ?? '—';
    final me = ref.watch(currentUserIdProvider);
    // Who prepared each version: "V3 · María", or "V1 · Tú" for the current user.
    String ownerName(RecipeVersion v) => v.createdBy == me ? 'Tú' : ref.watch(userByIdProvider(v.createdBy)).firstName;

    Widget picker(String value, ValueChanged<String> onChanged) => DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true),
      items: [
        for (final v in versions)
          DropdownMenuItem(
            value: v.id,
            child: Text('V${v.number} · ${ownerName(v)}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Comparar versiones')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(
            children: [
              Expanded(child: picker(_a, (v) => setState(() => _a = v))),
              IconButton(
                onPressed: () => setState(() {
                  final t = _a;
                  _a = _b;
                  _b = t;
                }),
                icon: Icon(Icons.swap_horiz_rounded, color: AppColors.accent),
              ),
              Expanded(child: picker(_b, (v) => setState(() => _b = v))),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _Row('', 'V${a.number}', 'V${b.number}', header: true),
                  _Row('Tiempo total', Fmt.minutes(a.totalMinutes), Fmt.minutes(b.totalMinutes)),
                  _Row('Dificultad', a.difficulty.label, b.difficulty.label),
                  _Row('Porciones', '${a.servings}', '${b.servings}'),
                  _Row('Costo total', Fmt.money(costA.total), Fmt.money(costB.total)),
                  _Row('Costo/persona', Fmt.money(costA.perServing), Fmt.money(costB.perServing)),
                  _Row('Promedio', _ratingLabel(rA), _ratingLabel(rB)),
                  _Row('Valoraciones', '${rA.count}', '${rB.count}'),
                  _Row('Comentarios', '$cA', '$cB'),
                ],
              ),
            ),
          ),
          if (!rA.isReliable || !rB.isReliable)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.gold),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Una versión con menos de ${RatingSummary.minReliableCount} valoraciones aún no tiene un promedio confiable. '
                        'No se considera mejor solo por tener pocas notas altas.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SectionHeader('Ingredientes'),
          if (diff.added.isEmpty && diff.removed.isEmpty && diff.changed.isEmpty)
            const Text('Sin diferencias en ingredientes.'),
          for (final i in diff.added)
            _DiffTile(
              icon: Icons.add_circle_rounded,
              color: AppColors.success,
              title: name(i.ingredientId),
              detail: 'Agregado · ${Fmt.qty(i.quantity)} ${i.unit.symbol}',
            ),
          for (final i in diff.removed)
            _DiffTile(
              icon: Icons.remove_circle_rounded,
              color: AppColors.danger,
              title: name(i.ingredientId),
              detail: 'Eliminado · era ${Fmt.qty(i.quantity)} ${i.unit.symbol}',
            ),
          for (final c in diff.changed)
            _DiffTile(
              icon: Icons.change_circle_rounded,
              color: AppColors.gold,
              title: name(c.before.ingredientId),
              detail:
                  '${Fmt.qty(c.before.quantity)} ${c.before.unit.symbol}  →  ${Fmt.qty(c.after.quantity)} ${c.after.unit.symbol}',
            ),
          const SectionHeader('Preparación'),
          if (diff.stepsReordered)
            const _DiffTile(
              icon: Icons.swap_vert_rounded,
              color: AppColors.gold,
              title: 'Orden modificado',
              detail: 'Los pasos en común siguen un orden distinto.',
            ),
          for (final s in diff.stepsAdded)
            _DiffTile(icon: Icons.add_circle_rounded, color: AppColors.success, title: 'Paso nuevo', detail: s),
          for (final s in diff.stepsRemoved)
            _DiffTile(icon: Icons.remove_circle_rounded, color: AppColors.danger, title: 'Paso eliminado', detail: s),
          if (!diff.stepsReordered && diff.stepsAdded.isEmpty && diff.stepsRemoved.isEmpty)
            const Text('Sin diferencias en la preparación.'),
          const SectionHeader('Costo por ingrediente'),
          _CostCompare(a: a, b: b, nameOf: name),
        ],
      ),
    );
  }

  String _ratingLabel(RatingSummary r) =>
      r.count == 0 ? '–' : '★ ${r.average.toStringAsFixed(1)}${r.isReliable ? '' : '*'}';
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.a, this.b, {this.header = false});
  final String label;
  final String a;
  final String b;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: header ? FontWeight.w900 : FontWeight.w700,
      color: header ? AppColors.accent : AppColors.textPrimary,
    );
    final differs = !header && a != b;
    return Container(
      color: differs ? AppColors.gold.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(
            flex: 2,
            child: Text(a, textAlign: TextAlign.center, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(b, textAlign: TextAlign.center, style: style),
          ),
        ],
      ),
    );
  }
}

class _DiffTile extends StatelessWidget {
  const _DiffTile({required this.icon, required this.color, required this.title, required this.detail});
  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CostCompare extends ConsumerWidget {
  const _CostCompare({required this.a, required this.b, required this.nameOf});
  final RecipeVersion a;
  final RecipeVersion b;
  final String Function(String) nameOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calc = ref.watch(costCalculatorProvider);
    final ca = {for (final l in calc.breakdown(a).lines) l.ingredientId: l.cost};
    final cb = {for (final l in calc.breakdown(b).lines) l.ingredientId: l.cost};
    final ids = {...ca.keys, ...cb.keys};
    String f(double? v) => v == null ? '—' : Fmt.money(v);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            _Row('Ingrediente', 'V${a.number}', 'V${b.number}', header: true),
            for (final id in ids)
              _Row(nameOf(id), ca.containsKey(id) ? f(ca[id]) : '—', cb.containsKey(id) ? f(cb[id]) : '—'),
          ],
        ),
      ),
    );
  }
}
