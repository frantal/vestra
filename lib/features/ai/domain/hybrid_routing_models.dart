/// The routing target chosen by the hybrid agent.
enum HybridRouteKind {
  local,
  remote,
  memory,
}

/// Input data the router evaluates for each request.
class HybridRoutingRequest {
  const HybridRoutingRequest({
    required this.prompt,
    this.hasImage = false,
    this.imageUrl,
    this.allowRemote = true,
    this.allowMemory = true,
    this.allowFallbackRemote = true,
  });

  final String prompt;
  final bool hasImage;
  final String? imageUrl;
  final bool allowRemote;
  final bool allowMemory;
  final bool allowFallbackRemote;

  Map<String, Object?> toJson() {
    return {
      'prompt': prompt,
      'hasImage': hasImage,
      'imageUrl': imageUrl,
      'allowRemote': allowRemote,
      'allowMemory': allowMemory,
      'allowFallbackRemote': allowFallbackRemote,
    };
  }

  static HybridRoutingRequest fromJson(Map<String, Object?> json) {
    return HybridRoutingRequest(
      prompt: json['prompt'] as String? ?? '',
      hasImage: json['hasImage'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String?,
      allowRemote: json['allowRemote'] as bool? ?? true,
      allowMemory: json['allowMemory'] as bool? ?? true,
      allowFallbackRemote: json['allowFallbackRemote'] as bool? ?? true,
    );
  }
}

/// Final routing decision returned by the hybrid agent.
class HybridRoutingDecision {
  const HybridRoutingDecision({
    required this.kind,
    required this.modelName,
    required this.confidence,
    required this.estimatedLatencyMs,
    required this.estimatedCostUsd,
    required this.rationale,
    required this.signals,
  });

  final HybridRouteKind kind;
  final String modelName;
  final int confidence;
  final int estimatedLatencyMs;
  final double estimatedCostUsd;
  final String rationale;
  final List<String> signals;

  String get pathLabel {
    return switch (kind) {
      HybridRouteKind.local => 'Local',
      HybridRouteKind.remote => 'Remoto',
      HybridRouteKind.memory => 'Memória',
    };
  }

  Map<String, Object?> toJson() {
    return {
      'kind': kind.name,
      'modelName': modelName,
      'confidence': confidence,
      'estimatedLatencyMs': estimatedLatencyMs,
      'estimatedCostUsd': estimatedCostUsd,
      'rationale': rationale,
      'signals': signals,
    };
  }

  static HybridRoutingDecision fromJson(Map<String, Object?> json) {
    return HybridRoutingDecision(
      kind: HybridRouteKind.values.byName(json['kind'] as String),
      modelName: json['modelName'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toInt() ?? 0,
      estimatedLatencyMs: (json['estimatedLatencyMs'] as num?)?.toInt() ?? 0,
      estimatedCostUsd: (json['estimatedCostUsd'] as num?)?.toDouble() ?? 0,
      rationale: json['rationale'] as String? ?? '',
      signals: (json['signals'] as List<dynamic>? ?? const [])
          .map((signal) => signal.toString())
          .toList(growable: false),
    );
  }
}
