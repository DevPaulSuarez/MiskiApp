import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/session/backend_providers.dart';
import '../../core/session/session_controller.dart';
import '../../features/social/presentation/providers/social_providers.dart';
import '../../shared/widgets/async_action.dart';

/// Keeps the signed-in app fresh:
///  - pull down on any tab to reload everything;
///  - every [AppConfig.pollInterval] it checks for new notifications and, if
///    there are any (an invitation, a new version of your dish...), reloads;
///  - reloads when the app comes back to the foreground.
class ActivitySync extends ConsumerStatefulWidget {
  const ActivitySync({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ActivitySync> createState() => _ActivitySyncState();
}

class _ActivitySyncState extends ConsumerState<ActivitySync> with WidgetsBindingObserver {
  Timer? _timer;
  bool _busy = false;

  bool get _live => !ref.read(isDemoProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_live) _timer = Timer.periodic(AppConfig.pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _live) _quiet(ref.read(sessionProvider.notifier).refresh);
  }

  Future<void> _poll() => _quiet(() async {
    if (await ref.read(notificationsProvider.notifier).reload()) {
      await ref.read(sessionProvider.notifier).refresh();
    }
  });

  /// Background refreshes never interrupt the user; errors are ignored until the next try.
  Future<void> _quiet(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    // Vertical lists of every tab, including the ones inside tab views.
    notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
    onRefresh: () => runQuietly(context, ref.read(sessionProvider.notifier).refresh),
    child: widget.child,
  );
}
