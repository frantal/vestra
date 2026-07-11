import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/shared_preferences_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/glass_card.dart';
import '../application/hybrid_demo_runtime.dart';
import '../application/hybrid_demo_runtime_provider.dart';
import '../domain/hybrid_demo_result.dart';
import '../domain/hybrid_routing_models.dart';
import '../infrastructure/hybrid_backend_runtime.dart';
import 'drop_target_wrapper.dart';

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  static const String _defaultBackendUrl = 'https://vestraapi.frantalcompany.com';
  static const String _legacyLocalBackendUrl = 'http://127.0.0.1:8000';

  final TextEditingController _prompt = TextEditingController();
  final TextEditingController _imageUrl = TextEditingController();
  late final TextEditingController _backendUrl;
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _composerFocusNode = FocusNode();
  final ScrollController _conversationScrollController = ScrollController();
  final Stopwatch _executionWatch = Stopwatch();

  bool _hasImage = false;
  bool _allowFallbackRemote = true;
  bool _useBackend = false;
  bool _demoMode = true;
  bool _isRunning = false;
  bool _showInsightsPanel = false;

  String? _error;
  HybridDemoResult? _result;
  int _lastExecutionMs = 0;
  _FlowStage _flowStage = _FlowStage.request;

  List<String> _pickedImageNames = const [];
  List<String> _pickedImageDataUrls = const [];

  List<_PipelineStepData> _pipelineSteps = _defaultPipelineSteps();
  List<_ImageStageData> _imageStages = _defaultImageStages();
  List<_TimelineEvent> _timeline = const [];

  List<_ChatSession> _chatSessions = const [];
  String? _activeSessionId;
  int? _editingTurnIndex;
  _ChatTurn? _pendingTurn;

  static const List<_Scenario> _scenarios = [
    _Scenario(
      label: 'Cor da peça',
      prompt: 'Que cor é esta peça?',
      hasImage: true,
    ),
    _Scenario(
      label: 'Look para casamento',
      prompt: 'Tenho estas peças, que look uso para um casamento ao pôr do sol?',
      hasImage: true,
    ),
    _Scenario(
      label: 'Memória',
      prompt: 'O que vesti na última reunião?',
      hasImage: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final savedBackendUrl = prefs.getString(PrefKeys.hybridBackendUrl);
    final initialBackendUrl = _resolveInitialBackendUrl(savedBackendUrl);
    _backendUrl = TextEditingController(
      text: initialBackendUrl,
    );
    if (savedBackendUrl == null ||
        savedBackendUrl.trim().isEmpty ||
        savedBackendUrl.trim() == _legacyLocalBackendUrl) {
      unawaited(_persistBackendSettings(backendUrl: initialBackendUrl));
    }
    _useBackend = prefs.containsKey(PrefKeys.hybridUseBackend)
        ? (prefs.getBool(PrefKeys.hybridUseBackend) ?? false)
        : true;
    _loadChatSessions();
    _prepareDraftChat();
  }

  @override
  void dispose() {
    _prompt.dispose();
    _imageUrl.dispose();
    _backendUrl.dispose();
    _composerFocusNode.dispose();
    _conversationScrollController.dispose();
    super.dispose();
  }

  static List<_PipelineStepData> _defaultPipelineSteps() {
    return const [
      _PipelineStepData(
        title: 'Receive Request',
        detail: 'Capturando texto, imagem e contexto.',
        status: _PipelineStepStatus.pending,
      ),
      _PipelineStepData(
        title: 'Analyze Intent',
        detail: 'Inferindo intenção do utilizador.',
        status: _PipelineStepStatus.pending,
      ),
      _PipelineStepData(
        title: 'Estimate Complexity',
        detail: 'Estimando custo, latência e profundidade.',
        status: _PipelineStepStatus.pending,
      ),
      _PipelineStepData(
        title: 'Choose Route',
        detail: 'Selecionando memória, local ou remoto.',
        status: _PipelineStepStatus.pending,
      ),
      _PipelineStepData(
        title: 'Execute',
        detail: 'Executando no modelo escolhido.',
        status: _PipelineStepStatus.pending,
      ),
      _PipelineStepData(
        title: 'Generate Response',
        detail: 'Consolidando resposta e telemetria.',
        status: _PipelineStepStatus.pending,
      ),
    ];
  }

  static List<_ImageStageData> _defaultImageStages() {
    return const [
      _ImageStageData(label: 'Analyzing image...'),
      _ImageStageData(label: 'Detecting clothing...'),
      _ImageStageData(label: 'Detecting colors...'),
      _ImageStageData(label: 'Extracting attributes...'),
      _ImageStageData(label: 'Computing embeddings...'),
      _ImageStageData(label: 'Selecting route...'),
      _ImageStageData(label: 'Generating response...'),
    ];
  }

  Duration get _stageDelay => _demoMode
      ? const Duration(milliseconds: 320)
      : const Duration(milliseconds: 140);

  _ChatSession? get _activeSession {
    final id = _activeSessionId;
    if (id == null) return null;
    for (final session in _chatSessions) {
      if (session.id == id) {
        return session;
      }
    }
    return null;
  }

  List<_ChatTurn> get _activeTurns => _activeSession?.turns ?? const [];

  String _resolveInitialBackendUrl(String? savedBackendUrl) {
    final trimmed = savedBackendUrl?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == _legacyLocalBackendUrl) {
      return _defaultBackendUrl;
    }
    return trimmed;
  }

  Future<void> _persistBackendSettings({
    bool? useBackend,
    String? backendUrl,
  }) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (useBackend != null) {
      await prefs.setBool(PrefKeys.hybridUseBackend, useBackend);
    }
    if (backendUrl != null) {
      await prefs.setString(PrefKeys.hybridBackendUrl, backendUrl);
    }
  }

  void _loadChatSessions() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(PrefKeys.hybridChatSessions);
    if (raw == null || raw.trim().isEmpty) {
      setState(() {
        _chatSessions = const [];
        _activeSessionId = null;
      });
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final sessions = decoded
          .map((item) => _ChatSession.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
      setState(() {
        _chatSessions = sessions;
        _activeSessionId = null;
      });
    } catch (_) {
      setState(() {
        _chatSessions = const [];
        _activeSessionId = null;
      });
    }
  }

  Future<void> _persistChatSessions() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final compactSessions = _chatSessions
        .take(20)
        .map((session) => session.copyWith(turns: session.turns.take(8).toList(growable: false)))
        .toList(growable: false);
    final encoded = jsonEncode(
      compactSessions.map((session) => session.toJson()).toList(growable: false),
    );
    await prefs.setString(PrefKeys.hybridChatSessions, encoded);
  }

  void _prepareDraftChat() {
    setState(() {
      _activeSessionId = null;
      _editingTurnIndex = null;
      _prompt.text = '';
      _result = null;
      _error = null;
      _hasImage = false;
      _clearPickedImage();
      _pipelineSteps = _defaultPipelineSteps();
      _imageStages = _defaultImageStages();
      _timeline = const [];
      _prompt.clear();
      _imageUrl.clear();
      _clearPickedImage();
      _flowStage = _FlowStage.request;
    });
  }

  void _openSession(_ChatSession session) {
    HybridDemoResult? sessionResult;
    if (session.turns.isNotEmpty) {
      final lastResultJson = session.turns.last.resultJson;
      if (lastResultJson != null) {
        try {
          sessionResult = HybridDemoResult.fromJson(
            Map<String, Object?>.from(
              jsonDecode(lastResultJson) as Map<String, dynamic>,
            ),
          );
        } catch (_) {
          sessionResult = null;
        }
      }
    }

    setState(() {
      _activeSessionId = session.id;
      _prompt.text = session.turns.isEmpty ? '' : session.turns.last.prompt;
      _result = sessionResult;
      _error = null;
      _editingTurnIndex = null;
      _hasImage = sessionResult?.request.hasImage ?? true;
      _clearPickedImage();
      _pendingTurn = null;
      _flowStage = sessionResult == null
          ? _FlowStage.request
          : _FlowStage.performance;
    });
  }

  void _editTurn(int index) {
    final session = _activeSession;
    if (session == null || index < 0 || index >= session.turns.length) {
      return;
    }
    final turn = session.turns[index];
    setState(() {
      _editingTurnIndex = index;
      _prompt.text = turn.prompt;
      _hasImage = turn.attachmentNames.isNotEmpty || _hasImage;
      _error = null;
    });
    FocusScope.of(context).requestFocus(_composerFocusNode);
  }

  Future<void> _appendTurnToSession(
    String prompt,
    HybridDemoResult result,
    {
      required List<String> attachmentNames,
      int? replaceTurnIndex,
    }
  ) async {
    final now = DateTime.now();
    final turn = _ChatTurn(
      prompt: prompt,
      answer: result.answer,
      timestampIso: now.toIso8601String(),
      resultJson: jsonEncode(_compactResultJson(result, prompt)),
      attachmentNames: List<String>.from(attachmentNames),
    );
    final title = _sessionTitle(prompt);

    final currentId = _activeSessionId;
    if (currentId == null) {
      final session = _ChatSession(
        id: now.microsecondsSinceEpoch.toString(),
        title: title,
        createdAtIso: now.toIso8601String(),
        updatedAtIso: now.toIso8601String(),
        turns: [turn],
      );
      setState(() {
        _chatSessions = [session, ..._chatSessions];
        _activeSessionId = session.id;
      });
      await _persistChatSessions();
      return;
    }

    final updated = [
      for (final session in _chatSessions)
        if (session.id == currentId)
          session.copyWith(
            title: title,
            updatedAtIso: now.toIso8601String(),
            turns: _applyTurnMutation(
              session.turns,
              turn,
              replaceTurnIndex: replaceTurnIndex,
            ),
          )
        else
          session,
    ]..sort((a, b) => b.updatedAtIso.compareTo(a.updatedAtIso));

    setState(() {
      _chatSessions = updated;
    });
    await _persistChatSessions();
  }

  List<_ChatTurn> _applyTurnMutation(
    List<_ChatTurn> turns,
    _ChatTurn nextTurn, {
    int? replaceTurnIndex,
  }) {
    if (replaceTurnIndex == null ||
        replaceTurnIndex < 0 ||
        replaceTurnIndex >= turns.length) {
      return [...turns, nextTurn];
    }
    return [
      ...turns.take(replaceTurnIndex),
      nextTurn,
    ];
  }

  Map<String, Object?> _compactResultJson(HybridDemoResult result, String prompt) {
    return {
      'request': {
        'prompt': prompt,
        'hasImage': result.request.hasImage,
        'imageUrl': result.request.imageUrl,
        'allowRemote': result.request.allowRemote,
        'allowMemory': result.request.allowMemory,
        'allowFallbackRemote': result.request.allowFallbackRemote,
      },
      'decision': result.decision.toJson(),
      'answer': result.answer,
      'executedModelName': result.executedModelName,
      'usedFallbackRemote': result.usedFallbackRemote,
      'timestampIso': result.timestamp.toIso8601String(),
      'entry': {
        'prompt': prompt,
        'answer': result.answer,
        'decision': result.decision.toJson(),
        'timestampIso': result.timestamp.toIso8601String(),
        'usedFallbackRemote': result.usedFallbackRemote,
      },
      'recentEntries': const [],
    };
  }

  String _sessionTitle(String prompt) {
    final compact = prompt.trim();
    if (compact.isEmpty) return 'Novo chat';
    if (compact.length <= 44) return compact;
    return '${compact.substring(0, 44)}...';
  }

  Future<void> _pickImageFromDevice() async {
    final pickedFiles = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (pickedFiles.isEmpty) return;

    final nextNames = <String>[];
    final nextDataUrls = <String>[];

    for (final file in pickedFiles) {
      final bytes = await file.readAsBytes();
      if (bytes.length > 4 * 1024 * 1024) {
        setState(() {
          _error = 'Uma das imagens é maior que 4MB. Seleciona imagens menores.';
        });
        return;
      }
      final mimeType = _inferMimeType(file.name);
      nextNames.add(file.name);
      nextDataUrls.add('data:$mimeType;base64,${base64Encode(bytes)}');
    }

    setState(() {
      _pickedImageNames = nextNames;
      _pickedImageDataUrls = nextDataUrls;
      _hasImage = true;
      _error = null;
    });
  }

  void _removePickedImageAt(int index) {
    if (index < 0 || index >= _pickedImageNames.length) {
      return;
    }
    setState(() {
      _pickedImageNames = [
        for (int i = 0; i < _pickedImageNames.length; i++)
          if (i != index) _pickedImageNames[i],
      ];
      _pickedImageDataUrls = [
        for (int i = 0; i < _pickedImageDataUrls.length; i++)
          if (i != index) _pickedImageDataUrls[i],
      ];
    });
  }

  void _clearPickedImage() {
    _pickedImageNames = const [];
    _pickedImageDataUrls = const [];
  }

  Future<void> _handleDroppedAttachments(List<Map<String, Object?>> attachments) async {
    if (attachments.isEmpty) return;
    setState(() {
      _hasImage = true;
      _pickedImageNames = attachments
          .map((attachment) => attachment['name']?.toString() ?? 'imagem')
          .toList(growable: false);
      _pickedImageDataUrls = attachments
          .map(
            (attachment) {
              final bytes = attachment['bytes'] as List<int>? ?? const <int>[];
              final mimeType = attachment['mimeType']?.toString() ?? 'image/jpeg';
              return 'data:$mimeType;base64,${base64Encode(bytes)}';
            },
          )
          .toList(growable: false);
      _error = null;
    });
  }

  String _inferMimeType(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  void _applyScenario(_Scenario scenario) {
    setState(() {
      _prompt.text = scenario.prompt;
      _hasImage = scenario.hasImage;
      _error = null;
      if (!scenario.hasImage) {
        _clearPickedImage();
      }
    });
  }

  HybridDemoRuntime _runtimeForCurrentSettings() {
    final backendUrl = _backendUrl.text.trim();
    if (_useBackend && backendUrl.isNotEmpty) {
      return HybridBackendRuntime(baseUrl: backendUrl);
    }
    return ref.read(hybridDemoRuntimeProvider);
  }

  Future<void> _beginPipelineStep(int index, {String? detail}) async {
    if (!mounted) return;
    setState(() {
      _pipelineSteps = [
        for (int i = 0; i < _pipelineSteps.length; i++)
          if (i < index)
            _pipelineSteps[i].copyWith(status: _PipelineStepStatus.done)
          else if (i == index)
            _pipelineSteps[i].copyWith(
              status: _PipelineStepStatus.active,
              detail: detail,
            )
          else
            _pipelineSteps[i].copyWith(status: _PipelineStepStatus.pending),
      ];
      _timeline = [
        ..._timeline,
        _TimelineEvent(
          title: _pipelineSteps[index].title,
          elapsedMs: _executionWatch.elapsedMilliseconds,
          status: _PipelineStepStatus.active,
        ),
      ];
    });
  }

  Future<void> _completePipelineStep(int index, {String? detail}) async {
    if (!mounted) return;
    setState(() {
      _pipelineSteps = [
        for (int i = 0; i < _pipelineSteps.length; i++)
          if (i == index)
            _pipelineSteps[i].copyWith(
              status: _PipelineStepStatus.done,
              detail: detail,
            )
          else
            _pipelineSteps[i],
      ];
      _timeline = [
        ..._timeline,
        _TimelineEvent(
          title: '${_pipelineSteps[index].title} concluído',
          elapsedMs: _executionWatch.elapsedMilliseconds,
          status: _PipelineStepStatus.done,
        ),
      ];
    });
  }

  Future<void> _failPipelineStep(int index, String detail) async {
    if (!mounted) return;
    setState(() {
      _pipelineSteps = [
        for (int i = 0; i < _pipelineSteps.length; i++)
          if (i == index)
            _pipelineSteps[i].copyWith(
              status: _PipelineStepStatus.error,
              detail: detail,
            )
          else
            _pipelineSteps[i],
      ];
      _timeline = [
        ..._timeline,
        _TimelineEvent(
          title: '${_pipelineSteps[index].title} falhou',
          elapsedMs: _executionWatch.elapsedMilliseconds,
          status: _PipelineStepStatus.error,
        ),
      ];
    });
  }

  Future<void> _runImageStages() async {
    if (!_hasImage || !mounted) return;

    for (int i = 0; i < _imageStages.length; i++) {
      if (!mounted) return;
      setState(() {
        _imageStages = [
          for (int index = 0; index < _imageStages.length; index++)
            if (index < i)
              _imageStages[index].copyWith(status: _PipelineStepStatus.done)
            else if (index == i)
              _imageStages[index].copyWith(status: _PipelineStepStatus.active)
            else
              _imageStages[index].copyWith(status: _PipelineStepStatus.pending),
        ];
      });
      await Future<void>.delayed(_stageDelay);
    }

    if (!mounted) return;
    setState(() {
      _imageStages = [
        for (final stage in _imageStages)
          stage.copyWith(status: _PipelineStepStatus.done),
      ];
    });
  }

  int _complexityScore(String prompt, bool hasImage) {
    final normalized = prompt.toLowerCase();
    int score = 16;
    if (hasImage) score += 17;
    score += math.min(32, (normalized.length / 8).round());
    if (normalized.contains('look') ||
        normalized.contains('casamento') ||
        normalized.contains('evento') ||
        normalized.contains('combina')) {
      score += 17;
    }
    if (normalized.contains('última') || normalized.contains('memória')) {
      score -= 8;
    }
    return score.clamp(0, 100);
  }

  int _estimatedTokens(HybridDemoResult result) {
    final base = math.max(140, result.request.prompt.length * 2);
    if (result.decision.kind == HybridRouteKind.remote) return base + 900;
    if (result.decision.kind == HybridRouteKind.local) return base + 260;
    return base + 110;
  }

  String _gpuLabel(HybridDemoResult result) {
    if (result.decision.kind == HybridRouteKind.remote) return 'AMD Cloud GPU';
    if (result.decision.kind == HybridRouteKind.local) return 'Local NPU/GPU';
    return 'Memory Cache';
  }

  Future<void> _tryAttachFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      return;
    }

    if (text.startsWith('data:image/')) {
      setState(() {
        _hasImage = true;
        _pickedImageDataUrls = [text];
        _pickedImageNames = ['imagem-colada'];
        _error = null;
      });
      return;
    }

    final uri = Uri.tryParse(text);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      setState(() {
        _hasImage = true;
        _imageUrl.text = text;
        _error = null;
      });
    }
  }

  String? _extractImageUrlFromPrompt(String prompt) {
    final regex = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);
    final match = regex.firstMatch(prompt);
    if (match == null) {
      return null;
    }
    final url = match.group(1);
    if (url == null || url.isEmpty) {
      return null;
    }
    final lower = url.toLowerCase();
    final likelyImage =
        lower.contains('images.unsplash.com') ||
        lower.contains('image') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.contains('format=');
    return likelyImage ? url : null;
  }

  String _currentLiveStatus() {
    if (_isRunning) {
      for (final step in _pipelineSteps) {
        if (step.status == _PipelineStepStatus.active) {
          return 'Pensando: ${step.title}';
        }
      }
      return 'Pensando: processando requisição...';
    }
    if (_timeline.isNotEmpty) {
      return 'Último: ${_timeline.last.title}';
    }
    return 'Pronto para uma nova mensagem.';
  }

  void _scrollConversationToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_conversationScrollController.hasClients) {
        return;
      }
      _conversationScrollController.animateTo(
        _conversationScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _runDemo() async {
    final prompt = _prompt.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _error = 'Escreve uma pergunta para iniciar o chat.';
      });
      return;
    }

    final manualImageUrl = _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim();
    final detectedImageUrl = _extractImageUrlFromPrompt(prompt);
    final selectedImageUrl =
        _pickedImageDataUrls.isNotEmpty ? _pickedImageDataUrls.first : (manualImageUrl ?? detectedImageUrl);
    final hasImageForRequest = selectedImageUrl != null && selectedImageUrl.isNotEmpty;
    final attachmentNames = hasImageForRequest
        ? List<String>.from(_pickedImageNames)
        : const <String>[];
    final editingTurnIndex = _editingTurnIndex;

    setState(() {
      _isRunning = true;
      _error = null;
      _flowStage = _FlowStage.request;
      _pipelineSteps = _defaultPipelineSteps();
      _imageStages = _defaultImageStages();
      _timeline = const [];
      _pendingTurn = _ChatTurn(
        prompt: prompt,
        answer: 'A processar...',
        timestampIso: DateTime.now().toIso8601String(),
        attachmentNames: attachmentNames,
      );
      _prompt.clear();
      _imageUrl.clear();
      _clearPickedImage();
      _editingTurnIndex = null;
    });
    _scrollConversationToEnd();

    _executionWatch
      ..reset()
      ..start();

    try {
      await _beginPipelineStep(0, detail: 'Pedido recebido e normalizado.');
      await Future<void>.delayed(_stageDelay);
      await _completePipelineStep(0);
      setState(() => _flowStage = _FlowStage.router);

      await _beginPipelineStep(1, detail: 'Analisando intenção e contexto.');
      await Future<void>.delayed(_stageDelay);
      await _completePipelineStep(1);

      await _beginPipelineStep(2, detail: 'Estimando complexidade.');
      await Future<void>.delayed(_stageDelay);
      await _completePipelineStep(
        2,
        detail:
            'Complexidade prevista: ${_complexityScore(prompt, _hasImage)}/100.',
      );

      await _beginPipelineStep(3, detail: 'Selecionando a melhor rota.');
      await Future<void>.delayed(_stageDelay);
      await _completePipelineStep(3);
      setState(() => _flowStage = _FlowStage.decision);

      await _beginPipelineStep(4, detail: 'Executando o caminho selecionado.');
      setState(() => _flowStage = _FlowStage.execution);
      await _runImageStages();

      final result = await _runtimeForCurrentSettings().run(
            HybridRoutingRequest(
              prompt: prompt,
              hasImage: hasImageForRequest,
              imageUrl: selectedImageUrl,
              allowFallbackRemote: _allowFallbackRemote,
            ),
          );

      await _completePipelineStep(
        4,
        detail: 'Execução concluída em ${_executionWatch.elapsedMilliseconds} ms.',
      );
      await _beginPipelineStep(5, detail: 'Gerando resposta e telemetria.');
      await Future<void>.delayed(_stageDelay);
      await _completePipelineStep(5);

      _executionWatch.stop();

      if (!mounted) return;
      setState(() {
        _result = result;
        _lastExecutionMs = _executionWatch.elapsedMilliseconds;
        _flowStage = _FlowStage.performance;
        _pendingTurn = null;
      });
      _scrollConversationToEnd();
      await _appendTurnToSession(
        prompt,
        result,
        attachmentNames: attachmentNames,
        replaceTurnIndex: editingTurnIndex,
      );
    } catch (error) {
      _executionWatch.stop();
      await _failPipelineStep(4, 'Falha na execução do modelo.');
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao executar: $error';
        _flowStage = _FlowStage.response;
        _pendingTurn = null;
      });
      _scrollConversationToEnd();
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1024;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hybrid AI Router'),
        actions: [
          IconButton(
            tooltip: wide ? 'Mostrar configurações' : 'Abrir configurações',
            onPressed: () {
              if (wide) {
                setState(() => _showInsightsPanel = !_showInsightsPanel);
                return;
              }
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppColors.background,
                builder: (context) {
                  return SizedBox(
                    height: MediaQuery.of(context).size.height * 0.82,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: _buildSettingsPanel(),
                    ),
                  );
                },
              );
            },
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _buildMainArea(wide: wide),
          ),
        ),
      ),
    );
  }

  Widget _buildMainArea({required bool wide}) {
    return Stack(
      children: [
        Positioned.fill(child: _buildChatTab()),
        if (wide)
          AnimatedPositioned(
            duration: AppDurations.normal,
            curve: Curves.easeInOut,
            top: 0,
            right: 0,
            bottom: 0,
            width: _showInsightsPanel ? 360 : 36,
            child: Row(
              children: [
                if (!_showInsightsPanel)
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () => setState(() => _showInsightsPanel = true),
                      borderRadius: AppRadius.brMd,
                      child: Container(
                        width: 36,
                        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.82),
                          borderRadius: AppRadius.brMd,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                if (_showInsightsPanel)
                  Expanded(
                    child: GlassCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                'Configurações',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => setState(() => _showInsightsPanel = false),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          Expanded(child: _buildSettingsPanel()),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChatTab() {
    final turns = _activeTurns;
    final pendingTurn = _pendingTurn;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _activeSession == null ? 'Novo Chat' : _activeSession!.title,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: _prepareDraftChat,
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text('Novo chat'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        AppSpacing.gapMd,
        Expanded(
          child: ListView(
            controller: _conversationScrollController,
            children: [
              GlassCard(
                child: Column(
                  children: [
                    if (turns.isEmpty && pendingTurn == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Text(
                          'Sem mensagens nesta sessão. Envie a primeira pergunta para criar/continuar o chat.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else ...[
                      for (int i = 0; i < turns.length; i++) ...[
                        _MessageBubble(
                          role: 'Você',
                          text: turns[i].prompt,
                          alignEnd: true,
                          attachmentNames: turns[i].attachmentNames,
                          onEdit: () => _editTurn(i),
                        ),
                        AppSpacing.gapSm,
                        _MessageBubble(
                          role: 'VESTRA AI',
                          text: turns[i].answer,
                          alignEnd: false,
                          attachmentNames: const [],
                        ),
                        AppSpacing.gapMd,
                      ],
                      if (pendingTurn != null) ...[
                        _MessageBubble(
                          role: 'Você',
                          text: pendingTurn.prompt,
                          alignEnd: true,
                          attachmentNames: pendingTurn.attachmentNames,
                        ),
                        AppSpacing.gapSm,
                        const _ThinkingBubble(),
                      ],
                    ],
                  ],
                ),
              ),
              AppSpacing.gapSm,
              _LiveStatusStrip(text: _currentLiveStatus()),
              AppSpacing.gapLg,
            ],
          ),
        ),
        DropTargetWrapper(
          onFilesDropped: _handleDroppedAttachments,
          child: _buildComposerPanel(),
        ),
      ],
    );
  }

  Widget _buildComposerPanel() {
    final isEditing = _editingTurnIndex != null;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mensagem', style: Theme.of(context).textTheme.labelMedium),
          AppSpacing.gapSm,
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.86),
              borderRadius: AppRadius.brMd,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Adicionar imagem',
                  onPressed: _pickImageFromDevice,
                  icon: const Icon(Icons.attach_file_rounded),
                ),
                Expanded(
                  child: Focus(
                    focusNode: _composerFocusNode,
                    onKeyEvent: (node, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      if (event.logicalKey == LogicalKeyboardKey.keyV &&
                          (HardwareKeyboard.instance.isControlPressed ||
                              HardwareKeyboard.instance.isMetaPressed)) {
                        unawaited(_tryAttachFromClipboard());
                        return KeyEventResult.ignored;
                      }
                      if (event.logicalKey != LogicalKeyboardKey.enter) {
                        return KeyEventResult.ignored;
                      }
                      if (HardwareKeyboard.instance.isShiftPressed) {
                        return KeyEventResult.ignored;
                      }
                      if (!_isRunning) {
                        unawaited(_runDemo());
                      }
                      return KeyEventResult.handled;
                    },
                    child: TextField(
                      controller: _prompt,
                      minLines: 1,
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Pergunte ao VESTRA...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Enviar',
                  onPressed: _isRunning ? null : _runDemo,
                  icon: _isRunning
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
          if (_pickedImageNames.isNotEmpty) ...[
            AppSpacing.gapSm,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (int i = 0; i < _pickedImageNames.length; i++)
                  _AttachmentChip(
                    label: _pickedImageNames[i],
                    onRemove: () => _removePickedImageAt(i),
                  ),
              ],
            ),
          ],
          AppSpacing.gapXs,
          Text(
            'Enter para enviar · Shift+Enter para nova linha',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (isEditing) ...[
            AppSpacing.gapXs,
            Text(
              'Editando mensagem anterior',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                  ),
            ),
          ],
          if (_error != null) ...[
            AppSpacing.gapSm,
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    final activeId = _activeSessionId;
    return ListView(
      children: [
        Text('Chats criados', style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.gapSm,
        _SessionTile(
          title: 'Novo chat',
          subtitle: 'Comece uma nova conversa.',
          selected: activeId == null,
          onTap: _prepareDraftChat,
        ),
        AppSpacing.gapSm,
        if (_chatSessions.isEmpty)
          const Text(
            'Sem sessões anteriores.',
            style: TextStyle(color: AppColors.textTertiary),
          )
        else
          ..._chatSessions.map((session) {
            final lastTurn = session.turns.isEmpty ? null : session.turns.last;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _SessionTile(
                title: session.title,
                subtitle: lastTurn?.answer ?? 'Sem resposta ainda.',
                selected: session.id == activeId,
                onTap: () => _openSession(session),
              ),
            );
          }),
        AppSpacing.gapLg,
        Text('Configurações', style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.gapSm,
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _hasImage,
          onChanged: (value) => setState(() {
            _hasImage = value;
            if (!value) {
              _clearPickedImage();
            }
          }),
          title: const Text('Imagem anexada'),
          subtitle: const Text('Ativa modo multimodal.'),
        ),
        if (_hasImage) ...[
          AppTextField(
            label: 'URL da imagem (opcional)',
            hint: 'https://...',
            controller: _imageUrl,
            icon: Icons.link_rounded,
          ),
          AppSpacing.gapSm,
        ],
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _useBackend,
          onChanged: (value) {
            setState(() => _useBackend = value);
            unawaited(_persistBackendSettings(useBackend: value));
          },
          title: const Text('Usar backend FastAPI'),
          subtitle: Text(
            _useBackend && _backendUrl.text.trim().isNotEmpty
                ? 'Ativo: ${_backendUrl.text.trim()}'
                : 'Desligado (runtime local).',
          ),
        ),
        if (_useBackend) ...[
          AppTextField(
            label: 'Backend URL',
            hint: _defaultBackendUrl,
            controller: _backendUrl,
            icon: Icons.settings_ethernet_rounded,
            onChanged: (value) {
              unawaited(_persistBackendSettings(backendUrl: value));
            },
          ),
          AppSpacing.gapSm,
        ],
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _allowFallbackRemote,
          onChanged: (value) => setState(() => _allowFallbackRemote = value),
          title: const Text('Permitir fallback remoto'),
          subtitle: const Text('Eleva para remoto quando necessário.'),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _demoMode,
          onChanged: (value) => setState(() => _demoMode = value),
          title: const Text('Hackathon Mode'),
          subtitle: const Text('Animações mais visíveis para apresentação.'),
        ),
        AppSpacing.gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _scenarios
              .map(
                (scenario) => ActionChip(
                  label: Text(scenario.label),
                  onPressed: () => _applyScenario(scenario),
                ),
              )
              .toList(growable: false),
        ),
        AppSpacing.gapLg,
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(
              'Router insights (oculto)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: const Text('Abrir somente quando precisar para demo'),
            children: [
              SizedBox(
                height: 640,
                child: _buildInsightsTab(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsTab() {
    final result = _result;
    final costFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 4);
    final latencyFormatter = NumberFormat('#,##0');
    return ListView(
      children: [
        _buildHeroCard(),
        AppSpacing.gapLg,
        _buildFlowRail(),
        AppSpacing.gapLg,
        _buildMetricsSection(result, costFormatter, latencyFormatter),
        AppSpacing.gapLg,
        _buildRouterPipeline(),
        if (_hasImage && (_isRunning || _demoMode)) ...[
          AppSpacing.gapLg,
          _buildImagePipeline(),
        ],
        AppSpacing.gapLg,
        _buildDecisionPanel(result, costFormatter),
        AppSpacing.gapLg,
        _buildResultPanel(result, costFormatter),
        AppSpacing.gapLg,
        _buildBenchmarkPanel(result, costFormatter, latencyFormatter),
      ],
    );
  }

  Widget _buildHeroCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
            child: Text(
              'VESTRA AI',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
            ),
          ),
          AppSpacing.gapXs,
          Text(
            'Hybrid AI Wardrobe Agent',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          AppSpacing.gapXs,
          Text(
            'Powered by AMD',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          AppSpacing.gapMd,
          const Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Tag(label: 'AMD Developer Cloud'),
              _Tag(label: 'Fireworks AI'),
              _Tag(label: 'Hybrid Router'),
              _Tag(label: 'Multimodal'),
              _Tag(label: 'Memory'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowRail() {
    const stages = [
      _FlowStage.request,
      _FlowStage.router,
      _FlowStage.decision,
      _FlowStage.execution,
      _FlowStage.response,
      _FlowStage.performance,
    ];
    return GlassCard(
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (int i = 0; i < stages.length; i++) ...[
            _FlowChip(
              label: stages[i].label,
              active: _flowStage == stages[i],
              done: _flowStage.index > stages[i].index,
            ),
            if (i < stages.length - 1)
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsSection(
    HybridDemoResult? result,
    NumberFormat costFormatter,
    NumberFormat latencyFormatter,
  ) {
    final baselineRemote = result == null
        ? 0.0
        : math.max(0.0028, result.decision.estimatedCostUsd * 2.1);
    final savings = result == null
        ? 0.0
        : (baselineRemote - result.decision.estimatedCostUsd).clamp(0, double.infinity);
    final metrics = [
      _MetricData(
        label: 'Latency',
        value: result == null
            ? '--'
            : '${latencyFormatter.format(result.decision.estimatedLatencyMs)} ms',
      ),
      _MetricData(
        label: 'Estimated Cost',
        value: result == null ? '--' : costFormatter.format(result.decision.estimatedCostUsd),
      ),
      _MetricData(
        label: 'Estimated Savings',
        value: result == null ? '--' : costFormatter.format(savings),
      ),
      _MetricData(
        label: 'Selected Route',
        value: result?.decision.pathLabel ?? '--',
      ),
      _MetricData(
        label: 'Confidence',
        value: result == null ? '--' : '${result.decision.confidence}%',
      ),
      _MetricData(
        label: 'Execution Time',
        value: result == null ? '--' : '$_lastExecutionMs ms',
      ),
      _MetricData(
        label: 'GPU',
        value: result == null ? '--' : _gpuLabel(result),
      ),
      _MetricData(
        label: 'Model',
        value: result?.executedModelName ?? '--',
      ),
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live Metrics', style: Theme.of(context).textTheme.titleLarge),
          AppSpacing.gapMd,
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 860 ? 4 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: metrics.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  mainAxisExtent: 94,
                ),
                itemBuilder: (context, index) => _MetricCard(data: metrics[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRouterPipeline() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live Router', style: Theme.of(context).textTheme.titleLarge),
          AppSpacing.gapMd,
          for (int i = 0; i < _pipelineSteps.length; i++) ...[
            _PipelineTile(step: _pipelineSteps[i]),
            if (i < _pipelineSteps.length - 1) ...[
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Icon(
                  Icons.arrow_downward_rounded,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ),
              AppSpacing.gapSm,
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildImagePipeline() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Image Analysis', style: Theme.of(context).textTheme.titleLarge),
          AppSpacing.gapMd,
          ..._imageStages.map((stage) => _ImageStageTile(stage: stage)),
        ],
      ),
    );
  }

  Widget _buildDecisionPanel(HybridDemoResult? result, NumberFormat costFormatter) {
    final complexity = result == null
        ? '--'
        : '${_complexityScore(result.request.prompt, result.request.hasImage)}/100';
    final visionRequired = result?.request.hasImage ?? _hasImage;
    final memoryRequired = result?.decision.kind == HybridRouteKind.memory;
    final remoteRequired = result?.decision.kind == HybridRouteKind.remote ||
        (result?.usedFallbackRemote ?? false);
    final estimatedTokens = result == null ? '--' : '${_estimatedTokens(result)}';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Decision Panel', style: Theme.of(context).textTheme.titleLarge),
          AppSpacing.gapSm,
          Text(
            result?.decision.rationale ??
                'A explicação da decisão aparece após executar um pedido.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          AppSpacing.gapMd,
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _DecisionTile(label: 'Complexity score', value: complexity),
              _DecisionTile(label: 'Vision required?', value: visionRequired ? 'Yes' : 'No'),
              _DecisionTile(label: 'Memory required?', value: memoryRequired ? 'Yes' : 'No'),
              const _DecisionTile(label: 'Database available?', value: 'Yes'),
              _DecisionTile(label: 'Remote required?', value: remoteRequired ? 'Yes' : 'No'),
              _DecisionTile(label: 'Estimated token usage', value: estimatedTokens),
              _DecisionTile(
                label: 'Estimated cost',
                value: result == null ? '--' : costFormatter.format(result.decision.estimatedCostUsd),
              ),
              _DecisionTile(
                label: 'Confidence',
                value: result == null ? '--' : '${result.decision.confidence}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel(HybridDemoResult? result, NumberFormat costFormatter) {
    if (result == null) {
      return GlassCard(
        child: Text(
          'Resultado aparecerá aqui após a execução.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    final baselineRemoteCost = math.max(
      0.0028,
      result.decision.estimatedCostUsd * 2.2,
    );
    final savings = baselineRemoteCost - result.decision.estimatedCostUsd;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Result', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              _RouteBadge(
                kind: result.decision.kind,
                usedFallbackRemote: result.usedFallbackRemote,
              ),
            ],
          ),
          AppSpacing.gapMd,
          Text('AI Response', style: Theme.of(context).textTheme.titleMedium),
          AppSpacing.gapXs,
          Text(result.answer, style: Theme.of(context).textTheme.bodyLarge),
          AppSpacing.gapMd,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: result.decision.signals
                .map((signal) => _Tag(label: signal))
                .toList(growable: false),
          ),
          AppSpacing.gapMd,
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _DecisionTile(label: 'Selected route', value: result.decision.pathLabel),
              _DecisionTile(label: 'Model used', value: result.executedModelName),
              _DecisionTile(label: 'Latency', value: '${result.decision.estimatedLatencyMs} ms'),
              _DecisionTile(
                label: 'Estimated cost',
                value: costFormatter.format(result.decision.estimatedCostUsd),
              ),
              _DecisionTile(
                label: 'Savings',
                value: costFormatter.format(savings.clamp(0, double.infinity)),
              ),
              _DecisionTile(label: 'Execution time', value: '$_lastExecutionMs ms'),
            ],
          ),
          AppSpacing.gapMd,
          Text('Execution timeline', style: Theme.of(context).textTheme.titleMedium),
          AppSpacing.gapSm,
          if (_timeline.isEmpty)
            const Text('Sem eventos.')
          else
            ..._timeline.map((event) => _TimelineTile(event: event)),
        ],
      ),
    );
  }

  Widget _buildBenchmarkPanel(
    HybridDemoResult? result,
    NumberFormat costFormatter,
    NumberFormat latencyFormatter,
  ) {
    final hybridLatency = (result?.decision.estimatedLatencyMs ?? 0).toDouble();
    final hybridCost = result?.decision.estimatedCostUsd ?? 0;
    final hybridTokens = result == null ? 0 : _estimatedTokens(result);

    final double remoteLatency = result == null
        ? 0
        : math.max(hybridLatency * 1.7, hybridLatency + 520).toDouble();
    final double remoteCost = result == null
        ? 0
        : math.max(hybridCost * 2.4, hybridCost + 0.0018).toDouble();
    final remoteTokens = result == null
        ? 0
        : math.max(hybridTokens + 620, (hybridTokens * 1.8).round());

    final latencySavings = remoteLatency <= 0
        ? 0
        : ((remoteLatency - hybridLatency) / remoteLatency * 100);
    final costSavings =
        remoteCost <= 0 ? 0 : ((remoteCost - hybridCost) / remoteCost * 100);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Benchmark Panel', style: Theme.of(context).textTheme.titleLarge),
          AppSpacing.gapSm,
          Text('Hybrid Router vs Always Remote', style: Theme.of(context).textTheme.titleMedium),
          AppSpacing.gapMd,
          _BenchmarkBar(
            label: 'Latency',
            leftLabel: 'Hybrid Router',
            rightLabel: 'Always Remote',
            leftValue: hybridLatency,
            rightValue: remoteLatency,
            leftText: result == null ? '--' : '${latencyFormatter.format(hybridLatency)} ms',
            rightText: result == null ? '--' : '${latencyFormatter.format(remoteLatency)} ms',
          ),
          AppSpacing.gapMd,
          _BenchmarkBar(
            label: 'Cost',
            leftLabel: 'Hybrid Router',
            rightLabel: 'Always Remote',
            leftValue: hybridCost,
            rightValue: remoteCost,
            leftText: result == null ? '--' : costFormatter.format(hybridCost),
            rightText: result == null ? '--' : costFormatter.format(remoteCost),
          ),
          AppSpacing.gapMd,
          _BenchmarkBar(
            label: 'Estimated Tokens',
            leftLabel: 'Hybrid Router',
            rightLabel: 'Always Remote',
            leftValue: hybridTokens.toDouble(),
            rightValue: remoteTokens.toDouble(),
            leftText: result == null ? '--' : '$hybridTokens',
            rightText: result == null ? '--' : '$remoteTokens',
          ),
          AppSpacing.gapMd,
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _DecisionTile(
                label: 'Latency savings',
                value: result == null ? '--' : '${latencySavings.toStringAsFixed(1)}%',
              ),
              _DecisionTile(
                label: 'Cost savings',
                value: result == null ? '--' : '${costSavings.toStringAsFixed(1)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _FlowStage {
  request('Request'),
  router('Router'),
  decision('Decision'),
  execution('Execution'),
  response('Response'),
  performance('Performance');

  const _FlowStage(this.label);
  final String label;
}

class _Scenario {
  const _Scenario({
    required this.label,
    required this.prompt,
    required this.hasImage,
  });

  final String label;
  final String prompt;
  final bool hasImage;
}

enum _PipelineStepStatus {
  pending,
  active,
  done,
  error,
}

class _PipelineStepData {
  const _PipelineStepData({
    required this.title,
    required this.detail,
    required this.status,
  });

  final String title;
  final String detail;
  final _PipelineStepStatus status;

  _PipelineStepData copyWith({
    String? title,
    String? detail,
    _PipelineStepStatus? status,
  }) {
    return _PipelineStepData(
      title: title ?? this.title,
      detail: detail ?? this.detail,
      status: status ?? this.status,
    );
  }
}

class _ImageStageData {
  const _ImageStageData({
    required this.label,
    this.status = _PipelineStepStatus.pending,
  });

  final String label;
  final _PipelineStepStatus status;

  _ImageStageData copyWith({_PipelineStepStatus? status}) {
    return _ImageStageData(
      label: label,
      status: status ?? this.status,
    );
  }
}

class _TimelineEvent {
  const _TimelineEvent({
    required this.title,
    required this.elapsedMs,
    required this.status,
  });

  final String title;
  final int elapsedMs;
  final _PipelineStepStatus status;
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _ChatTurn {
  const _ChatTurn({
    required this.prompt,
    required this.answer,
    required this.timestampIso,
    this.attachmentNames = const [],
    this.resultJson,
  });

  final String prompt;
  final String answer;
  final String timestampIso;
  final List<String> attachmentNames;
  final String? resultJson;

  Map<String, Object?> toJson() {
    final payload = <String, Object?>{
      'prompt': prompt,
      'answer': answer,
      'timestampIso': timestampIso,
      'attachmentNames': attachmentNames,
    };
    if (resultJson != null && resultJson!.length <= 4096) {
      payload['resultJson'] = resultJson;
    }
    return payload;
  }

  static _ChatTurn fromJson(Map<String, dynamic> json) {
    return _ChatTurn(
      prompt: json['prompt'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      timestampIso: json['timestampIso'] as String? ?? '',
      attachmentNames: (json['attachmentNames'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      resultJson: json['resultJson'] as String?,
    );
  }
}

class _ChatSession {
  const _ChatSession({
    required this.id,
    required this.title,
    required this.createdAtIso,
    required this.updatedAtIso,
    required this.turns,
  });

  final String id;
  final String title;
  final String createdAtIso;
  final String updatedAtIso;
  final List<_ChatTurn> turns;

  _ChatSession copyWith({
    String? id,
    String? title,
    String? createdAtIso,
    String? updatedAtIso,
    List<_ChatTurn>? turns,
  }) {
    return _ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      turns: turns ?? this.turns,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAtIso': createdAtIso,
      'updatedAtIso': updatedAtIso,
      'turns': turns.map((turn) => turn.toJson()).toList(growable: false),
    };
  }

  static _ChatSession fromJson(Map<String, dynamic> json) {
    return _ChatSession(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Chat',
      createdAtIso: json['createdAtIso'] as String? ?? '',
      updatedAtIso: json['updatedAtIso'] as String? ?? '',
      turns: (json['turns'] as List<dynamic>? ?? const [])
          .map((item) => _ChatTurn.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.primary.withValues(alpha: 0.45)
        : AppColors.border;
    return InkWell(
      borderRadius: AppRadius.brMd,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface.withValues(alpha: 0.65),
          borderRadius: AppRadius.brMd,
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            AppSpacing.gapXs,
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.role,
    required this.text,
    required this.alignEnd,
    required this.attachmentNames,
    this.onEdit,
  });

  final String role;
  final String text;
  final bool alignEnd;
  final List<String> attachmentNames;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = alignEnd
        ? AppColors.primary.withValues(alpha: 0.18)
        : AppColors.surface.withValues(alpha: 0.85);
    final borderColor = alignEnd
        ? AppColors.primary.withValues(alpha: 0.38)
        : AppColors.border;
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: AppRadius.brMd,
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: alignEnd ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              AppSpacing.gapXs,
              _FormattedMessage(text: text),
              if (alignEnd && onEdit != null) ...[
                AppSpacing.gapSm,
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: const Text('Editar e reenviar'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
              if (attachmentNames.isNotEmpty) ...[
                AppSpacing.gapSm,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: attachmentNames
                      .map(
                        (name) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated.withValues(alpha: 0.7),
                            borderRadius: AppRadius.brPill,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.image_outlined, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                name,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.8),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined, size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: AppRadius.brPill,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormattedMessage extends StatelessWidget {
  const _FormattedMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final spans = <InlineSpan>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isBulletLine(line)) {
        spans.add(
          WidgetSpan(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text('•', style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        );
        spans.addAll(_parseInlineSpans(line.replaceFirst(RegExp(r'^[-*•]\s+'), ''), context));
      } else {
        spans.addAll(_parseInlineSpans(line, context));
      }
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return Text.rich(
      TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: spans,
      ),
    );
  }

  bool _isBulletLine(String line) {
    return line.startsWith('- ') || line.startsWith('* ') || line.startsWith('• ');
  }

  List<InlineSpan> _parseInlineSpans(String line, BuildContext context) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int index = 0;
    for (final match in regex.allMatches(line)) {
      if (match.start > index) {
        spans.add(TextSpan(text: line.substring(index, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      );
      index = match.end;
    }
    if (index < line.length) {
      spans.add(TextSpan(text: line.substring(index)));
    }
    return spans;
  }
}

class _LiveStatusStrip extends StatelessWidget {
  const _LiveStatusStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.62),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.circle,
            size: 8,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.82),
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 10,
                width: 10,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              AppSpacing.gapSm,
              Text(
                'Pensando...',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.76),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _FlowChip extends StatelessWidget {
  const _FlowChip({
    required this.label,
    required this.active,
    required this.done,
  });

  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final bg = done
        ? AppColors.success.withValues(alpha: 0.12)
        : active
            ? AppColors.primary.withValues(alpha: 0.14)
            : AppColors.surface.withValues(alpha: 0.8);
    final fg = done
        ? AppColors.success
        : active
            ? AppColors.primary
            : AppColors.textSecondary;
    return AnimatedContainer(
      duration: AppDurations.normal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.brPill,
        border: Border.all(
          color: done
              ? AppColors.success.withValues(alpha: 0.35)
              : active
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.74),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(data.label, style: Theme.of(context).textTheme.labelMedium),
          AppSpacing.gapXs,
          Text(
            data.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PipelineTile extends StatelessWidget {
  const _PipelineTile({required this.step});

  final _PipelineStepData step;

  @override
  Widget build(BuildContext context) {
    final color = switch (step.status) {
      _PipelineStepStatus.pending => AppColors.textTertiary,
      _PipelineStepStatus.active => AppColors.primary,
      _PipelineStepStatus.done => AppColors.success,
      _PipelineStepStatus.error => AppColors.error,
    };
    final icon = switch (step.status) {
      _PipelineStepStatus.pending => Icons.radio_button_unchecked_rounded,
      _PipelineStepStatus.active => Icons.sync_rounded,
      _PipelineStepStatus.done => Icons.check_circle_rounded,
      _PipelineStepStatus.error => Icons.error_outline_rounded,
    };
    return AnimatedContainer(
      duration: AppDurations.normal,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: color.withValues(alpha: 0.34)),
        boxShadow: step.status == _PipelineStepStatus.active
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: Theme.of(context).textTheme.titleMedium),
                AppSpacing.gapXs,
                Text(step.detail, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (step.status == _PipelineStepStatus.active)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _ImageStageTile extends StatelessWidget {
  const _ImageStageTile({required this.stage});

  final _ImageStageData stage;

  @override
  Widget build(BuildContext context) {
    final color = switch (stage.status) {
      _PipelineStepStatus.pending => AppColors.textTertiary,
      _PipelineStepStatus.active => AppColors.primary,
      _PipelineStepStatus.done => AppColors.success,
      _PipelineStepStatus.error => AppColors.error,
    };
    return AnimatedContainer(
      duration: AppDurations.normal,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            stage.status == _PipelineStepStatus.done
                ? Icons.check_circle_rounded
                : stage.status == _PipelineStepStatus.active
                    ? Icons.sync_rounded
                    : Icons.circle_outlined,
            color: color,
            size: 16,
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Text(
              stage.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
          if (stage.status == _PipelineStepStatus.active)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 210),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          AppSpacing.gapXs,
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _RouteBadge extends StatelessWidget {
  const _RouteBadge({
    required this.kind,
    required this.usedFallbackRemote,
  });

  final HybridRouteKind kind;
  final bool usedFallbackRemote;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      HybridRouteKind.local => AppColors.success,
      HybridRouteKind.remote => AppColors.warning,
      HybridRouteKind.memory => AppColors.primary,
    };
    final label = usedFallbackRemote
        ? 'Fallback'
        : switch (kind) {
            HybridRouteKind.local => 'Local',
            HybridRouteKind.remote => 'Remoto',
            HybridRouteKind.memory => 'Memória',
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});

  final _TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.status) {
      _PipelineStepStatus.pending => AppColors.textTertiary,
      _PipelineStepStatus.active => AppColors.primary,
      _PipelineStepStatus.done => AppColors.success,
      _PipelineStepStatus.error => AppColors.error,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.timeline_rounded, color: color, size: 17),
          AppSpacing.gapSm,
          Expanded(child: Text(event.title)),
          Text(
            '${event.elapsedMs} ms',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _BenchmarkBar extends StatelessWidget {
  const _BenchmarkBar({
    required this.label,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftValue,
    required this.rightValue,
    required this.leftText,
    required this.rightText,
  });

  final String label;
  final String leftLabel;
  final String rightLabel;
  final double leftValue;
  final double rightValue;
  final String leftText;
  final String rightText;

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(leftValue, rightValue);
    final leftRatio = maxValue <= 0 ? 0.0 : leftValue / maxValue;
    final rightRatio = maxValue <= 0 ? 0.0 : rightValue / maxValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.gapSm,
        _BarRow(
          label: leftLabel,
          ratio: leftRatio,
          color: AppColors.primary,
          valueText: leftText,
        ),
        AppSpacing.gapSm,
        _BarRow(
          label: rightLabel,
          ratio: rightRatio,
          color: AppColors.warning,
          valueText: rightText,
        ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.ratio,
    required this.color,
    required this.valueText,
  });

  final String label;
  final double ratio;
  final Color color;
  final String valueText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 124,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadius.brPill,
            child: Container(
              height: 10,
              color: AppColors.surfaceElevated,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(color: color),
              ),
            ),
          ),
        ),
        AppSpacing.gapSm,
        SizedBox(
          width: 92,
          child: Text(
            valueText,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
