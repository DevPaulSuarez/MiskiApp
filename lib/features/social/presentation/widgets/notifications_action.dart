import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../providers/social_providers.dart';

/// App-bar bell with unread badge.
class NotificationsAction extends ConsumerWidget {
  const NotificationsAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return IconButton(
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.wine,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}
