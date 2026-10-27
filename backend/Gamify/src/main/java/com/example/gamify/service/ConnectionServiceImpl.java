package com.example.gamify.service;

import com.example.gamify.dto.ConnectionResponse;
import com.example.gamify.entity.ConnectionStatus;
import com.example.gamify.entity.Player;
import com.example.gamify.entity.PlayerConnection;
import com.example.gamify.exception.BadRequestException;
import com.example.gamify.exception.ResourceNotFoundException;
import com.example.gamify.mapper.ConnectionMapper;
import com.example.gamify.repository.PlayerConnectionRepository;
import com.example.gamify.repository.PlayerRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ConnectionServiceImpl implements ConnectionService {

    private final PlayerRepository playerRepository;
    private final PlayerConnectionRepository connectionRepository;
    private final ConnectionMapper connectionMapper;

    @Override
    @Transactional(readOnly = true)
    public List<ConnectionResponse> getMyConnections(String username) {
        Player me = findPlayer(username);
        return connectionRepository.findAllInvolving(me).stream()
                .map(connection -> connectionMapper.toConnectionResponse(connection, me))
                .toList();
    }

    @Override
    @Transactional
    public ConnectionResponse sendInvite(String username, Long receiverId) {
        Player me = findPlayer(username);
        Player receiver = playerRepository.findById(receiverId)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with ID: " + receiverId));

        if (me.getPlayerId().equals(receiver.getPlayerId())) {
            throw new BadRequestException("You cannot send an invite to yourself");
        }

        connectionRepository.findBySenderAndReceiver(me, receiver).ifPresent(existing -> {
            switch (existing.getStatus()) {
                case PENDING -> throw new BadRequestException("Invite already sent to " + receiver.getUsername());
                case ACCEPTED -> throw new BadRequestException("You are already friends with " + receiver.getUsername());
                case DECLINED -> throw new BadRequestException(receiver.getUsername() + " declined your invite. You can't send another one.");
            }
        });

        // An invite in the other direction: a pending one must be answered instead, and an
        // accepted one already makes us friends. If I declined theirs earlier, I may still invite them.
        connectionRepository.findBySenderAndReceiver(receiver, me).ifPresent(reverse -> {
            if (reverse.getStatus() == ConnectionStatus.PENDING) {
                throw new BadRequestException(receiver.getUsername() + " has already invited you. Check your notifications.");
            }
            if (reverse.getStatus() == ConnectionStatus.ACCEPTED) {
                throw new BadRequestException("You are already friends with " + receiver.getUsername());
            }
        });

        PlayerConnection connection = PlayerConnection.builder()
                .sender(me)
                .receiver(receiver)
                .status(ConnectionStatus.PENDING)
                .build();

        return connectionMapper.toConnectionResponse(connectionRepository.save(connection), me);
    }

    @Override
    @Transactional
    public ConnectionResponse acceptInvite(String username, Long connectionId) {
        return respond(username, connectionId, ConnectionStatus.ACCEPTED);
    }

    @Override
    @Transactional
    public ConnectionResponse declineInvite(String username, Long connectionId) {
        return respond(username, connectionId, ConnectionStatus.DECLINED);
    }

    // The sender withdraws a pending invite. The row is deleted (not marked cancelled) so it
    // disappears for the receiver and the sender can invite again later.
    @Override
    @Transactional
    public void cancelInvite(String username, Long connectionId) {
        Player me = findPlayer(username);
        PlayerConnection connection = connectionRepository.findById(connectionId)
                // Only the sender may cancel; hide other players' invites behind a 404
                .filter(c -> c.getSender().getPlayerId().equals(me.getPlayerId()))
                .orElseThrow(() -> new ResourceNotFoundException("Invite not found with ID: " + connectionId));

        if (connection.getStatus() != ConnectionStatus.PENDING) {
            throw new BadRequestException("This invite has already been " + connection.getStatus().name().toLowerCase());
        }
        connectionRepository.delete(connection);
    }

    private ConnectionResponse respond(String username, Long connectionId, ConnectionStatus newStatus) {
        Player me = findPlayer(username);
        PlayerConnection connection = connectionRepository.findById(connectionId)
                // Only the receiver may respond; hide other players' invites behind a 404
                .filter(c -> c.getReceiver().getPlayerId().equals(me.getPlayerId()))
                .orElseThrow(() -> new ResourceNotFoundException("Invite not found with ID: " + connectionId));

        if (connection.getStatus() != ConnectionStatus.PENDING) {
            throw new BadRequestException("This invite has already been " + connection.getStatus().name().toLowerCase());
        }

        connection.setStatus(newStatus);
        connection.setRespondedAt(OffsetDateTime.now());
        return connectionMapper.toConnectionResponse(connectionRepository.save(connection), me);
    }

    private Player findPlayer(String username) {
        return playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));
    }
}
