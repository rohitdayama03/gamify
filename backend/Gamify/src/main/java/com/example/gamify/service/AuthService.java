package com.example.gamify.service;

import com.example.gamify.dto.*;

public interface AuthService {
    SendOtpResponse sendOtp(SendOtpRequest request);
    AuthResponse register(RegisterRequest request);
    AuthResponse login(LoginRequest request);
    void logout(String authHeader);
}
