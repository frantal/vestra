import 'package:flutter_test/flutter_test.dart';

import 'package:vestra/features/ai/application/hybrid_router.dart';
import 'package:vestra/features/ai/domain/hybrid_routing_models.dart';

void main() {
  const router = HybridRouter();

  test('routes memory lookups to the cache path', () {
    final decision = router.route(
      const HybridRoutingRequest(prompt: 'O que vesti na última reunião?'),
    );

    expect(decision.kind, HybridRouteKind.memory);
    expect(decision.modelName, 'Memory Cache');
  });

  test('routes simple image questions to local inference', () {
    final decision = router.route(
      const HybridRoutingRequest(prompt: 'Que cor é esta peça?', hasImage: true),
    );

    expect(decision.kind, HybridRouteKind.local);
    expect(decision.modelName, 'Local Vision Model');
  });

  test('routes complex styling requests to remote reasoning', () {
    final decision = router.route(
      const HybridRoutingRequest(
        prompt: 'Tenho estas peças, que look uso para um casamento ao pôr do sol?',
        hasImage: true,
      ),
    );

    expect(decision.kind, HybridRouteKind.remote);
    expect(decision.modelName, 'Remote Reasoning LLM');
  });
}
