class ApiEndpoints {
  // Auth Endpoints
  static const String sendOtp = '/auth/otp';
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';

  // Profile Endpoints
  static const String myProfile = '/players/me';
  static const String updateProfile = '/players/me';
  static const String deleteAccount = '/players/me';
  static const String avatarUpload = '/players/me/avatar/upload';
  static const String avatar = '/players/me/avatar';

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

  // Push notification devices (Firebase tokens)
  static const String devices = '/devices';
  static const String unregisterDevice = '/devices/unregister';

  // Friends' posts and gaming news, ranked and mixed by the backend
  static const String feed = '/feed';

  // Chat Endpoints
  static const String chats = '/chats';
  static String chatMessages(int friendId) => '/chats/$friendId/messages';

  // Squad (group chat) Endpoints
  static const String squads = '/squads';
  static const String squadInvites = '/squads/invites';
  static String squad(int squadId) => '/squads/$squadId';
  static String inviteToSquad(int squadId) => '/squads/$squadId/invites';
  static String squadMember(int squadId, int playerId) => '/squads/$squadId/members/$playerId';
  static String leaveSquad(int squadId) => '/squads/$squadId/leave';
  static String acceptSquadInvite(int inviteId) => '/squads/invites/$inviteId/accept';
  static String declineSquadInvite(int inviteId) => '/squads/invites/$inviteId/decline';
  static String squadMessages(int squadId) => '/squads/$squadId/messages';

  // Tournament Endpoints
  static const String tournaments = '/tournaments';
  static const String myTournaments = '/tournaments/mine';
  static const String tournamentRequests = '/tournaments/requests';
  static const String tournamentChats = '/tournaments/chats';
  static String tournament(int tournamentId) => '/tournaments/$tournamentId';
  static String joinTournament(int tournamentId) => '/tournaments/$tournamentId/join';
  static String acceptTournamentRequest(int requestId) => '/tournaments/requests/$requestId/accept';
  static String rejectTournamentRequest(int requestId) => '/tournaments/requests/$requestId/reject';
  static String tournamentResult(int tournamentId) => '/tournaments/$tournamentId/result';
  static String tournamentMessages(int tournamentId) => '/tournaments/$tournamentId/messages';
  static String playerTournaments(int playerId) => '/players/$playerId/tournaments';

  // Post Endpoints
  static const String posts = '/posts';
  static const String postUploads = '/posts/uploads';
  static String post(int postId) => '/posts/$postId';
  static String playerPosts(int playerId) => '/players/$playerId/posts';
  static String postComments(int postId) => '/posts/$postId/comments';
  static String postLike(int postId) => '/posts/$postId/like';
  static String comment(int commentId) => '/comments/$commentId';
}
