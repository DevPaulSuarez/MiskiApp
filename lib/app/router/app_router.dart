import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/recipes/presentation/screens/compare_versions_screen.dart';
import '../../features/recipes/presentation/screens/cookbook_screen.dart';
import '../../features/recipes/presentation/screens/costs_screen.dart';
import '../../features/recipes/presentation/screens/favorites_screen.dart';
import '../../features/recipes/presentation/screens/recipe_detail_screen.dart';
import '../../features/recipes/presentation/screens/search_screen.dart';
import '../../features/recipes/presentation/screens/version_editor_screen.dart';
import '../../features/recipes/presentation/screens/version_history_screen.dart';
import '../../features/social/presentation/screens/comments_screen.dart';
import '../../features/social/presentation/screens/invitations_screen.dart';
import '../../features/social/presentation/screens/invite_screen.dart';
import '../../features/social/presentation/screens/notifications_screen.dart';
import '../../features/social/presentation/screens/rate_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/recipes', builder: (_, _) => const CookbookScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/invitations', builder: (_, _) => const InvitationsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/search', builder: (_, s) => SearchScreen(initialQuery: s.uri.queryParameters['q'])),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/user/:id', builder: (_, s) => ProfileScreen(userId: s.pathParameters['id'])),
      GoRoute(
        path: '/recipe-new',
        builder: (_, s) => VersionEditorScreen(initialName: s.uri.queryParameters['name']),
      ),
      GoRoute(
        path: '/recipe/:id',
        builder: (_, s) => RecipeDetailScreen(recipeId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/recipe/:id/versions',
        builder: (_, s) => VersionHistoryScreen(recipeId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/recipe/:id/compare',
        builder: (_, s) => CompareVersionsScreen(
          recipeId: s.pathParameters['id']!,
          initialA: s.uri.queryParameters['a'],
          initialB: s.uri.queryParameters['b'],
        ),
      ),
      GoRoute(
        path: '/version/:vid',
        builder: (_, s) => RecipeDetailScreen.forVersion(versionId: s.pathParameters['vid']!),
      ),
      GoRoute(
        path: '/version/:vid/derive',
        builder: (_, s) => VersionEditorScreen(parentVersionId: s.pathParameters['vid']),
      ),
      GoRoute(
        path: '/version/:vid/costs',
        builder: (_, s) => CostsScreen(
          versionId: s.pathParameters['vid']!,
          initialServings: int.tryParse(s.uri.queryParameters['servings'] ?? ''),
        ),
      ),
      GoRoute(path: '/version/:vid/invite', builder: (_, s) => InviteScreen(versionId: s.pathParameters['vid']!)),
      GoRoute(
        path: '/version/:vid/rate',
        builder: (_, s) => RateScreen(
          versionId: s.pathParameters['vid']!,
          invitationId: s.uri.queryParameters['inv'],
        ),
      ),
      GoRoute(path: '/version/:vid/comments', builder: (_, s) => CommentsScreen(versionId: s.pathParameters['vid']!)),
    ],
  );
});

class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Recetario'),
            NavigationDestination(icon: Icon(Icons.mail_outline_rounded), selectedIcon: Icon(Icons.mail_rounded), label: 'Invitaciones'),
            NavigationDestination(icon: Icon(Icons.favorite_border_rounded), selectedIcon: Icon(Icons.favorite_rounded), label: 'Favoritos'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
          ],
        ),
      );
}
