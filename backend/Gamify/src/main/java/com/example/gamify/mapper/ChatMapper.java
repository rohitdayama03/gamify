package com.example.gamify.mapper;

import com.example.gamify.dto.ChatMessageResponse;
import com.example.gamify.entity.ChatMessage;
import com.example.gamify.entity.Player;
import org.springframework.stereotype.Component;

@Component
public class ChatMapper {

    public ChatMessageResponse toChatMessageResponse(ChatMessage message, Player currentPlayer) {
        Long senderId = message.getSender().getPlayerId();
        return new ChatMessageResponse(
                message.getId(),
                senderId,
                message.getReceiver().getPlayerId(),
                message.getContent(),
                senderId.equals(currentPlayer.getPlayerId()),
                message.getCreatedAt(),
                message.getReadAt()
        );
    }
}
