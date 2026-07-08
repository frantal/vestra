import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/shared_preferences_provider.dart';
import 'hybrid_demo_engine.dart';
import 'hybrid_demo_memory.dart';
import 'hybrid_router_provider.dart';

/// Demo engine used by the VESTRA hackathon screen.
final hybridDemoEngineProvider = Provider<HybridDemoEngine>((ref) {
  final router = ref.watch(hybridRouterProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return HybridDemoEngine(
    router: router,
    memory: HybridDemoMemory(prefs),
  );
});
