class ApiEndpoints {
  // Auth Endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String secretQuestion = '/auth/forgot-password/question';
  static const String resetPassword = '/auth/forgot-password/reset';
  static const String logout = '/auth/logout';

  // Profile Endpoints
  static const String myProfile = '/players/me';
  static const String updateProfile = '/players/me';
  static const String deleteAccount = '/players/me';

  // Game Profile Endpoints
  static const String gtaProfile = '/players/me/game-profiles/gta';
  static const String bgmiProfile = '/players/me/game-profiles/bgmi';
  static const String efootballProfile = '/players/me/game-profiles/efootball';

  // Search Endpoint
  static const String searchPlayers = '/players/search';
  static String player(int playerId) => '/players/$playerId';

  // Connection (invite / friend) Endpoints
  static const String connections = '/connections';
  static String sendInvite(int playerId) => '/connections/invite/$playerId';
  static String acceptInvite(int connectionId) => '/connections/$connectionId/accept';
  static String declineInvite(int connectionId) => '/connections/$connectionId/decline';
  static String cancelInvite(int connectionId) => '/connections/$connectionId';

  // Chat Endpoints
  static const String chats = '/chats';
  static String chatMessages(int friendId) => '/chats/$friendId/messages';
}