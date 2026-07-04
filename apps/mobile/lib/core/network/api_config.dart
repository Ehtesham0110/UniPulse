/// Central place for backend connectivity settings.
///
/// Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=https://api.unipulse.app/api
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // 10.0.2.2 is the Android emulator's alias for the host machine's
    // localhost. Update this (or pass --dart-define) for iOS simulator
    // (use 127.0.0.1) or a real device (use your machine's LAN IP).
    defaultValue: 'http://10.0.2.2:4000/api',
  );
}
