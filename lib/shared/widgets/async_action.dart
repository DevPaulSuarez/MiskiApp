import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/network/api_exception.dart';
import 'common_widgets.dart';

/// Shows an error the user can read.
void showError(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : 'Algo salió mal. Inténtalo de nuevo.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(message)));
}

/// Runs a server action behind a blocking progress indicator. Shows [success]
/// when it works and the error message when it fails. Returns null on failure.
Future<T?> runAction<T>(BuildContext context, Future<T> Function() action, {String? success}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var open = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
  ).then((_) => open = false);

  try {
    final result = await action();
    if (open) navigator.pop();
    if (success != null && context.mounted) showSuccess(context, success);
    return result;
  } catch (e) {
    if (open) navigator.pop();
    if (context.mounted) showError(context, e);
    return null;
  }
}

/// Same as [runAction] but without the blocking indicator (for quick, optimistic actions).
Future<void> runQuietly(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}
