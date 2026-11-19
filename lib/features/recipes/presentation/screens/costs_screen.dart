import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/recipe_providers.dart';

class CostsScreen extends ConsumerStatefulWidget {
  const CostsScreen({super.key, required this.versionId, this.initialServings});
  final String versionId;
  final int? initialServings;

  @override
  ConsumerState<CostsScreen> createState() => _CostsScreenState();
}

class _CostsScreenState extends ConsumerState<CostsScreen> {
  int? _servings;

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(versionByIdProvider(widget.versionId))!;
    final servings = _servings ?? widget.initialServings ?? version.servings;
    final costs = ref.watch(costCalculatorProvider).breakdown(version, servings: servings);
    final maxCost = costs.lines.fold<double>(0, (m, l) => (l.cost ?? 0) > m ? l.cost! : m);

    return Scaffold(
      appBar: AppBar(title: Text('Costos · V${version.number}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppTheme.radiusL)),
            child: Column(
              children: [
                Text('Costo total', style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text(
                  Fmt.money(costs.total),
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 36, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${Fmt.money(costs.perServing)} por persona',
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: servings > 1 ? () => setState(() => _servings = servings - 1) : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$servings personas',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => setState(() => _servings = servings + 1),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'El precio de compra es lo que pagas en el mercado. El costo utilizado es solo la parte proporcional '
            'que usa esta receta.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final l in costs.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ref.watch(ingredientByIdProvider(l.ingredientId))?.name ?? '—',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            l.cost == null ? 'Sin precio' : Fmt.money(l.cost!),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: l.cost == null ? AppColors.textMuted : AppColors.accent,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (l.cost != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxCost == 0 ? 0 : l.cost! / maxCost,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceHigh,
                            color: AppColors.gold,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _Kv('Usado', '${Fmt.qty(l.usedQuantity)} ${l.line.unit.symbol}')),
                          Expanded(
                            child: _Kv(
                              'Compra',
                              l.line.purchase == null
                                  ? '—'
                                  : '${Fmt.qty(l.line.purchase!.quantity)} ${l.line.purchase!.unit.symbol} a ${Fmt.money(l.line.purchase!.price)}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k, style: Theme.of(context).textTheme.bodySmall),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    ],
  );
}
