from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from .engine import HybridDemoEngine
from .memory import DemoMemoryStore
from .model_clients import build_local_model_client, build_remote_model_client
from .router import HybridRouter
from .schemas import HealthResponse, HybridDemoResult, HybridRoutingRequest

app = FastAPI(title="VESTRA Hybrid Router", version="0.1.0")

_root = Path(__file__).resolve().parents[1]
load_dotenv(_root / ".env")

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ALLOW_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

_memory_path = Path(os.getenv("HYBRID_HISTORY_PATH", _root / "data" / "hybrid_history.json"))
_engine = HybridDemoEngine(
    router=HybridRouter(),
    memory=DemoMemoryStore(_memory_path),
    local_client=build_local_model_client(),
    remote_client=build_remote_model_client(),
)


@app.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        localModelReady=_engine._local_client.is_live,  # noqa: SLF001
        remoteModelReady=_engine._remote_client.is_live,  # noqa: SLF001
    )


@app.post("/v1/hybrid/run", response_model=HybridDemoResult)
async def run_hybrid(request: HybridRoutingRequest) -> HybridDemoResult:
    return await _engine.run(request)


@app.get("/v1/hybrid/history", response_model=list[HybridDemoResult])
async def history() -> list[HybridDemoResult]:
    entries = _engine._memory.load_recent_entries()  # noqa: SLF001
    return [
        HybridDemoResult(
            request=HybridRoutingRequest(prompt=item.prompt),
            decision=item.decision,
            answer=item.answer,
            executedModelName=item.decision.modelName,
            usedFallbackRemote=item.usedFallbackRemote,
            timestampIso=item.timestampIso,
            entry=item,
            recentEntries=entries,
        )
        for item in entries
    ]
