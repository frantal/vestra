/// Supabase connection configuration.
///
/// Values are injected at build/run time and never hard-coded, e.g.:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
///
/// When the values are absent (e.g. local UI development or tests), the app
/// runs without a backend and auth calls degrade gracefully.
abstract final class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Whether valid backend credentials were provided at build time.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
