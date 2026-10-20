class AuthResponse {
  final String token;
  final String tokenType;
  final int playerId;
  final String username;

  AuthResponse({
    required this.token,
    required this.tokenType,
    required this.playerId,
    required this.username,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'],
      tokenType: json['tokenType'],
      playerId: json['playerId'],
      username: json['username'],
    );
  }
}

class SecretQuestionResponse {
  final String username;
  final String secretQuestion;

  SecretQuestionResponse({
    required this.username,
    required this.secretQuestion,
  });

  factory SecretQuestionResponse.fromJson(Map<String, dynamic> json) {
    return SecretQuestionResponse(
      username: json['username'],
      secretQuestion: json['secretQuestion'],
    );
  }
}