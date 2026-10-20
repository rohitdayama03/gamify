package com.example.gamify.service;

import com.example.gamify.dto.ChatMessageResponse;
import com.example.gamify.dto.ConversationResponse;

import java.util.List;

public interface ChatService {
    List<ConversationResponse> getConversations(String username);
    List<ChatMessageResponse> getMessages(String username, Long friendId, Long afterId, Long beforeId);
    ChatMessageResponse sendMessage(String username, Long friendId, String content);
}
