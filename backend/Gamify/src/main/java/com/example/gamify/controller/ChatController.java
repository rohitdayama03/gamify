package com.example.gamify.controller;

import com.example.gamify.dto.ChatMessageResponse;
import com.example.gamify.dto.ConversationResponse;
import com.example.gamify.dto.SendMessageRequest;
import com.example.gamify.service.ChatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/chats")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    // One entry per friend the player has exchanged messages with, newest first
    @GetMapping
    public ResponseEntity<List<ConversationResponse>> getConversations(@AuthenticationPrincipal String currentUsername) {
        return ResponseEntity.ok(chatService.getConversations(currentUsername));
    }

    // Messages with a friend, oldest first. No params: latest page. afterId: newer messages (polling). beforeId: older page.
    @GetMapping("/{friendId}/messages")
    public ResponseEntity<List<ChatMessageResponse>> getMessages(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long friendId,
            @RequestParam(required = false) Long afterId,
            @RequestParam(required = false) Long beforeId) {
        return ResponseEntity.ok(chatService.getMessages(currentUsername, friendId, afterId, beforeId));
    }

    @PostMapping("/{friendId}/messages")
    public ResponseEntity<ChatMessageResponse> sendMessage(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long friendId,
            @Valid @RequestBody SendMessageRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(chatService.sendMessage(currentUsername, friendId, request.content()));
    }
}
