import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vestra/features/ai/application/hybrid_demo_engine.dart';
import 'package:vestra/features/ai/application/hybrid_demo_memory.dart';
import 'package:vestra/features/ai/application/hybrid_router.dart';
import 'package:vestra/features/ai/domain/hybrid_routing_models.dart';

void main() {
  test('persists and reuses recent memory entries', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final engine = HybridDemoEngine(
      router: const HybridRouter(),
      memory: HybridDemoMemory(prefs),
    );

    await engine.run(
      const HybridRoutingRequest(prompt: 'Que cor é esta peça?', hasImage: true),
    );
    final result = await engine.run(
      const HybridRoutingRequest(prompt: 'O que vesti na última reunião?'),
    );

    expect(result.decision.kind, HybridRouteKind.memory);
    expect(result.answer, contains('Memória persistente encontrada'));
  });

  test('falls back to remote when local confidence is low', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final engine = HybridDemoEngine(
      router: const HybridRouter(),
      memory: HybridDemoMemory(prefs),
    );

    final result = await engine.run(
      const HybridRoutingRequest(
        prompt:
            'Tenho esta peça guardada e preciso de uma leitura rápida para decidir se a mantenho, adapto ou substituo.',
      ),
    );

    expect(result.usedFallbackRemote, isTrue);
    expect(result.decision.kind, HybridRouteKind.remote);
    expect(result.answer, contains('Fallback remoto ativado'));
  });
}
