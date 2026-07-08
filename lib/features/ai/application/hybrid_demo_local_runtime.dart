import '../domain/hybrid_demo_result.dart';
import '../domain/hybrid_routing_models.dart';
import 'hybrid_demo_engine.dart';
import 'hybrid_demo_runtime.dart';

/// Local runtime used when the backend is not configured.
class HybridDemoLocalRuntime implements HybridDemoRuntime {
  HybridDemoLocalRuntime(this._engine);

  final HybridDemoEngine _engine;

  @override
  Future<HybridDemoResult> run(HybridRoutingRequest request) {
    return _engine.run(request);
  }
}
