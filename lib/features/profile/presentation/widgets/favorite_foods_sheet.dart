import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../social/domain/social_entities.dart';
import '../../../social/presentation/providers/social_providers.dart';

const maxFavoriteFoods = 8;

Future<void> showFavoriteFoodsSheet(BuildContext context, WidgetRef ref, AppUser user) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _FavoriteFoodsSheet(user: user),
);

class _FavoriteFoodsSheet extends ConsumerStatefulWidget {
  const _FavoriteFoodsSheet({required this.user});
  final AppUser user;

  @override
  ConsumerState<_FavoriteFoodsSheet> createState() => _FavoriteFoodsSheetState();
}

class _FavoriteFoodsSheetState extends ConsumerState<_FavoriteFoodsSheet> {
  late final List<String> _foods = [...widget.user.favoriteFoods];
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty || _foods.length >= maxFavoriteFoods) return;
    if (_foods.any((f) => f.toLowerCase() == text.toLowerCase())) {
      _input.clear();
      return;
    }
    setState(() => _foods.add(text));
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final full = _foods.length >= maxFavoriteFoods;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mis comidas favoritas', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Tus amigos las verán en tu perfil para sorprenderte en tu cumpleaños.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _input,
            enabled: !full,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              hintText: full ? 'Máximo $maxFavoriteFoods comidas' : 'Ej. Lomo saltado',
              suffixIcon: IconButton(icon: const Icon(Icons.add_rounded), onPressed: full ? null : _add),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _foods) InputChip(label: Text(f), onDeleted: () => setState(() => _foods.remove(f))),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                ref.read(usersProvider.notifier).setFavoriteFoods(widget.user.id, _foods);
                Navigator.of(context).pop();
              },
              child: const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}
