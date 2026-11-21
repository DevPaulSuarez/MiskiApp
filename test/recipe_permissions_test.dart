import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miski_app/core/session/session_controller.dart';
import 'package:miski_app/features/recipes/presentation/providers/recipe_providers.dart';
import 'package:miski_app/features/recipes/presentation/screens/recipe_detail_screen.dart';

// Current user is u1 (Paul): r1 (ceviche) is his, r2 (ensalada andina) is María's.
void main() {
  test('only the author can change the main version or archive', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(sessionProvider.future); // demo backend, signed in as u1
    final recipes = c.read(recipesProvider.notifier);

    await recipes.setMainVersion('r1', 'v1');
    expect(c.read(recipeByIdProvider('r1'))!.mainVersionId, 'v1');

    expect(recipes.canManage('r2'), isFalse);
    await expectLater(recipes.setMainVersion('r2', 'v4'), throwsStateError);
    await expectLater(recipes.toggleArchive('r2'), throwsStateError);
  });

  Future<void> openMenu(WidgetTester tester, String recipeId) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: RecipeDetailScreen(recipeId: recipeId)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
  }

  testWidgets('menu hides owner-only actions on someone else\'s dish', (tester) async {
    await openMenu(tester, 'r2');
    expect(find.text('Árbol de versiones'), findsWidgets);
    expect(find.text('Archivar receta'), findsNothing);
    expect(find.text('Marcar como versión principal'), findsNothing);
  });

  testWidgets('menu shows owner-only actions on my own dish', (tester) async {
    await openMenu(tester, 'r1'); // main is V2, so V2 is shown and "mark as main" is hidden
    expect(find.text('Archivar receta'), findsOneWidget);
  });
}
