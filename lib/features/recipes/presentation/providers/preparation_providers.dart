import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../social/domain/social_entities.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/services/dish_matcher.dart';
import 'recipe_providers.dart';

final dishMatcherProvider = Provider((_) => const DishMatcher());

/// Each person's way of preparing a dish (their best version), best rated first.
final preparationsProvider = Provider.family<List<Preparation>, String>((ref, recipeId) {
  final versions = ref.watch(versionsOfRecipeProvider(recipeId));
  return preparationsByAuthor(versions, (vid) {
    final s = ref.watch(ratingSummaryProvider(vid));
    return (average: s.average, count: s.count);
  });
});

/// "Tu versión" / "Versión de María".
String versionOwnerLabel(AppUser author, String meId) =>
    author.id == meId ? 'Tu versión' : 'Versión de ${author.firstName}';

/// "Basada en V2 de Carlos" when the version builds on someone else's, else null.
final basedOnLabelProvider = Provider.family<String?, String>((ref, versionId) {
  final RecipeVersion? v = ref.watch(versionByIdProvider(versionId));
  if (v?.parentVersionId == null) return null;
  final parent = ref.watch(versionByIdProvider(v!.parentVersionId!));
  if (parent == null || parent.createdBy == v.createdBy) return null;
  final who = ref.watch(userByIdProvider(parent.createdBy));
  final me = ref.watch(currentUserIdProvider);
  return 'Basada en V${parent.number} de ${who.id == me ? 'ti' : who.firstName}';
});

/// The current user's most recent version of a dish, if any: the natural base
/// to keep working on "my" preparation instead of someone else's.
final myLatestVersionProvider = Provider.family<RecipeVersion?, String>((ref, recipeId) {
  final me = ref.watch(currentUserIdProvider);
  final mine = ref.watch(versionsOfRecipeProvider(recipeId)).where((v) => v.createdBy == me).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return mine.lastOrNull;
});
