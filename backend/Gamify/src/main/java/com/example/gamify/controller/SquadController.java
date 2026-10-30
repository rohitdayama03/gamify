package com.example.gamify.controller;

import com.example.gamify.dto.*;
import com.example.gamify.service.SquadService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/squads")
@RequiredArgsConstructor
public class SquadController {

    private final SquadService squadService;

    // Squads the player has joined, with the last message and unread count of each
    @GetMapping
    public ResponseEntity<List<SquadSummaryResponse>> getMySquads(@AuthenticationPrincipal String currentUsername) {
        return ResponseEntity.ok(squadService.getMySquads(currentUsername));
    }

    // Create a squad with a unique name and invite friends to it
    @PostMapping
    public ResponseEntity<SquadDetailResponse> createSquad(
            @AuthenticationPrincipal String currentUsername,
            @Valid @RequestBody CreateSquadRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(squadService.createSquad(currentUsername, request));
    }

    @GetMapping("/{squadId}")
    public ResponseEntity<SquadDetailResponse> getSquad(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long squadId) {
        return ResponseEntity.ok(squadService.getSquad(currentUsername, squadId));
    }

    // Invite more friends to a squad the player is in
    @PostMapping("/{squadId}/invites")
    public ResponseEntity<SquadDetailResponse> invite(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long squadId,
            @Valid @RequestBody InviteToSquadRequest request) {
        return ResponseEntity.ok(squadService.invite(currentUsername, squadId, request.playerIds()));
    }

    // Owner removes a member or withdraws a pending invite
    @DeleteMapping("/{squadId}/members/{playerId}")
    public ResponseEntity<SquadDetailResponse> removeMember(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long squadId,
            @PathVariable Long playerId) {
        return ResponseEntity.ok(squadService.removeMember(currentUsername, squadId, playerId));
    }

    @PostMapping("/{squadId}/leave")
    public ResponseEntity<Void> leave(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long squadId) {
        squadService.leave(currentUsername, squadId);
        return ResponseEntity.noContent().build();
    }

    // Pending invites the logged-in player received
    @GetMapping("/invites")
    public ResponseEntity<List<SquadInviteResponse>> getMyInvites(@AuthenticationPrincipal String currentUsername) {
        return ResponseEntity.ok(squadService.getMyInvites(currentUsername));
    }

    @PostMapping("/invites/{inviteId}/accept")
    public ResponseEntity<SquadDetailResponse> acceptInvite(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long inviteId) {
        return ResponseEntity.ok(squadService.acceptInvite(currentUsername, inviteId));
    }

    @PostMapping("/invites/{inviteId}/decline")
    public ResponseEntity<Void> declineInvite(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long inviteId) {
        squadService.declineInvite(currentUsername, inviteId);
        return ResponseEntity.noContent().build();
    }

    // Squad messages, oldest first. No params: latest page. afterId: newer messages (polling). beforeId: older page.
    @GetMapping("/{squadId}/messages")
    public ResponseEntity<List<SquadMessageResponse>> getMessages(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long squadId,
            @RequestParam(required = false) Long afterId,
            @RequestParam(required = false) Long beforeId) {
        return ResponseEntity.ok(squadService.getMessages(currentUsername, squadId, afterId, beforeId));
    }

    @PostMapping("/{squadId}/messages")
    public ResponseEntity<SquadMessageResponse> sendMessage(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long squadId,
            @Valid @RequestBody SendMessageRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(squadService.sendMessage(currentUsername, squadId, request.content()));
    }
}
