/// An error the user can read. [fieldErrors] holds per-field validation messages.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;

  bool get isUnauthorized => statusCode == 401;

  /// First error for [field], if any (e.g. "email", "version.steps").
  String? errorFor(String field) => fieldErrors[field]?.firstOrNull;

  static const offline = ApiException('No pudimos conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.');

  @override
  String toString() => message;
}
