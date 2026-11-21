import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/backend_providers.dart';
import '../domain/repositories/recipe_repository.dart';
import 'api_recipe_repositories.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) => pickRepository(ref, ApiRecipeRepository.new));
final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => pickRepository(ref, ApiCatalogRepository.new));
