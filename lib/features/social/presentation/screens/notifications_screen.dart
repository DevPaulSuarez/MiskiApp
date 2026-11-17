import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../providers/social_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (items.any((n) => !n.read))
            TextButton(onPressed: notifier.markAllRead, child: const Text('Marcar leídas')),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(icon: Icons.notifications_none_rounded, title: 'Todo al día', message: 'No tienes notificaciones.')
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (_, i) {
                final n = items[i];
                return ListTile(
                  tileColor: n.read ? null : AppColors.gold.withValues(alpha: 0.08),
                  leading: CircleAvatar(
                    backgroundColor: n.read ? AppColors.beigeSoft : AppColors.wine,
                    child: Icon(Icons.notifications_rounded, color: n.read ? AppColors.forest : Colors.white, size: 20),
                  ),
                  title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w800)),
                  subtitle: Text('${n.body}\n${Fmt.relative(n.createdAt)}'),
                  isThreeLine: true,
                  onTap: () {
                    notifier.markRead(n.id);
                    final route = n.route;
                    if (route == null) return;
                    // Tab routes switch tabs; detail routes are pushed.
                    const tabs = ['/', '/recipes', '/invitations', '/favorites', '/profile'];
                    tabs.contains(route) ? context.go(route) : context.push(route);
                  },
                );
              },
            ),
    );
  }
}
