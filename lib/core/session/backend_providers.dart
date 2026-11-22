import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/api_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../config/app_config.dart';
import '../demo/demo_backend.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';
import 'api_sync_repository.dart';
import 'app_snapshot.dart';
import 'session_controller.dart';

/// Demo mode (no MISKI_API_URL) or tests: everything is served by [DemoBackend].
final isDemoProvider = Provider<bool>((_) => AppConfig.isDemo);

final demoBackendProvider = Provider<DemoBackend>((_) => DemoBackend());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(baseUrl: AppConfig.apiUrl, onUnauthorized: () => ref.read(sessionProvider.notifier).expire()),
);

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => ref.watch(isDemoProvider) ? (MemoryTokenStorage()..write('demo')) : const SecureTokenStorage(),
);

/// Picks the demo or the HTTP implementation of a repository.
T pickRepository<T>(Ref ref, T Function(ApiClient api) http) =>
    ref.watch(isDemoProvider) ? ref.watch(demoBackendProvider) as T : http(ref.watch(apiClientProvider));

final authRepositoryProvider = Provider<AuthRepository>((ref) => pickRepository(ref, ApiAuthRepository.new));
final syncRepositoryProvider = Provider<SyncRepository>((ref) => pickRepository(ref, ApiSyncRepository.new));
