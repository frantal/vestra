import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

/// Supabase-backed implementation of [AuthRepository].
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    final metadata = user.userMetadata;
    return AppUser(
      id: user.id,
      email: user.email,
      fullName: metadata?['full_name'] as String?,
      avatarUrl: metadata?['avatar_url'] as String?,
    );
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.onAuthStateChange.map(
      (event) => _mapUser(event.session?.user),
    );
  }

  @override
  AppUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = _mapUser(response.user);
    if (user == null) {
      throw const AuthException('Não foi possível iniciar sessão.');
    }
    return user;
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: fullName == null ? null : {'full_name': fullName},
    );
    final user = _mapUser(response.user);
    if (user == null) {
      throw const AuthException('Não foi possível criar a conta.');
    }
    return user;
  }

  @override
  Future<void> signInWithGoogle() async {
    await _auth.signInWithOAuth(OAuthProvider.google);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
