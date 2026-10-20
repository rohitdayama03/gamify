class ApiEndpoints {
  // Auth Endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String secretQuestion = '/auth/secret-question';
  static const String resetPassword = '/auth/reset-password';
  static const String logout = '/auth/logout';

  // Profile Endpoints
  static const String myProfile = '/players/me';
  static const String updateProfile = '/players/me';
  static const String deleteAccount = '/players/me';

  // Game Profile Endpoints
  static const String bgmiProfile = '/players/me/bgmi';
  static const String efootballProfile = '/players/me/efootball';

  // Search Endpoint
  static const String searchPlayers = '/players/search';
}