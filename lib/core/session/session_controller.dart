import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/social/domain/social_entities.dart';
import '../network/api_exception.dart';
import 'app_snapshot.dart';
import 'backend_providers.dart';

/// The signed-in user and the data loaded for them.
class Session {
  const Session({required this.userId, required this.data});
  final String userId;
  final AppSnapshot data;
}

/// null = signed out. While loading (start-up) the splash is shown; an error
/// means the server could not be reached and the splash offers to retry.
class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return null;
    ref.read(apiClientProvider).token = token;
    try {
      return await _load();
    } on ApiException catch (e) {
      if (!e.isUnauthorized) rethrow;
      await ref.read(tokenStorageProvider).clear();
      return null;
    }
  }

  Future<Session> _load() async {
    final data = await ref.read(syncRepositoryProvider).fetch();
    return Session(userId: data.me.id, data: data);
  }

  Future<void> login(String email, String password) async {
    final res = await ref.read(authRepositoryProvider).login(email: email.trim(), password: password);
    await _start(res.token);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    DateTime? birthday,
  }) async {
    final res = await ref
        .read(authRepositoryProvider)
        .register(name: name.trim(), email: email.trim(), password: password, birthday: birthday);
    await _start(res.token);
  }

  Future<void> _start(String token) async {
    ref.read(apiClientProvider).token = token;
    await ref.read(tokenStorageProvider).write(token);
    state = AsyncData(await _load());
  }

  /// Reloads everything from the server (pull to refresh, app resumed).
  Future<void> refresh() async {
    if (state.value == null) return;
    state = AsyncData(await _load());
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } on ApiException {
      // Signing out locally is enough if the server can't be reached.
    }
    await _clear();
  }

  /// The server rejected the token: back to the login screen.
  void expire() {
    if (state.value != null) unawaited(_clear());
  }

  Future<void> _clear() async {
    ref.read(apiClientProvider).token = null;
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(null);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, Session?>(SessionController.new);

final _placeholderMe = AppUser(id: '', name: 'Invitado', handle: '@', bio: '');

/// Data of the current session (empty while signed out).
final snapshotProvider = Provider<AppSnapshot>(
  (ref) => ref.watch(sessionProvider.select((s) => s.value?.data)) ?? AppSnapshot(me: _placeholderMe, email: ''),
);

final currentUserIdProvider = Provider<String>(
  (ref) => ref.watch(sessionProvider.select((s) => s.value?.userId)) ?? '',
);

final currentEmailProvider = Provider<String>((ref) => ref.watch(snapshotProvider).email);
