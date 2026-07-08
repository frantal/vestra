import 'hybrid_routing_models.dart';

/// One persisted demo interaction shown in the recent-history panel.
class HybridDemoEntry {
  const HybridDemoEntry({
    required this.prompt,
    required this.answer,
    required this.decision,
    required this.timestampIso,
    required this.usedFallbackRemote,
  });

  final String prompt;
  final String answer;
  final HybridRoutingDecision decision;
  final String timestampIso;
  final bool usedFallbackRemote;

  Map<String, Object?> toJson() {
    return {
      'prompt': prompt,
      'answer': answer,
      'decision': decision.toJson(),
      'timestampIso': timestampIso,
      'usedFallbackRemote': usedFallbackRemote,
    };
  }

  static HybridDemoEntry fromJson(Map<String, Object?> json) {
    return HybridDemoEntry(
      prompt: json['prompt'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      decision: HybridRoutingDecision.fromJson(
        Map<String, Object?>.from(json['decision'] as Map<String, dynamic>),
      ),
      timestampIso: json['timestampIso'] as String? ?? '',
      usedFallbackRemote: json['usedFallbackRemote'] as bool? ?? false,
    );
  }
}

/// Result of executing the demo with the routing agent.
class HybridDemoResult {
  const HybridDemoResult({
    required this.request,
    required this.decision,
    required this.answer,
    required this.executedModelName,
    required this.usedFallbackRemote,
    required this.timestamp,
    required this.entry,
    required this.recentEntries,
  });

  final HybridRoutingRequest request;
  final HybridRoutingDecision decision;
  final String answer;
  final String executedModelName;
  final bool usedFallbackRemote;
  final DateTime timestamp;
  final HybridDemoEntry entry;
  final List<HybridDemoEntry> recentEntries;

  Map<String, Object?> toJson() {
    return {
      'request': request.toJson(),
      'decision': decision.toJson(),
      'answer': answer,
      'executedModelName': executedModelName,
      'usedFallbackRemote': usedFallbackRemote,
      'timestampIso': timestamp.toIso8601String(),
      'entry': entry.toJson(),
      'recentEntries': recentEntries.map((item) => item.toJson()).toList(growable: false),
    };
  }

  static HybridDemoResult fromJson(Map<String, Object?> json) {
    final requestJson = Map<String, Object?>.from(
      json['request'] as Map<String, dynamic>,
    );
    final decisionJson = Map<String, Object?>.from(
      json['decision'] as Map<String, dynamic>,
    );
    final entryJson = Map<String, Object?>.from(
      json['entry'] as Map<String, dynamic>,
    );
    final recentEntriesJson = json['recentEntries'] as List<dynamic>? ?? const [];
    return HybridDemoResult(
      request: HybridRoutingRequest.fromJson(requestJson),
      decision: HybridRoutingDecision.fromJson(decisionJson),
      answer: json['answer'] as String? ?? '',
      executedModelName: json['executedModelName'] as String? ?? '',
      usedFallbackRemote: json['usedFallbackRemote'] as bool? ?? false,
      timestamp: DateTime.parse(json['timestampIso'] as String),
      entry: HybridDemoEntry.fromJson(entryJson),
      recentEntries: recentEntriesJson
          .map((item) => HybridDemoEntry.fromJson(
                Map<String, Object?>.from(item as Map<String, dynamic>),
              ),)
          .toList(growable: false),
    );
  }
}
