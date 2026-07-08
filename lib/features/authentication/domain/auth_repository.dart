import 'app_user.dart';

/// Contract for authentication operations.
///
/// Implemented by the infrastructure layer (Supabase) and consumed through
/// Riverpod providers, keeping the presentation layer backend-agnostic.
abstract interface class AuthRepository {
  /// Emits the current [AppUser] (or `null` when signed out) on every change.
  Stream<AppUser?> authStateChanges();

  /// The currently authenticated user, if any.
  AppUser? get currentUser;

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  });

  Future<void> signInWithGoogle();

  Future<void> signOut();
}
