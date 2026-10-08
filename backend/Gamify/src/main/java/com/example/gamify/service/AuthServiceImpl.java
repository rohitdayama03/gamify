package com.example.gamify.service;

import com.example.gamify.dto.*;
import com.example.gamify.entity.Player;
import com.example.gamify.exception.BadRequestException;
import com.example.gamify.exception.ResourceNotFoundException;
import com.example.gamify.repository.PlayerRepository;
import com.example.gamify.security.JwtUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthServiceImpl implements AuthService {

    private final PlayerRepository playerRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtils jwtUtils;

    @Override
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (playerRepository.existsByUsername(request.username())) {
            throw new BadRequestException("Username is already taken");
        }

        Player player = Player.builder()
                .username(request.username())
                .password(passwordEncoder.encode(request.password()))
                .playerBio(request.playerBio())
                .language(request.language())
                .country(request.country())
                .secretQuestion(request.secretQuestion())
                .secretAnswer(passwordEncoder.encode(request.secretAnswer().trim().toLowerCase()))
                .build();

        Player savedPlayer = playerRepository.save(player);
        String token = jwtUtils.generateToken(savedPlayer.getUsername());

        return new AuthResponse(token, "Bearer", savedPlayer.getPlayerId(), savedPlayer.getUsername());
    }

    @Override
    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        Player player = playerRepository.findByUsername(request.username())
                .orElseThrow(() -> new BadRequestException("Invalid username or password"));

        if (!passwordEncoder.matches(request.password(), player.getPassword())) {
            throw new BadRequestException("Invalid username or password");
        }

        String token = jwtUtils.generateToken(player.getUsername());
        return new AuthResponse(token, "Bearer", player.getPlayerId(), player.getUsername());
    }

    @Override
    @Transactional(readOnly = true)
    public SecretQuestionResponse getSecretQuestion(String username) {
        Player player = playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with username: " + username));

        return new SecretQuestionResponse(player.getUsername(), player.getSecretQuestion());
    }

    @Override
    @Transactional
    public void resetPassword(ResetPasswordRequest request) {
        Player player = playerRepository.findByUsername(request.username())
                .orElseThrow(() -> new ResourceNotFoundException("User not found with username: " + request.username()));

        boolean isAnswerCorrect = passwordEncoder.matches(
                request.secretAnswer().trim().toLowerCase(),
                player.getSecretAnswer()
        );

        if (!isAnswerCorrect) {
            throw new BadRequestException("Incorrect secret answer provided");
        }

        player.setPassword(passwordEncoder.encode(request.newPassword()));
        playerRepository.save(player);
    }

    @Override
    public void logout(String authHeader) {
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            jwtUtils.invalidateToken(token);
        }
    }
}