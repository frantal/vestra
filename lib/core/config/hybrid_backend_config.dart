/// Configuration for the optional FastAPI backend.
abstract final class HybridBackendConfig {
  HybridBackendConfig._();

  static const String baseUrl = String.fromEnvironment('HYBRID_BACKEND_URL');

  static bool get isConfigured => baseUrl.isNotEmpty;
}
