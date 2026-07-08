from __future__ import annotations

import os
from dataclasses import dataclass

import httpx

from .schemas import HybridRoutingDecision, HybridRoutingRequest


@dataclass(slots=True)
class ModelExecution:
    answer: str
    model_name: str
    actual_latency_ms: int
    cost_usd: float


class OpenAICompatibleModelClient:
    def __init__(
        self,
        *,
        base_url: str | None,
        model_name: str,
        vision_model_name: str | None = None,
        api_key: str | None = None,
    ) -> None:
        self._base_url = base_url
        self._model_name = model_name
        self._vision_model_name = vision_model_name
        self._api_key = api_key

    @property
    def model_name(self) -> str:
        return self._model_name

    @property
    def is_live(self) -> bool:
        if not self._base_url:
            return False
        if "fireworks.ai" in self._base_url and not self._api_key:
            return False
        return True

    async def execute(
        self,
        request: HybridRoutingRequest,
        decision: HybridRoutingDecision,
    ) -> ModelExecution:
        if not self.is_live:
            return self._simulate(request, decision)

        headers = {"Content-Type": "application/json", "Accept": "application/json"}
        if self._api_key:
            headers["Authorization"] = f"Bearer {self._api_key}"

        model_name = self._model_name
        if request.hasImage and self._vision_model_name:
            model_name = self._vision_model_name

        user_content: object = request.prompt
        if request.imageUrl:
            user_content = [
                {
                    "type": "text",
                    "text": request.prompt,
                },
                {
                    "type": "image_url",
                    "image_url": {
                        "url": request.imageUrl,
                    },
                },
            ]

        payload = {
            "model": model_name,
            "max_tokens": 1200,
            "messages": [
                {
                    "role": "system",
                    "content": (
                        "You are VESTRA's hybrid assistant. Keep answers concise, "
                        "practical, and friendly."
                    ),
                },
                {
                    "role": "user",
                    "content": user_content,
                },
            ],
            "temperature": 0.2,
        }

        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(self._base_url, headers=headers, json=payload)
            response.raise_for_status()

        data = response.json()
        content = data.get("choices", [{}])[0].get("message", {}).get("content")
        answer = content if isinstance(content, str) and content.strip() else self._simulate(request, decision).answer
        return ModelExecution(
            answer=answer,
            model_name=model_name,
            actual_latency_ms=decision.estimatedLatencyMs,
            cost_usd=decision.estimatedCostUsd,
        )

    def _simulate(
        self,
        request: HybridRoutingRequest,
        decision: HybridRoutingDecision,
    ) -> ModelExecution:
        prompt = request.prompt.lower()
        if decision.kind.value == "memory":
            answer = "Memória consultada localmente."
        elif request.hasImage and any(
            token in prompt for token in ("descrev", "analisa", "detalh", "o que tem", "o que há")
        ):
            answer = (
                "Análise visual concluída (modo demo):\n"
                "• Imagem recebida e processada localmente\n"
                "• Elementos principais de vestuário identificados\n"
                "• Cores e estilo geral extraídos para recomendação\n\n"
                "Se quiser, já te proponho 2-3 combinações com base nessa análise."
            )
        elif request.hasImage and any(
            token in prompt for token in ("sugere", "look", "outfit", "combina", "estilo")
        ):
            answer = (
                "Com base na imagem, sugiro um look casual equilibrado:\n"
                "• Peça base neutra\n"
                "• Camada leve para contraste\n"
                "• Ténis ou sapato limpo com acessórios discretos"
            )
        elif "cor" in prompt:
            answer = "Execução local concluída: a peça foi classificada rapidamente sem gastar tokens remotos."
        elif "camisa" in prompt or "peça" in prompt:
            answer = "Execução local concluída: atributos visuais simples analisados com o modelo local."
        elif decision.kind.value == "remote":
            answer = f"Execução remota concluída para: {request.prompt}"
        else:
            answer = "Execução local concluída: resposta rápida gerada no dispositivo."

        return ModelExecution(
            answer=answer,
            model_name=self._model_name,
            actual_latency_ms=decision.estimatedLatencyMs,
            cost_usd=decision.estimatedCostUsd,
        )


def build_local_model_client() -> OpenAICompatibleModelClient:
    return OpenAICompatibleModelClient(
        base_url=os.getenv("LOCAL_MODEL_BASE_URL"),
        model_name=os.getenv("LOCAL_MODEL_NAME", "local-model"),
        api_key=os.getenv("LOCAL_MODEL_API_KEY"),
    )


def build_remote_model_client() -> OpenAICompatibleModelClient:
    remote_base_url = os.getenv("REMOTE_MODEL_BASE_URL")
    remote_api_key = os.getenv("REMOTE_MODEL_API_KEY")

    if not remote_base_url and remote_api_key:
        remote_base_url = "https://api.fireworks.ai/inference/v1/chat/completions"

    return OpenAICompatibleModelClient(
        base_url=remote_base_url,
        model_name=os.getenv("REMOTE_MODEL_NAME", "accounts/fireworks/models/kimi-k2p7-code"),
        vision_model_name=os.getenv(
            "REMOTE_VISION_MODEL_NAME",
            "accounts/fireworks/models/kimi-k2p6",
        ),
        api_key=remote_api_key,
    )
