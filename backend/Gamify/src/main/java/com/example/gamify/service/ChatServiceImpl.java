package com.example.gamify.service;

import com.example.gamify.dto.ChatMessageResponse;
import com.example.gamify.dto.ConversationResponse;
import com.example.gamify.entity.ChatMessage;
import com.example.gamify.entity.Player;
import com.example.gamify.exception.BadRequestException;
import com.example.gamify.exception.ResourceNotFoundException;
import com.example.gamify.mapper.ChatMapper;
import com.example.gamify.mapper.ConnectionMapper;
import com.example.gamify.repository.ChatMessageRepository;
import com.example.gamify.repository.PlayerConnectionRepository;
import com.example.gamify.repository.PlayerRepository;
import com.example.gamify.notification.PushNotification;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ChatServiceImpl implements ChatService {

    // Longest message text shown in a notification
    private static final int PREVIEW_LENGTH = 150;

    private static final int PAGE_SIZE = 50;

    private final PlayerRepository playerRepository;
    private final PlayerConnectionRepository connectionRepository;
    private final ChatMessageRepository messageRepository;
    private final ChatMapper chatMapper;
    private final ConnectionMapper connectionMapper;
    private final ApplicationEventPublisher events;

    @Override
    @Transactional(readOnly = true)
    public List<ConversationResponse> getConversations(String username) {
        Player me = findPlayer(username);

        List<Long> lastIds = messageRepository.findLastMessageIds(me);
        if (lastIds.isEmpty()) {
            return List.of();
        }

        Map<Long, Long> unreadBySender = new HashMap<>();
        for (Object[] row : messageRepository.countUnreadBySender(me)) {
            unreadBySender.put((Long) row[0], (Long) row[1]);
        }

        // Already sorted newest conversation first
        return messageRepository.findAllWithPlayersByIdIn(lastIds).stream()
                .map(message -> {
                    boolean sentByMe = message.getSender().getPlayerId().equals(me.getPlayerId());
                    Player friend = sentByMe ? message.getReceiver() : message.getSender();
                    return new ConversationResponse(
                            connectionMapper.toPlayerSummary(friend),
                            chatMapper.toChatMessageResponse(message, me),
                            unreadBySender.getOrDefault(friend.getPlayerId(), 0L)
                    );
                })
                .toList();
    }

    @Override
    @Transactional
    public List<ChatMessageResponse> getMessages(String username, Long friendId, Long afterId, Long beforeId) {
        Player me = findPlayer(username);
        Player friend = findFriend(me, friendId);

        List<ChatMessage> messages;
        if (afterId != null) {
            messages = messageRepository.findNewer(me, friend, afterId, PageRequest.of(0, PAGE_SIZE));
        } else {
            // Initial load or "load older": newest-first from the database, flipped to oldest-first
            messages = new ArrayList<>(messageRepository.findOlder(
                    me, friend, beforeId != null ? beforeId : Long.MAX_VALUE, PageRequest.of(0, PAGE_SIZE)));
            Collections.reverse(messages);
        }

        // Opening the chat means everything the friend sent so far has been read
        messageRepository.markAsRead(me, friend, OffsetDateTime.now());

        return messages.stream()
                .map(message -> chatMapper.toChatMessageResponse(message, me))
                .toList();
    }

    @Override
    @Transactional
    public ChatMessageResponse sendMessage(String username, Long friendId, String content) {
        Player me = findPlayer(username);
        Player friend = findFriend(me, friendId);

        ChatMessage message = ChatMessage.builder()
                .sender(me)
                .receiver(friend)
                .content(content.trim())
                .build();

        ChatMessage saved = messageRepository.save(message);
        // One notification per chat: a newer message replaces the previous one on the phone
        events.publishEvent(new PushNotification(
                friend.getPlayerId(),
                me.getUsername(),
                preview(saved.getContent()),
                PushNotification.CHANNEL_MESSAGES,
                "chat-" + me.getPlayerId(),
                Map.of("type", "message", "playerId", String.valueOf(me.getPlayerId()), "username", me.getUsername())
        ));
        return chatMapper.toChatMessageResponse(saved, me);
    }

    private static String preview(String content) {
        return content.length() <= PREVIEW_LENGTH ? content : content.substring(0, PREVIEW_LENGTH) + "…";
    }

    private Player findFriend(Player me, Long friendId) {
        Player friend = playerRepository.findById(friendId)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with ID: " + friendId));
        if (!connectionRepository.areFriends(me, friend)) {
            throw new BadRequestException("You can only chat with your friends");
        }
        return friend;
    }

    private Player findPlayer(String username) {
        return playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));
    }
}
