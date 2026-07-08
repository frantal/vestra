import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/hybrid_demo_result.dart';

/// Persistent demo memory backed by SharedPreferences.
class HybridDemoMemory {
  HybridDemoMemory(this._prefs);

  final SharedPreferences _prefs;

  static const String _historyKey = 'hybrid_demo_history';
  static const int _maxEntries = 5;

  List<HybridDemoEntry> loadRecentEntries() {
    final raw = _prefs.getStringList(_historyKey) ?? const <String>[];
    return raw
        .map(
          (item) => HybridDemoEntry.fromJson(
            Map<String, Object?>.from(
              jsonDecode(item) as Map<String, dynamic>,
            ),
          ),
        )
        .toList(growable: false);
  }

  HybridDemoEntry? findLastRelevantEntry(String prompt) {
    final normalized = prompt.toLowerCase();
    final entries = loadRecentEntries();
    if (entries.isEmpty) {
      return null;
    }

    for (final entry in entries) {
      final entryPrompt = entry.prompt.toLowerCase();
      if (normalized.contains('última') ||
          normalized.contains('ultima') ||
          normalized.contains('anterior')) {
        return entry;
      }
      if (entryPrompt.contains('look') || entryPrompt.contains('peça')) {
        return entry;
      }
    }

    return entries.first;
  }

  Future<void> saveEntry(HybridDemoEntry entry) async {
    final current = _prefs.getStringList(_historyKey) ?? const <String>[];
    final updated = <String>[
      jsonEncode(entry.toJson()),
      ...current,
    ].take(_maxEntries).toList(growable: false);
    await _prefs.setStringList(_historyKey, updated);
  }
}
