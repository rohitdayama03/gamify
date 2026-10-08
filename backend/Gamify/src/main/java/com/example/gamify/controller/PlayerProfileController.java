package com.example.gamify.controller;

import com.example.gamify.dto.*;
import com.example.gamify.service.PlayerService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/players")
@RequiredArgsConstructor
public class PlayerProfileController {

    private final PlayerService playerService;

    // Get current logged-in user's complete profile
    @GetMapping("/me")
    public ResponseEntity<PlayerResponse> getCurrentPlayer(@AuthenticationPrincipal String currentUsername) {
        PlayerResponse profile = playerService.getProfileByUsername(currentUsername);
        return ResponseEntity.ok(profile);
    }

    // Get public profile by Player ID
    @GetMapping("/{playerId}")
    public ResponseEntity<PlayerResponse> getPlayerById(@PathVariable Long playerId) {
        PlayerResponse profile = playerService.getProfileById(playerId);
        return ResponseEntity.ok(profile);
    }

    // Update general player info (bio, country, language)
    @PutMapping("/me")
    public ResponseEntity<PlayerResponse> updateProfile(
            @AuthenticationPrincipal String currentUsername,
            @Valid @RequestBody UpdatePlayerRequest request) {
        PlayerResponse updatedProfile = playerService.updateProfile(currentUsername, request);
        return ResponseEntity.ok(updatedProfile);
    }

    // Delete logged-in account
    @DeleteMapping("/me")
    public ResponseEntity<Void> deleteAccount(@AuthenticationPrincipal String currentUsername) {
        playerService.deleteAccount(currentUsername);
        return ResponseEntity.noContent().build();
    }

    // --- GAME PROFILES ---

    // Upsert BGMI Profile
    @PutMapping("/me/game-profiles/bgmi")
    public ResponseEntity<BgmiProfileResponse> upsertBgmiProfile(
            @AuthenticationPrincipal String currentUsername,
            @Valid @RequestBody BgmiProfileRequest request) {
        BgmiProfileResponse response = playerService.upsertBgmiProfile(currentUsername, request);
        return ResponseEntity.ok(response);
    }

    // Delete BGMI Profile
    @DeleteMapping("/me/game-profiles/bgmi")
    public ResponseEntity<Void> deleteBgmiProfile(@AuthenticationPrincipal String currentUsername) {
        playerService.deleteBgmiProfile(currentUsername);
        return ResponseEntity.noContent().build();
    }

    // Upsert E-Football Profile
    @PutMapping("/me/game-profiles/efootball")
    public ResponseEntity<EfootballProfileResponse> upsertEfootballProfile(
            @AuthenticationPrincipal String currentUsername,
            @Valid @RequestBody EfootballProfileRequest request) {
        EfootballProfileResponse response = playerService.upsertEfootballProfile(currentUsername, request);
        return ResponseEntity.ok(response);
    }

    // Delete E-Football Profile
    @DeleteMapping("/me/game-profiles/efootball")
    public ResponseEntity<Void> deleteEfootballProfile(@AuthenticationPrincipal String currentUsername) {
        playerService.deleteEfootballProfile(currentUsername);
        return ResponseEntity.noContent().build();
    }
}