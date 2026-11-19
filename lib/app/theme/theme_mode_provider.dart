import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';

/// Light or dark theme chosen by the user (dark by default). Not persisted yet.
class AppBrightnessNotifier extends Notifier<Brightness> {
  @override
  Brightness build() => Brightness.dark;

  void toggle() {
    final next = state == Brightness.dark ? Brightness.light : Brightness.dark;
    // Screens read AppColors roles while building, and pages kept alive by the
    // router aren't recreated, so switch the palette and rebuild every element
    // in this same frame (no flash of mixed colors).
    AppColors.use(next);
    _rebuildWholeApp();
    state = next;
  }

  static void _rebuildWholeApp() {
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(mark);
  }
}

final appBrightnessProvider = NotifierProvider<AppBrightnessNotifier, Brightness>(AppBrightnessNotifier.new);
