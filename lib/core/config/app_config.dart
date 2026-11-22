/// Build-time configuration (pass with --dart-define).
///
///   flutter run --dart-define=MISKI_API_URL=http://192.168.1.50:8000/api/v1
///
/// Without MISKI_API_URL the app runs in demo mode: an in-memory backend
/// seeded with sample data, useful for tests and for showing the app offline.
abstract final class AppConfig {
  static const apiUrl = String.fromEnvironment('MISKI_API_URL');

  static bool get isDemo => apiUrl.isEmpty;

  /// Prices and costs (purchase price per ingredient, total and per-person cost,
  /// the costs screen and the "Costo / calidad" rating criterion) are kept in the
  /// code and in the API but hidden for now. Turn them on with
  /// --dart-define=MISKI_SHOW_COSTS=true, or change the default here.
  static const showCosts = bool.fromEnvironment('MISKI_SHOW_COSTS');

  /// How often new notifications and invitations are fetched while the app is open.
  static const pollInterval = Duration(seconds: 45);
}
