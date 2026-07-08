/// Domain representation of an authenticated user.
///
/// Decoupled from Supabase's `User` so the rest of the app never depends on the
/// backend SDK directly.
class AppUser {
  const AppUser({required this.id, this.email, this.fullName, this.avatarUrl});

  final String id;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
}
