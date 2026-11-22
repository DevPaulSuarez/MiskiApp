import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/async_action.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../recipes/presentation/providers/recipe_providers.dart';
import '../../domain/social_repository.dart';
import '../providers/social_providers.dart';

class RateScreen extends ConsumerStatefulWidget {
  const RateScreen({super.key, required this.versionId, this.invitationId});
  final String versionId;
  final String? invitationId;

  @override
  ConsumerState<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends ConsumerState<RateScreen> {
  int _stars = 0;
  int _flavor = 0;
  int _presentation = 0;
  int _ease = 0;
  int _value = 0;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final invId = widget.invitationId;
    if (invId != null && !ref.read(ratingsProvider.notifier).canRateInvitation(invId)) {
      showSuccess(context, 'Ya calificaste esta invitación');
      return;
    }
    final ok = await runAction(context, () async {
      await ref
          .read(ratingsProvider.notifier)
          .rate(
            RatingDraft(
              versionId: widget.versionId,
              invitationId: invId,
              stars: _stars,
              flavor: _flavor,
              presentation: _presentation,
              ease: _ease,
              value: _value,
              comment: _comment.text.trim(),
            ),
          );
      return true;
    }, success: '¡Gracias por tu valoración!');
    if (ok == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(versionByIdProvider(widget.versionId))!;
    final recipe = ref.watch(recipeByIdProvider(version.recipeId))!;

    Widget criterion(String label, int value, ValueChanged<int> onChanged) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          StarInput(value: value, onChanged: onChanged, size: 26),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Calificar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RecipeImage(url: recipe.imageUrl, height: 160),
          const SizedBox(height: 12),
          Text(recipe.name, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          Text(
            'V${version.number} · ${version.title}',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Center(
            child: StarInput(value: _stars, onChanged: (v) => setState(() => _stars = v), size: 46),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              const ['Toca para calificar', 'No me gustó', 'Regular', 'Bueno', 'Muy bueno', '¡Excelente!'][_stars],
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  criterion('Sabor', _flavor, (v) => setState(() => _flavor = v)),
                  criterion('Presentación', _presentation, (v) => setState(() => _presentation = v)),
                  criterion('Facilidad', _ease, (v) => setState(() => _ease = v)),
                  criterion('Costo / calidad', _value, (v) => setState(() => _value = v)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _comment,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Comentario (opcional)'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: FilledButton(onPressed: _stars == 0 ? null : _submit, child: const Text('Enviar valoración')),
        ),
      ),
    );
  }
}
