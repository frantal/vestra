import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../infrastructure/supabase_auth_repository.dart';

/// The active [AuthRepository], or `null` when no backend is configured.
///
/// Presentation code checks for `null` and degrades gracefully (dev/UI mode)
/// instead of crashing when Supabase credentials are absent.
final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  return SupabaseAuthRepository(Supabase.instance.client);
});

/// Streams the authenticated user (or `null`) for reactive UI and route guards.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  if (repository == null) return const Stream<AppUser?>.empty();
  return repository.authStateChanges();
});
