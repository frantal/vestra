from __future__ import annotations

from datetime import datetime, timezone

from .memory import DemoMemoryStore
from .model_clients import OpenAICompatibleModelClient
from .router import HybridRouter
from .schemas import (
    HybridDemoEntry,
    HybridDemoResult,
    HybridRouteKind,
    HybridRoutingDecision,
    HybridRoutingRequest,
)


class HybridDemoEngine:
    def __init__(
        self,
        *,
        router: HybridRouter,
        memory: DemoMemoryStore,
        local_client: OpenAICompatibleModelClient,
        remote_client: OpenAICompatibleModelClient,
    ) -> None:
        self._router = router
        self._memory = memory
        self._local_client = local_client
        self._remote_client = remote_client

    async def run(self, request: HybridRoutingRequest) -> HybridDemoResult:
        decision = self._router.route(request)
        timestamp = datetime.now(timezone.utc).isoformat()
        executed_decision = decision
        used_fallback_remote = False

        if (
            request.allowFallbackRemote
            and decision.kind == HybridRouteKind.local
            and decision.confidence < 82
            and request.allowRemote
        ):
            executed_decision = HybridRoutingDecision(
                kind=HybridRouteKind.remote,
                modelName="Remote Reasoning LLM",
                confidence=84,
                estimatedLatencyMs=2600,
                estimatedCostUsd=0.0025,
                rationale="Fallback remoto acionado por baixa confiança do modelo local.",
                signals=["Baixa confiança local"],
            )
            used_fallback_remote = True

        if (
            executed_decision.kind == HybridRouteKind.local
            and not self._local_client.is_live
            and self._remote_client.is_live
            and request.allowRemote
        ):
            executed_decision = HybridRoutingDecision(
                kind=HybridRouteKind.remote,
                modelName="Remote Reasoning LLM",
                confidence=max(executed_decision.confidence, 82),
                estimatedLatencyMs=2600,
                estimatedCostUsd=0.0025,
                rationale="Fallback remoto acionado porque o endpoint local não está configurado.",
                signals=[*executed_decision.signals, "Endpoint local indisponível"],
            )
            used_fallback_remote = True

        if executed_decision.kind == HybridRouteKind.memory:
            last_entry = self._memory.find_last_relevant_entry(request.prompt)
            answer = self._answer_for_memory(request, last_entry)
            executed_model_name = "Memory Cache"
        elif executed_decision.kind == HybridRouteKind.remote:
            execution = await self._remote_client.execute(request, executed_decision)
            answer = execution.answer
            executed_model_name = execution.model_name
        else:
            execution = await self._local_client.execute(request, executed_decision)
            answer = execution.answer
            executed_model_name = execution.model_name

        entry = HybridDemoEntry(
            prompt=request.prompt,
            answer=answer,
            decision=executed_decision,
            timestampIso=timestamp,
            usedFallbackRemote=used_fallback_remote,
        )
        recent_entries = self._memory.save_entry(entry)

        return HybridDemoResult(
            request=request,
            decision=executed_decision,
            answer=answer,
            executedModelName=executed_model_name,
            usedFallbackRemote=used_fallback_remote,
            timestampIso=timestamp,
            entry=entry,
            recentEntries=recent_entries,
        )

    @staticmethod
    def _answer_for_memory(
        request: HybridRoutingRequest,
        last_entry: HybridDemoEntry | None,
    ) -> str:
        if last_entry is None:
            return f'Memória vazia: não encontrei histórico recente para responder "{request.prompt}".'
        return (
            f'Memória persistente encontrada: a última interação relevante foi "{last_entry.prompt}", '
            f'processada via {last_entry.decision.path_label}.'
        )
