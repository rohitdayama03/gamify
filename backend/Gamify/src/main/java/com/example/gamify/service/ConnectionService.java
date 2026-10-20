package com.example.gamify.service;

import com.example.gamify.dto.ConnectionResponse;

import java.util.List;

public interface ConnectionService {
    List<ConnectionResponse> getMyConnections(String username);
    ConnectionResponse sendInvite(String username, Long receiverId);
    ConnectionResponse acceptInvite(String username, Long connectionId);
    ConnectionResponse declineInvite(String username, Long connectionId);
}
