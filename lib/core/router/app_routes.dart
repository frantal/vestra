/// Centralized route paths for VESTRA.
///
/// Using named constants avoids magic strings at call sites and keeps
/// navigation refactors safe.
abstract final class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String permissions = '/permissions';
  static const String home = '/home';
  static const String wardrobe = '/wardrobe';
  static const String ai = '/ai';
  static const String profile = '/profile';
  static const String add = '/add';
}
