import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/hybrid_backend_config.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../infrastructure/hybrid_backend_runtime.dart';
import 'hybrid_demo_engine.dart';
import 'hybrid_demo_local_runtime.dart';
import 'hybrid_demo_memory.dart';
import 'hybrid_demo_runtime.dart';
import 'hybrid_router_provider.dart';

/// Picks the backend runtime when configured, otherwise falls back to local demo logic.
final hybridDemoRuntimeProvider = Provider<HybridDemoRuntime>((ref) {
  if (HybridBackendConfig.isConfigured) {
    return HybridBackendRuntime(baseUrl: HybridBackendConfig.baseUrl);
  }

  final router = ref.watch(hybridRouterProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return HybridDemoLocalRuntime(
    HybridDemoEngine(
      router: router,
      memory: HybridDemoMemory(prefs),
    ),
  );
});
