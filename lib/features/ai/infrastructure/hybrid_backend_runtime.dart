import 'dart:convert';

import 'package:http/http.dart' as http;

import '../application/hybrid_demo_runtime.dart';
import '../domain/hybrid_demo_result.dart';
import '../domain/hybrid_routing_models.dart';

/// HTTP client for the FastAPI backend.
class HybridBackendRuntime implements HybridDemoRuntime {
  HybridBackendRuntime({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  Future<HybridDemoResult> run(HybridRoutingRequest request) async {
    final uri = Uri.parse('$baseUrl/v1/hybrid/run');
    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Backend returned ${response.statusCode}: ${response.body}',
        uri,
      );
    }

    return HybridDemoResult.fromJson(
      Map<String, Object?>.from(
        jsonDecode(response.body) as Map<String, dynamic>,
      ),
    );
  }
}
