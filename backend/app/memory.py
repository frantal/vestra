from __future__ import annotations

import json
from pathlib import Path

from .schemas import HybridDemoEntry


class DemoMemoryStore:
    def __init__(self, storage_path: Path) -> None:
        self._storage_path = storage_path
        self._storage_path.parent.mkdir(parents=True, exist_ok=True)

    def load_recent_entries(self) -> list[HybridDemoEntry]:
        if not self._storage_path.exists():
            return []

        raw = json.loads(self._storage_path.read_text(encoding="utf-8"))
        return [HybridDemoEntry.model_validate(item) for item in raw]

    def save_entry(self, entry: HybridDemoEntry, max_entries: int = 5) -> list[HybridDemoEntry]:
        current = self.load_recent_entries()
        updated = [entry, *current][:max_entries]
        self._storage_path.write_text(
            json.dumps([item.model_dump() for item in updated], ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        return updated

    def find_last_relevant_entry(self, prompt: str) -> HybridDemoEntry | None:
        normalized = prompt.lower()
        entries = self.load_recent_entries()
        if not entries:
            return None

        for entry in entries:
            entry_prompt = entry.prompt.lower()
            if "última" in normalized or "ultima" in normalized or "anterior" in normalized:
                return entry
            if "look" in entry_prompt or "peça" in entry_prompt:
                return entry

        return entries[0]
