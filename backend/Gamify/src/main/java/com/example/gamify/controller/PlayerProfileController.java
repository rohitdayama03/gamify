package com.example.gamify.controller;

import com.example.gamify.dto.*;
import com.example.gamify.service.PlayerService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
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

    // Upsert GTA Online Profile
    // Profile picture, step 1: a signed link to upload the cropped JPEG straight to S3
    @PostMapping("/me/avatar/upload")
    public ResponseEntity<UploadSessionResponse> startAvatarUpload(
            @AuthenticationPrincipal String currentUsername,
            @Valid @RequestBody AvatarUploadRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(playerService.startAvatarUpload(currentUsername, request));
    }

    // Step 2, after the app has uploaded it: make it the profile picture
    @PutMapping("/me/avatar")
    public ResponseEntity<PlayerResponse> setAvatar(
            @AuthenticationPrincipal String currentUsername,
            @Valid @RequestBody SetAvatarRequest request) {
        return ResponseEntity.ok(playerService.setAvatar(currentUsername, request.key()));
    }

    @DeleteMapping("/me/avatar")
    public ResponseEntity<PlayerResponse> removeAvatar(@AuthenticationPrincipal String currentUsername) {
        return ResponseEntity.ok(playerService.removeAvatar(currentUsername));
    }

    @PutMapping("/me/game-profiles/gta")
    public ResponseEntity<GtaProfileResponse> upsertGtaProfile(
            @AuthenticationPrincipal String currentUsername,
            @Valid @RequestBody GtaProfileRequest request) {
        GtaProfileResponse response = playerService.upsertGtaProfile(currentUsername, request);
        return ResponseEntity.ok(response);
    }

    // Delete GTA Online Profile
    @DeleteMapping("/me/game-profiles/gta")
    public ResponseEntity<Void> deleteGtaProfile(@AuthenticationPrincipal String currentUsername) {
        playerService.deleteGtaProfile(currentUsername);
        return ResponseEntity.noContent().build();
    }

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