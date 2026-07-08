import '../domain/hybrid_demo_result.dart';
import '../domain/hybrid_routing_models.dart';
import 'hybrid_demo_memory.dart';
import 'hybrid_router.dart';

/// Runs the hybrid demo end-to-end, including simulated model execution.
class HybridDemoEngine {
  HybridDemoEngine({
    required HybridRouter router,
    required HybridDemoMemory memory,
  })  : _router = router,
        _memory = memory;

  final HybridRouter _router;
  final HybridDemoMemory _memory;

  Future<HybridDemoResult> run(HybridRoutingRequest request) async {
    final decision = _router.route(request);
    final timestamp = DateTime.now();
    var executedDecision = decision;
    var usedFallbackRemote = false;
    var answer = _answerForDecision(request, decision);
    var executedModelName = decision.modelName;

    if (request.allowFallbackRemote &&
        decision.kind == HybridRouteKind.local &&
        decision.confidence < 82) {
      executedDecision = const HybridRoutingDecision(
        kind: HybridRouteKind.remote,
        modelName: 'Remote Reasoning LLM',
        confidence: 84,
        estimatedLatencyMs: 2600,
        estimatedCostUsd: 0.0025,
        rationale: 'Fallback remoto acionado por baixa confiança do modelo local.',
        signals: ['Baixa confiança local'],
      );
      usedFallbackRemote = true;
      executedModelName = executedDecision.modelName;
      answer = _answerForRemoteFallback(request);
    } else if (decision.kind == HybridRouteKind.remote) {
      executedModelName = decision.modelName;
      answer = _answerForRemote(request, decision);
    } else if (decision.kind == HybridRouteKind.memory) {
      final lastEntry = _memory.findLastRelevantEntry(request.prompt);
      answer = _answerForMemory(request, lastEntry);
    }

    final entry = HybridDemoEntry(
      prompt: request.prompt,
      answer: answer,
      decision: executedDecision,
      timestampIso: timestamp.toIso8601String(),
      usedFallbackRemote: usedFallbackRemote,
    );
    await _memory.saveEntry(entry);

    return HybridDemoResult(
      request: request,
      decision: executedDecision,
      answer: answer,
      executedModelName: executedModelName,
      usedFallbackRemote: usedFallbackRemote,
      timestamp: timestamp,
      entry: entry,
      recentEntries: _memory.loadRecentEntries(),
    );
  }

  String _answerForDecision(
    HybridRoutingRequest request,
    HybridRoutingDecision decision,
  ) {
    return switch (decision.kind) {
      HybridRouteKind.local => _answerForLocal(request),
      HybridRouteKind.remote => _answerForRemote(request, decision),
      HybridRouteKind.memory => _answerForMemory(request, _memory.findLastRelevantEntry(request.prompt)),
    };
  }

  String _answerForLocal(HybridRoutingRequest request) {
    final prompt = request.prompt.toLowerCase();
    if (request.hasImage &&
        (prompt.contains('descrev') ||
            prompt.contains('analisa') ||
            prompt.contains('detalh') ||
            prompt.contains('o que tem') ||
            prompt.contains('o que há'))) {
      return 'Análise visual concluída (modo demo):\n'
          '• Imagem recebida e processada localmente\n'
          '• Elementos principais de vestuário identificados\n'
          '• Cores e estilo geral extraídos para recomendação\n\n'
          'Se quiser, já te proponho 2-3 combinações com base nessa análise.';
    }
    if (request.hasImage &&
        (prompt.contains('sugere') ||
            prompt.contains('look') ||
            prompt.contains('outfit') ||
            prompt.contains('combina') ||
            prompt.contains('estilo'))) {
      return 'Com base na imagem, sugiro um look casual equilibrado:\n'
          '• Peça base neutra\n'
          '• Camada leve para contraste\n'
          '• Ténis ou sapato limpo com acessórios discretos';
    }
    if (prompt.contains('cor')) {
      return 'Execução local concluída: a peça foi classificada rapidamente sem gastar tokens remotos.';
    }
    if (prompt.contains('peça') || prompt.contains('camisa')) {
      return 'Execução local concluída: atributos visuais simples analisados com o modelo local.';
    }
    return 'Execução local concluída: resposta rápida gerada no dispositivo.';
  }

  String _answerForRemote(
    HybridRoutingRequest request,
    HybridRoutingDecision decision,
  ) {
    return 'Execução remota concluída: a pergunta "${request.prompt}" pediu mais raciocínio, '
        'por isso o router escolheu ${decision.modelName} para uma resposta mais rica.';
  }

  String _answerForRemoteFallback(HybridRoutingRequest request) {
    return 'Fallback remoto ativado: a análise local não tinha confiança suficiente para "${request.prompt}".';
  }

  String _answerForMemory(
    HybridRoutingRequest request,
    HybridDemoEntry? entry,
  ) {
    if (entry == null) {
      return 'Memória vazia: não encontrei histórico recente para responder "${request.prompt}".';
    }
    return 'Memória persistente encontrada: a última interação relevante foi "${entry.prompt}", '
        'processada via ${entry.decision.pathLabel}.';
  }
}
