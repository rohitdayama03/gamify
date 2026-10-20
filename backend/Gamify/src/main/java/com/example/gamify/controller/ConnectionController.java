package com.example.gamify.controller;

import com.example.gamify.dto.ConnectionResponse;
import com.example.gamify.service.ConnectionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/connections")
@RequiredArgsConstructor
public class ConnectionController {

    private final ConnectionService connectionService;

    // All invites the logged-in player sent or received (pending, accepted and declined)
    @GetMapping
    public ResponseEntity<List<ConnectionResponse>> getMyConnections(@AuthenticationPrincipal String currentUsername) {
        return ResponseEntity.ok(connectionService.getMyConnections(currentUsername));
    }

    // Send an invite to another player
    @PostMapping("/invite/{playerId}")
    public ResponseEntity<ConnectionResponse> sendInvite(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long playerId) {
        return ResponseEntity.status(HttpStatus.CREATED).body(connectionService.sendInvite(currentUsername, playerId));
    }

    // Accept an invite received by the logged-in player
    @PostMapping("/{connectionId}/accept")
    public ResponseEntity<ConnectionResponse> acceptInvite(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long connectionId) {
        return ResponseEntity.ok(connectionService.acceptInvite(currentUsername, connectionId));
    }

    // Decline an invite received by the logged-in player; the sender can never invite again
    @PostMapping("/{connectionId}/decline")
    public ResponseEntity<ConnectionResponse> declineInvite(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long connectionId) {
        return ResponseEntity.ok(connectionService.declineInvite(currentUsername, connectionId));
    }
}
