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

enum OtpPurpose { register, login }

/// Reply to a code request: how long the code works and how many more can be sent today.
class OtpSent {
  final Duration expiresIn;
  final int remainingToday;

  OtpSent({required this.expiresIn, required this.remainingToday});

  factory OtpSent.fromJson(Map<String, dynamic> json) {
    return OtpSent(
      expiresIn: Duration(seconds: json['expiresInSeconds']),
      remainingToday: json['remainingToday'],
    );
  }
}
