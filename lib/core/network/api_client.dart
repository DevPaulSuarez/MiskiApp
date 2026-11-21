import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Thin JSON client for the Miski API: adds the bearer token, decodes JSON and
/// turns error responses into [ApiException]s with Spanish messages.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient, this.onUnauthorized})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Called when the server rejects the token (expired or revoked session).
  final void Function()? onUnauthorized;

  String? token;

  static const _timeout = Duration(seconds: 20);

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body);
  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Multipart upload of a single file under [field].
  Future<dynamic> upload(String path, String field, String filePath) async {
    final req = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_headers(json: false))
      ..files.add(await http.MultipartFile.fromPath(field, filePath));
    return _handle(() async => http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 60))));
  }

  Uri _uri(String path) => Uri.parse('$baseUrl/${path.startsWith('/') ? path.substring(1) : path}');

  Map<String, String> _headers({bool json = true}) => {
    'Accept': 'application/json',
    if (json) 'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<dynamic> _send(String method, String path, [Object? body]) => _handle(() async {
    final req = http.Request(method, _uri(path))..headers.addAll(_headers());
    if (body != null) req.body = jsonEncode(body);
    return http.Response.fromStream(await _http.send(req).timeout(_timeout));
  });

  Future<dynamic> _handle(Future<http.Response> Function() call) async {
    final http.Response res;
    try {
      res = await call();
    } on SocketException {
      throw ApiException.offline;
    } on TimeoutException {
      throw ApiException.offline;
    } on http.ClientException {
      throw ApiException.offline;
    }

    final decoded = res.body.isEmpty ? null : _tryDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;

    if (res.statusCode == 401) onUnauthorized?.call();
    throw _error(res.statusCode, decoded);
  }

  static dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static ApiException _error(int status, dynamic body) {
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final fields = <String, List<String>>{
      for (final e in (map['errors'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: [for (final m in e.value as List) m.toString()],
    };
    // Validation errors: show the first field message, which is more useful than the summary.
    final message = fields.values.firstOrNull?.firstOrNull ?? map['message'] as String? ?? _fallback(status);
    return ApiException(message.isEmpty ? _fallback(status) : message, statusCode: status, fieldErrors: fields);
  }

  static String _fallback(int status) => switch (status) {
    401 => 'Tu sesión expiró. Vuelve a iniciar sesión.',
    403 => 'No tienes permiso para hacer esto.',
    404 => 'No encontramos lo que buscabas.',
    429 => 'Demasiados intentos. Espera un momento.',
    >= 500 => 'El servidor tuvo un problema. Inténtalo en un momento.',
    _ => 'Algo salió mal. Inténtalo de nuevo.',
  };
}
