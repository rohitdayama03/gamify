import '../core/api/msg91_otp.dart';

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

/// A code that has been sent. With MSG91 the widget sent it and [msg91]/[reqId] check it; otherwise the
/// server issued it (testing) and limits how many can be sent per day.
class OtpSent {
  final Msg91Otp? msg91;
  final String? reqId;
  // Null with MSG91, which keeps its own limits
  final int? remainingToday;

  const OtpSent({this.msg91, this.reqId, this.remainingToday});
}
