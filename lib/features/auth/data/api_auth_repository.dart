import '../../../core/network/api_client.dart';
import '../../recipes/data/recipe_json.dart';
import '../../social/data/social_json.dart';
import '../domain/auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._api);
  final ApiClient _api;

  static const _device = 'Miski app';

  @override
  Future<AuthResult> login({required String email, required String password}) async =>
      _result(await _api.post('auth/login', {'email': email, 'password': password, 'device_name': _device}) as Json);

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    DateTime? birthday,
  }) async => _result(
    await _api.post('auth/register', {
      'name': name,
      'email': email,
      'password': password,
      if (birthday != null) 'birthday': birthday.toIso8601String().substring(0, 10),
      'device_name': _device,
    }) as Json,
  );

  @override
  Future<void> logout() => _api.post('auth/logout');

  static AuthResult _result(Json j) {
    final user = j['user'] as Json;
    return AuthResult(token: j['token'] as String, user: SocialJson.user(user), email: user['email'] as String);
  }
}
