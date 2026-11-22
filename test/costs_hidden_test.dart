import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miski_app/core/config/app_config.dart';
import 'package:miski_app/core/session/session_controller.dart';
import 'package:miski_app/features/recipes/presentation/screens/compare_versions_screen.dart';
import 'package:miski_app/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:miski_app/features/social/presentation/screens/rate_screen.dart';

/// Prices and costs stay in the code but are hidden while AppConfig.showCosts is off.
void main() {
  Future<void> show(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(400, 3000)); // tall: everything is built
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: _SignedIn(child: screen)),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('costs are off by default', () => expect(AppConfig.showCosts, isFalse));

  testWidgets('recipe detail shows no costs', (tester) async {
    await show(tester, const RecipeDetailScreen(recipeId: 'r1'));
    expect(find.text('Costos'), findsNothing);
    expect(find.text('Por persona'), findsNothing);
    expect(find.text('Costo/calidad'), findsNothing);
    expect(find.text('Sabor'), findsWidgets); // the rest of the ratings stay
  });

  testWidgets('comparing versions shows no costs', (tester) async {
    await show(tester, const CompareVersionsScreen(recipeId: 'r1', initialA: 'v1', initialB: 'v2'));
    expect(find.text('Costo total'), findsNothing);
    expect(find.text('Costo por ingrediente'), findsNothing);
    expect(find.text('Tiempo total'), findsOneWidget);
  });

  testWidgets('rating has no cost criterion', (tester) async {
    await show(tester, const RateScreen(versionId: 'v4'));
    expect(find.text('Costo / calidad'), findsNothing);
    expect(find.text('Sabor'), findsOneWidget);
  });
}

/// Waits for the demo session before showing [child].
class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(sessionProvider).hasValue ? child : const SizedBox();
}
