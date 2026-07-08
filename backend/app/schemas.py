from __future__ import annotations

from enum import Enum
from pydantic import BaseModel, ConfigDict


class HybridRouteKind(str, Enum):
    local = "local"
    remote = "remote"
    memory = "memory"


class HybridRoutingRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    prompt: str
    hasImage: bool = False
    imageUrl: str | None = None
    allowRemote: bool = True
    allowMemory: bool = True
    allowFallbackRemote: bool = True


class HybridRoutingDecision(BaseModel):
    model_config = ConfigDict(extra="ignore")

    kind: HybridRouteKind
    modelName: str
    confidence: int
    estimatedLatencyMs: int
    estimatedCostUsd: float
    rationale: str
    signals: list[str]

    @property
    def path_label(self) -> str:
        return {
            HybridRouteKind.local: "Local",
            HybridRouteKind.remote: "Remoto",
            HybridRouteKind.memory: "Memória",
        }[self.kind]


class HybridDemoEntry(BaseModel):
    model_config = ConfigDict(extra="ignore")

    prompt: str
    answer: str
    decision: HybridRoutingDecision
    timestampIso: str
    usedFallbackRemote: bool


class HybridDemoResult(BaseModel):
    model_config = ConfigDict(extra="ignore")

    request: HybridRoutingRequest
    decision: HybridRoutingDecision
    answer: str
    executedModelName: str
    usedFallbackRemote: bool
    timestampIso: str
    entry: HybridDemoEntry
    recentEntries: list[HybridDemoEntry]


class HealthResponse(BaseModel):
    status: str
    backend: str = "vestra-hybrid-router"
    localModelReady: bool = False
    remoteModelReady: bool = False
