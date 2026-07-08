import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hybrid_router.dart';

/// Shared router instance for the hackathon demo.
final hybridRouterProvider = Provider<HybridRouter>((ref) {
  return const HybridRouter();
});
