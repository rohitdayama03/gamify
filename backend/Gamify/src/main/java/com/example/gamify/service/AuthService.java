package com.example.gamify.service;

import com.example.gamify.dto.*;

public interface AuthService {
    AuthResponse register(RegisterRequest request);
    AuthResponse login(LoginRequest request);
    SecretQuestionResponse getSecretQuestion(String username);
    void resetPassword(ResetPasswordRequest request);
    void logout(String authHeader);
}