import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../recipes/presentation/providers/recipe_providers.dart';
import '../providers/social_providers.dart';

class CommentsScreen extends ConsumerStatefulWidget {
  const CommentsScreen({super.key, required this.versionId});
  final String versionId;

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    ref.read(commentsProvider.notifier).add(widget.versionId, t);
    _text.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(versionByIdProvider(widget.versionId))!;
    final comments = ref.watch(commentsOfVersionProvider(widget.versionId));
    final ratings = ref.watch(ratingsProvider).where((r) => r.versionId == widget.versionId).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Comentarios · V${version.number}')),
      body: Column(children: [
        Expanded(
          child: comments.isEmpty && ratings.isEmpty
              ? const EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Sin comentarios',
                  message: 'Sé el primero en comentar esta versión.',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final c in comments)
                      _Bubble(
                        userId: c.userId,
                        text: c.text,
                        date: c.createdAt,
                      ),
                    if (ratings.isNotEmpty) const SectionHeader('Historial de valoraciones'),
                    for (final r in ratings)
                      _Bubble(userId: r.userId, text: r.comment.isEmpty ? 'Sin comentario' : r.comment, date: r.createdAt, stars: r.stars),
                  ],
                ),
        ),
        SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.beigeSoft)),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Escribe un comentario…', isDense: true),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.wine),
                onPressed: _send,
                icon: const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.userId, required this.text, required this.date, this.stars});
  final String userId;
  final String text;
  final DateTime date;
  final int? stars;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userByIdProvider(userId));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => context.push('/user/${user.id}'),
          child: UserAvatar(initials: user.initials),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.beigeSoft),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/user/${user.id}'),
                    child: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                Text(Fmt.relative(date), style: Theme.of(context).textTheme.bodySmall),
              ]),
              if (stars != null) StarRating(value: stars!.toDouble(), size: 14),
              const SizedBox(height: 4),
              Text(text),
            ]),
          ),
        ),
      ]),
    );
  }
}
