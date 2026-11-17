package com.example.gamify.controller;

import com.example.gamify.dto.*;
import com.example.gamify.entity.Game;
import com.example.gamify.service.TournamentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class TournamentController {

    private final TournamentService tournamentService;

    // Open tournaments, soonest first; filter by game with ?game=BGMI
    @GetMapping("/tournaments")
    public ResponseEntity<List<TournamentSummaryResponse>> getOpenTournaments(
            @AuthenticationPrincipal String currentUsername,
            @RequestParam(required = false) Game game) {
        return ResponseEntity.ok(tournamentService.getOpenTournaments(currentUsername, game));
    }

    // Tournaments the player organizes or has asked to join
    @GetMapping("/tournaments/mine")
    public ResponseEntity<List<TournamentSummaryResponse>> getMyTournaments(@AuthenticationPrincipal String currentUsername) {
        return ResponseEntity.ok(tournamentService.getMyTournaments(currentUsername));
    }

    @PostMapping("/tournaments")
    public ResponseEntity<TournamentDetailResponse> createTournament(
            @AuthenticationPrincipal String currentUsername,
            @Valid @RequestBody CreateTournamentRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(tournamentService.createTournament(currentUsername, request));
    }

    @GetMapping("/tournaments/{tournamentId}")
    public ResponseEntity<TournamentDetailResponse> getTournament(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long tournamentId) {
        return ResponseEntity.ok(tournamentService.getTournament(currentUsername, tournamentId));
    }

    // Organizer cancels the tournament
    @DeleteMapping("/tournaments/{tournamentId}")
    public ResponseEntity<Void> deleteTournament(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long tournamentId) {
        tournamentService.deleteTournament(currentUsername, tournamentId);
        return ResponseEntity.noContent().build();
    }

    // Ask the organizer to let the player in
    @PostMapping("/tournaments/{tournamentId}/join")
    public ResponseEntity<TournamentDetailResponse> requestToJoin(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long tournamentId) {
        return ResponseEntity.ok(tournamentService.requestToJoin(currentUsername, tournamentId));
    }

    // Withdraw a pending request or leave before the result is recorded
    @DeleteMapping("/tournaments/{tournamentId}/join")
    public ResponseEntity<TournamentDetailResponse> withdraw(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long tournamentId) {
        return ResponseEntity.ok(tournamentService.withdraw(currentUsername, tournamentId));
    }

    // Pending join requests to every tournament the player organizes
    @GetMapping("/tournaments/requests")
    public ResponseEntity<List<TournamentRequestResponse>> getPendingRequests(@AuthenticationPrincipal String currentUsername) {
        return ResponseEntity.ok(tournamentService.getPendingRequests(currentUsername));
    }

    @PostMapping("/tournaments/requests/{requestId}/accept")
    public ResponseEntity<TournamentDetailResponse> acceptRequest(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long requestId) {
        return ResponseEntity.ok(tournamentService.acceptRequest(currentUsername, requestId));
    }

    // A rejected player can't ask again
    @PostMapping("/tournaments/requests/{requestId}/reject")
    public ResponseEntity<TournamentDetailResponse> rejectRequest(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long requestId) {
        return ResponseEntity.ok(tournamentService.rejectRequest(currentUsername, requestId));
    }

    // Record (or correct) placements; marks the tournament completed
    @PutMapping("/tournaments/{tournamentId}/result")
    public ResponseEntity<TournamentDetailResponse> recordResult(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long tournamentId,
            @Valid @RequestBody RecordResultRequest request) {
        return ResponseEntity.ok(tournamentService.recordResult(currentUsername, tournamentId, request));
    }

    // Organizer replaces the stages, stats and fixtures; only until a player has been accepted
    @PutMapping("/tournaments/{tournamentId}/format")
    public ResponseEntity<TournamentDetailResponse> updateFormat(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long tournamentId,
            @Valid @RequestBody TournamentFormatRequest request) {
        return ResponseEntity.ok(tournamentService.updateFormat(currentUsername, tournamentId, request));
    }

    // Organizer draws the players into slots and locks the fixtures; every slot must be filled
    @PostMapping("/tournaments/{tournamentId}/start")
    public ResponseEntity<TournamentDetailResponse> startTournament(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long tournamentId,
            @Valid @RequestBody StartTournamentRequest request) {
        return ResponseEntity.ok(tournamentService.startTournament(currentUsername, tournamentId, request));
    }

    @GetMapping("/tournaments/{tournamentId}/fixtures")
    public ResponseEntity<TournamentFixturesResponse> getFixtures(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long tournamentId) {
        return ResponseEntity.ok(tournamentService.getFixtures(currentUsername, tournamentId));
    }

    // Organizer enters (or corrects) a match result in the current stage
    @PutMapping("/tournaments/{tournamentId}/matches/{matchId}")
    public ResponseEntity<TournamentFixturesResponse> recordMatchResult(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long tournamentId,
            @PathVariable Long matchId,
            @Valid @RequestBody MatchResultRequest request) {
        return ResponseEntity.ok(tournamentService.recordMatchResult(currentUsername, tournamentId, matchId, request));
    }

    // Organizer closes the current stage once every result is in; the last stage completes the tournament
    @PostMapping("/tournaments/{tournamentId}/stages/{stageId}/finish")
    public ResponseEntity<TournamentDetailResponse> finishStage(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long tournamentId,
            @PathVariable Long stageId,
            @Valid @RequestBody(required = false) FinishStageRequest request) {
        return ResponseEntity.ok(tournamentService.finishStage(currentUsername, tournamentId, stageId, request));
    }

    @GetMapping("/tournaments/{tournamentId}/leaderboard")
    public ResponseEntity<TournamentLeaderboardResponse> getLeaderboard(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long tournamentId) {
        return ResponseEntity.ok(tournamentService.getLeaderboard(currentUsername, tournamentId));
    }

    // Announcement chats the player is in, for the Inbox
    @GetMapping("/tournaments/chats")
    public ResponseEntity<List<TournamentChatResponse>> getChats(@AuthenticationPrincipal String currentUsername) {
        return ResponseEntity.ok(tournamentService.getChats(currentUsername));
    }

    // Announcements, oldest first. No params: latest page. afterId: newer messages (polling). beforeId: older page.
    @GetMapping("/tournaments/{tournamentId}/messages")
    public ResponseEntity<List<TournamentMessageResponse>> getMessages(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long tournamentId,
            @RequestParam(required = false) Long afterId,
            @RequestParam(required = false) Long beforeId) {
        return ResponseEntity.ok(tournamentService.getMessages(currentUsername, tournamentId, afterId, beforeId));
    }

    // Organizer only
    @PostMapping("/tournaments/{tournamentId}/messages")
    public ResponseEntity<TournamentMessageResponse> sendMessage(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long tournamentId,
            @Valid @RequestBody SendMessageRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(tournamentService.sendMessage(currentUsername, tournamentId, request.content()));
    }

    // Tournaments a player took part in, for their profile
    @GetMapping("/players/{playerId}/tournaments")
    public ResponseEntity<List<PlayerTournamentResponse>> getPlayerTournaments(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long playerId) {
        return ResponseEntity.ok(tournamentService.getPlayerTournaments(playerId));
    }
}
