package com.example.gamify.service;

import com.example.gamify.dto.*;
import com.example.gamify.entity.OtpPurpose;
import com.example.gamify.entity.Player;
import com.example.gamify.exception.BadRequestException;
import com.example.gamify.otp.Msg91Properties;
import com.example.gamify.otp.Msg91TokenVerifier;
import com.example.gamify.otp.OtpProperties;
import com.example.gamify.otp.OtpService;
import com.example.gamify.repository.PlayerRepository;
import com.example.gamify.security.JwtUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthServiceImpl implements AuthService {

    private final PlayerRepository playerRepository;
    private final OtpService otpService;
    private final OtpProperties otpProperties;
    private final Msg91Properties msg91Properties;
    private final Msg91TokenVerifier msg91TokenVerifier;
    private final JwtUtils jwtUtils;

    @Override
    @Transactional
    public SendOtpResponse sendOtp(SendOtpRequest request) {
        String phoneNumber = request.phoneNumber();
        if (request.purpose() == OtpPurpose.REGISTER) {
            checkCanRegister(request.username(), phoneNumber);
        } else if (!playerRepository.existsByPhoneNumber(phoneNumber)) {
            throw new BadRequestException("No account uses this phone number. Create an account instead.");
        }

        if (msg91Properties.enabled()) {
            otpService.recordRequest(phoneNumber);
            return SendOtpResponse.msg91(msg91Properties.widgetId(), msg91Properties.tokenAuth());
        }
        int remainingToday = otpService.send(phoneNumber, request.purpose());
        return SendOtpResponse.server(otpProperties.validity().toSeconds(), remainingToday);
    }

    @Override
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        // Checked before the code, so a taken username doesn't use it up
        checkCanRegister(request.username(), request.phoneNumber());
        verifyCode(request.phoneNumber(), OtpPurpose.REGISTER, request.otp(), request.accessToken());

        Player player = Player.builder()
                .username(request.username())
                .phoneNumber(request.phoneNumber())
                .playerBio(request.playerBio())
                .language(request.language())
                .country(request.country())
                .build();

        Player savedPlayer = playerRepository.save(player);
        String token = jwtUtils.generateToken(savedPlayer.getUsername());

        return new AuthResponse(token, "Bearer", savedPlayer.getPlayerId(), savedPlayer.getUsername());
    }

    @Override
    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        Player player = playerRepository.findByPhoneNumber(request.phoneNumber())
                .orElseThrow(() -> new BadRequestException("No account uses this phone number"));

        verifyCode(request.phoneNumber(), OtpPurpose.LOGIN, request.otp(), request.accessToken());

        String token = jwtUtils.generateToken(player.getUsername());
        return new AuthResponse(token, "Bearer", player.getPlayerId(), player.getUsername());
    }

    @Override
    public void logout(String authHeader) {
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            jwtUtils.invalidateToken(token);
        }
    }

    // With MSG91 on, only its access token counts, so the testing code can't be used to sign in
    private void verifyCode(String phoneNumber, OtpPurpose purpose, String otp, String accessToken) {
        if (msg91Properties.enabled()) {
            if (accessToken == null || accessToken.isBlank()) {
                throw new BadRequestException("Enter the code we sent you. If this keeps happening, update the app.");
            }
            msg91TokenVerifier.verify(accessToken, phoneNumber);
        } else {
            if (otp == null || otp.isBlank()) {
                throw new BadRequestException("Enter the code we sent you");
            }
            otpService.verify(phoneNumber, purpose, otp);
        }
    }

    private void checkCanRegister(String username, String phoneNumber) {
        if (playerRepository.existsByPhoneNumber(phoneNumber)) {
            throw new BadRequestException("An account already uses this phone number. Sign in instead.");
        }
        if (username != null && playerRepository.existsByUsername(username)) {
            throw new BadRequestException("Username is already taken");
        }
    }
}
