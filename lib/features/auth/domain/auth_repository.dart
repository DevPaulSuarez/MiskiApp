import '../../social/domain/social_entities.dart';

class AuthResult {
  const AuthResult({required this.token, required this.user, required this.email});
  final String token;
  final AppUser user;
  final String email;
}

abstract interface class AuthRepository {
  Future<AuthResult> login({required String email, required String password});
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    DateTime? birthday,
  });

  /// Revokes the current token on the server.
  Future<void> logout();
}
