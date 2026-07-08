import '../domain/hybrid_demo_result.dart';
import '../domain/hybrid_routing_models.dart';

/// Unified execution contract for the VESTRA demo.
abstract interface class HybridDemoRuntime {
  Future<HybridDemoResult> run(HybridRoutingRequest request);
}
