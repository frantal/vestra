from __future__ import annotations

from .schemas import HybridDemoEntry, HybridRouteKind, HybridRoutingDecision, HybridRoutingRequest


class HybridRouter:
    _remote_baseline_cost_usd = 0.0025

    def route(self, request: HybridRoutingRequest) -> HybridRoutingDecision:
        normalized = request.prompt.lower().strip()
        signals: list[str] = []

        if not normalized:
            return HybridRoutingDecision(
                kind=HybridRouteKind.local,
                modelName="Local Vision/Text Model",
                confidence=52,
                estimatedLatencyMs=180,
                estimatedCostUsd=0,
                rationale="Sem prompt explícito, o router assume um caminho local.",
                signals=["Prompt vazio"],
            )

        if request.allowMemory and self._contains_any(
            normalized,
            ["última", "ultima", "histórico", "historico", "anterior", "repeti", "usei", "vesti"],
        ):
            return HybridRoutingDecision(
                kind=HybridRouteKind.memory,
                modelName="Memory Cache",
                confidence=97,
                estimatedLatencyMs=40,
                estimatedCostUsd=0,
                rationale="A resposta pode ser servida pelo histórico local.",
                signals=["Consulta de histórico detetada"],
            )

        complexity_score = 0

        if request.hasImage:
            complexity_score += 1
            signals.append("Imagem anexada")

        if self._contains_any(
            normalized,
            ["que cor", "qual a cor", "que tipo", "que peça", "o que é isto", "identifica", "classifica"],
        ):
            complexity_score -= 2
            signals.append("Pedido simples de visão")

        if self._contains_any(
            normalized,
            ["casamento", "evento", "combina", "sugere", "recomenda", "explica", "compara", "porquê", "porque", "estilo", "ocasião", "ocasiao", "melhor"],
        ):
            complexity_score += 3
            signals.append("Pedido de raciocínio avançado")

        if len(normalized) > 120:
            complexity_score += 1
            signals.append("Texto longo")

        if not request.hasImage and len(normalized) > 40:
            complexity_score += 1
            signals.append("Sem imagem e contexto alargado")

        if self._contains_any(
            normalized,
            ["cor", "categoria", "marca", "manga", "tecido", "tamanho", "atributos"],
        ):
            complexity_score -= 1
            signals.append("Atributo direto ou classificação rápida")

        if request.allowRemote and complexity_score >= 3:
            return HybridRoutingDecision(
                kind=HybridRouteKind.remote,
                modelName="Remote Reasoning LLM",
                confidence=84,
                estimatedLatencyMs=2600,
                estimatedCostUsd=self._remote_baseline_cost_usd,
                rationale="O pedido pede síntese, comparação ou raciocínio mais profundo.",
                signals=signals or ["Complexidade elevada"],
            )

        confidence = (
            max(78, min(96, 96 - (complexity_score * 4)))
            if request.hasImage
            else max(68, min(90, 84 - (complexity_score * 6)))
        )

        return HybridRoutingDecision(
            kind=HybridRouteKind.local,
            modelName="Local Vision Model" if request.hasImage else "Local Text Model",
            confidence=int(confidence),
            estimatedLatencyMs=420 if request.hasImage else 220,
            estimatedCostUsd=0,
            rationale="O pedido é simples o suficiente para correr localmente.",
            signals=signals or ["Complexidade baixa"],
        )

    @staticmethod
    def _contains_any(input_text: str, keywords: list[str]) -> bool:
        return any(keyword in input_text for keyword in keywords)
