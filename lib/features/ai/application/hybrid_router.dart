import '../domain/hybrid_routing_models.dart';

/// Hybrid router that chooses the cheapest viable path for each request.
///
/// The logic is intentionally transparent for the hackathon demo: it favors
/// memory/cache first, then local inference for simple tasks, and remote
/// reasoning only when the request complexity justifies the cost.
class HybridRouter {
  const HybridRouter();

  static const double _remoteBaselineCostUsd = 0.0025;

  HybridRoutingDecision route(HybridRoutingRequest request) {
    final normalized = request.prompt.toLowerCase().trim();
    final signals = <String>[];

    if (normalized.isEmpty) {
      return const HybridRoutingDecision(
        kind: HybridRouteKind.local,
        modelName: 'Local Vision/Text Model',
        confidence: 52,
        estimatedLatencyMs: 180,
        estimatedCostUsd: 0,
        rationale: 'Sem prompt explícito, o router assume um caminho local.',
        signals: ['Prompt vazio'],
      );
    }

    if (request.allowMemory && _containsAny(normalized, _memoryKeywords)) {
      signals.add('Consulta de histórico detetada');
      return HybridRoutingDecision(
        kind: HybridRouteKind.memory,
        modelName: 'Memory Cache',
        confidence: 97,
        estimatedLatencyMs: 40,
        estimatedCostUsd: 0,
        rationale: 'A resposta pode ser servida pelo histórico local.',
        signals: signals,
      );
    }

    var complexityScore = 0;

    if (request.hasImage) {
      complexityScore += 1;
      signals.add('Imagem anexada');
    }

    if (_containsAny(normalized, _simpleVisualKeywords)) {
      complexityScore -= 2;
      signals.add('Pedido simples de visão');
    }

    if (_containsAny(normalized, _remoteKeywords)) {
      complexityScore += 3;
      signals.add('Pedido de raciocínio avançado');
    }

    if (normalized.length > 120) {
      complexityScore += 1;
      signals.add('Texto longo');
    }

    if (!request.hasImage && normalized.length > 40) {
      complexityScore += 1;
      signals.add('Sem imagem e contexto alargado');
    }

    if (_containsAny(normalized, _localKeywords)) {
      complexityScore -= 1;
      signals.add('Atributo direto ou classificação rápida');
    }

    if (request.allowRemote && complexityScore >= 3) {
      return HybridRoutingDecision(
        kind: HybridRouteKind.remote,
        modelName: 'Remote Reasoning LLM',
        confidence: 84,
        estimatedLatencyMs: 2600,
        estimatedCostUsd: _remoteBaselineCostUsd,
        rationale: 'O pedido pede síntese, comparação ou raciocínio mais profundo.',
        signals: signals.isEmpty ? const ['Complexidade elevada'] : signals,
      );
    }

    final confidence = request.hasImage
        ? (96 - (complexityScore * 4)).clamp(78, 96).toInt()
        : (84 - (complexityScore * 6)).clamp(68, 90).toInt();

    return HybridRoutingDecision(
      kind: HybridRouteKind.local,
      modelName: request.hasImage ? 'Local Vision Model' : 'Local Text Model',
      confidence: confidence,
      estimatedLatencyMs: request.hasImage ? 420 : 220,
      estimatedCostUsd: 0,
      rationale: 'O pedido é simples o suficiente para correr localmente.',
      signals: signals.isEmpty ? const ['Complexidade baixa'] : signals,
    );
  }

  bool _containsAny(String input, List<String> keywords) {
    return keywords.any(input.contains);
  }

  static const List<String> _memoryKeywords = [
    'última',
    'ultima',
    'histórico',
    'historico',
    'anterior',
    'repeti',
    'usei',
    'vesti',
  ];

  static const List<String> _simpleVisualKeywords = [
    'que cor',
    'qual a cor',
    'que tipo',
    'que peça',
    'o que é isto',
    'identifica',
    'classifica',
  ];

  static const List<String> _localKeywords = [
    'cor',
    'categoria',
    'marca',
    'manga',
    'tecido',
    'tamanho',
    'atributos',
  ];

  static const List<String> _remoteKeywords = [
    'casamento',
    'evento',
    'combina',
    'sugere',
    'recomenda',
    'explica',
    'compara',
    'porquê',
    'porque',
    'estilo',
    'ocasião',
    'ocasiao',
    'melhor',
  ];
}
