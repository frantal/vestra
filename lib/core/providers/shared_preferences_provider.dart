import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage keys used with [SharedPreferences]. Centralized to avoid typos.
abstract final class PrefKeys {
  PrefKeys._();

  static const String onboardingSeen = 'onboarding_seen';
  static const String hybridUseBackend = 'hybrid_use_backend';
  static const String hybridBackendUrl = 'hybrid_backend_url';
  static const String hybridChatSessions = 'hybrid_chat_sessions';
}

/// Provides the app-wide [SharedPreferences] instance.
///
/// The real instance is injected in `main()` via a [ProviderScope] override so
/// reads stay synchronous throughout the app (and are trivially mockable in
/// tests).
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});
