package com.example.gamify.service;

import com.example.gamify.dto.*;
import com.example.gamify.dto.TournamentSummaryResponse.MyStatus;
import com.example.gamify.entity.*;
import com.example.gamify.exception.BadRequestException;
import com.example.gamify.exception.ResourceNotFoundException;
import com.example.gamify.mapper.ConnectionMapper;
import com.example.gamify.notification.PushNotification;
import com.example.gamify.repository.PlayerRepository;
import com.example.gamify.repository.TournamentMessageRepository;
import com.example.gamify.repository.TournamentParticipantRepository;
import com.example.gamify.repository.TournamentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TournamentServiceImpl implements TournamentService {

    // Most open tournaments listed at once
    private static final int OPEN_LIST_SIZE = 100;

    private static final int PAGE_SIZE = 50;

    // Longest message text shown in a notification
    private static final int PREVIEW_LENGTH = 150;

    private final PlayerRepository playerRepository;
    private final TournamentRepository tournamentRepository;
    private final TournamentParticipantRepository participantRepository;
    private final TournamentMessageRepository messageRepository;
    private final ConnectionMapper connectionMapper;
    private final ApplicationEventPublisher events;

    @Override
    @Transactional(readOnly = true)
    public List<TournamentSummaryResponse> getOpenTournaments(String username, Game game) {
        Player me = findPlayer(username);
        PageRequest page = PageRequest.of(0, OPEN_LIST_SIZE);
        return toSummaries(game == null ? tournamentRepository.findOpen(page) : tournamentRepository.findOpenByGame(game, page), me);
    }

    @Override
    @Transactional(readOnly = true)
    public List<TournamentSummaryResponse> getMyTournaments(String username) {
        Player me = findPlayer(username);
        return toSummaries(tournamentRepository.findInvolving(me), me);
    }

    @Override
    @Transactional
    public TournamentDetailResponse createTournament(String username, CreateTournamentRequest request) {
        Player me = findPlayer(username);
        String description = request.description() == null ? null : request.description().trim();
        Tournament tournament = tournamentRepository.save(Tournament.builder()
                .name(request.name().trim().replaceAll("\\s+", " "))
                .game(request.game())
                .description(description == null || description.isEmpty() ? null : description)
                .startsAt(request.startsAt())
                .maxParticipants(request.maxParticipants())
                .organizer(me)
                .status(TournamentStatus.OPEN)
                .build());
        return toDetail(tournament, me);
    }

    @Override
    @Transactional(readOnly = true)
    public TournamentDetailResponse getTournament(String username, Long tournamentId) {
        Player me = findPlayer(username);
        return toDetail(findTournament(tournamentId), me);
    }

    @Override
    @Transactional
    public void deleteTournament(String username, Long tournamentId) {
        Player me = findPlayer(username);
        Tournament tournament = findTournament(tournamentId);
        requireOrganizer(tournament, me);
        for (Long playerId : participantRepository.findAcceptedPlayerIds(tournament)) {
            notify(playerId, "Tournament cancelled", me.getUsername() + " cancelled " + tournament.getName(),
                    PushNotification.CHANNEL_REQUESTS, tournament, "tournament_update");
        }
        delete(tournament);
    }

    @Override
    @Transactional
    public TournamentDetailResponse requestToJoin(String username, Long tournamentId) {
        Player me = findPlayer(username);
        Tournament tournament = findTournament(tournamentId);
        if (isOrganizer(tournament, me)) {
            throw new BadRequestException("You're organizing this tournament");
        }
        requireOpen(tournament);
        if (!tournament.getStartsAt().isAfter(OffsetDateTime.now())) {
            throw new BadRequestException("Registration closed when the tournament started");
        }
        participantRepository.findByTournamentAndPlayer(tournament, me).ifPresent(existing -> {
            switch (existing.getStatus()) {
                case PENDING -> throw new BadRequestException("You've already asked to join. Wait for the organizer to answer.");
                case ACCEPTED -> throw new BadRequestException("You're already in this tournament");
                case REJECTED -> throw new BadRequestException("The organizer turned down your request. You can't ask again.");
            }
        });
        requireRoom(tournament);

        participantRepository.save(TournamentParticipant.builder()
                .tournament(tournament)
                .player(me)
                .status(ParticipantStatus.PENDING)
                .build());
        notify(tournament.getOrganizer().getPlayerId(), "Join request",
                me.getUsername() + " wants to join " + tournament.getName(),
                PushNotification.CHANNEL_REQUESTS, tournament, "tournament_request");
        return toDetail(tournament, me);
    }

    // Deletes the request, so the player may ask again later
    @Override
    @Transactional
    public TournamentDetailResponse withdraw(String username, Long tournamentId) {
        Player me = findPlayer(username);
        Tournament tournament = findTournament(tournamentId);
        requireOpen(tournament);
        TournamentParticipant participant = participantRepository.findByTournamentAndPlayer(tournament, me)
                .filter(p -> p.getStatus() != ParticipantStatus.REJECTED)
                .orElseThrow(() -> new BadRequestException("You haven't joined this tournament"));
        participantRepository.delete(participant);
        return toDetail(tournament, me);
    }

    @Override
    @Transactional(readOnly = true)
    public List<TournamentRequestResponse> getPendingRequests(String username) {
        Player me = findPlayer(username);
        return participantRepository.findPendingForOrganizer(me).stream()
                .map(p -> new TournamentRequestResponse(
                        p.getId(),
                        p.getTournament().getId(),
                        p.getTournament().getName(),
                        p.getTournament().getGame(),
                        connectionMapper.toPlayerSummary(p.getPlayer()),
                        p.getCreatedAt()))
                .toList();
    }

    @Override
    @Transactional
    public TournamentDetailResponse acceptRequest(String username, Long requestId) {
        return respond(username, requestId, ParticipantStatus.ACCEPTED);
    }

    @Override
    @Transactional
    public TournamentDetailResponse rejectRequest(String username, Long requestId) {
        return respond(username, requestId, ParticipantStatus.REJECTED);
    }

    private TournamentDetailResponse respond(String username, Long requestId, ParticipantStatus newStatus) {
        Player me = findPlayer(username);
        TournamentParticipant request = participantRepository.findById(requestId)
                // Only the organizer may answer; hide other tournaments' requests behind a 404
                .filter(p -> isOrganizer(p.getTournament(), me))
                .orElseThrow(() -> new ResourceNotFoundException("Join request not found with ID: " + requestId));
        Tournament tournament = request.getTournament();
        requireOpen(tournament);
        if (request.getStatus() != ParticipantStatus.PENDING) {
            throw new BadRequestException("This request has already been " + request.getStatus().name().toLowerCase());
        }
        if (newStatus == ParticipantStatus.ACCEPTED) {
            requireRoom(tournament);
        }

        request.setStatus(newStatus);
        request.setRespondedAt(OffsetDateTime.now());
        participantRepository.save(request);
        if (newStatus == ParticipantStatus.ACCEPTED) {
            notify(request.getPlayer().getPlayerId(), "You're in!",
                    me.getUsername() + " accepted you into " + tournament.getName(),
                    PushNotification.CHANNEL_REQUESTS, tournament, "tournament_update");
        } else {
            notify(request.getPlayer().getPlayerId(), "Request declined",
                    "Your request to join " + tournament.getName() + " wasn't accepted",
                    PushNotification.CHANNEL_REQUESTS, tournament, "tournament_update");
        }
        return toDetail(tournament, me);
    }

    // Can be called again to correct the result
    @Override
    @Transactional
    public TournamentDetailResponse recordResult(String username, Long tournamentId, RecordResultRequest request) {
        Player me = findPlayer(username);
        Tournament tournament = findTournament(tournamentId);
        requireOrganizer(tournament, me);

        Map<Long, TournamentParticipant> accepted = participantRepository.findAllByTournament(tournament).stream()
                .filter(p -> p.getStatus() == ParticipantStatus.ACCEPTED)
                .collect(Collectors.toMap(p -> p.getPlayer().getPlayerId(), Function.identity()));
        Map<Long, Integer> placements = new HashMap<>();
        for (RecordResultRequest.Placement placement : request.placements()) {
            if (!accepted.containsKey(placement.playerId())) {
                throw new BadRequestException("Only accepted participants can be placed");
            }
            if (placement.placement() > accepted.size()) {
                throw new BadRequestException("Placements go from 1 to " + accepted.size());
            }
            placements.put(placement.playerId(), placement.placement());
        }
        accepted.forEach((playerId, participant) -> participant.setPlacement(placements.get(playerId)));

        boolean firstTime = tournament.getStatus() != TournamentStatus.COMPLETED;
        String notes = request.notes() == null ? null : request.notes().trim();
        tournament.setResultNotes(notes == null || notes.isEmpty() ? null : notes);
        tournament.setStatus(TournamentStatus.COMPLETED);
        if (firstTime) {
            tournament.setCompletedAt(OffsetDateTime.now());
        }
        tournamentRepository.save(tournament);

        for (Long playerId : accepted.keySet()) {
            notify(playerId, firstTime ? "Results are in" : "Results updated",
                    tournament.getName() + ": see where you placed",
                    PushNotification.CHANNEL_REQUESTS, tournament, "tournament_update");
        }
        return toDetail(tournament, me);
    }

    @Override
    @Transactional(readOnly = true)
    public List<TournamentChatResponse> getChats(String username) {
        Player me = findPlayer(username);
        List<Tournament> involved = tournamentRepository.findInvolving(me);
        if (involved.isEmpty()) {
            return List.of();
        }
        Set<Long> ids = involved.stream().map(Tournament::getId).collect(Collectors.toSet());
        Map<Long, TournamentParticipant> mine = participantRepository.findMine(me, ids).stream()
                .collect(Collectors.toMap(p -> p.getTournament().getId(), Function.identity()));
        Map<Long, Long> counts = toCountMap(participantRepository.countAcceptedByTournamentIds(ids));
        Map<Long, Long> unread = toCountMap(messageRepository.countUnreadByTournament(me));
        Map<Long, TournamentMessage> lastMessages = messageRepository.findLastMessages(ids).stream()
                .collect(Collectors.toMap(m -> m.getTournament().getId(), Function.identity()));

        return involved.stream()
                // Only the organizer and accepted players are in the chat
                .filter(t -> isOrganizer(t, me) || isAccepted(mine.get(t.getId())))
                .map(t -> {
                    boolean organizer = isOrganizer(t, me);
                    TournamentMessage last = lastMessages.get(t.getId());
                    return new TournamentChatResponse(
                            t.getId(),
                            t.getName(),
                            t.getGame(),
                            organizer,
                            counts.getOrDefault(t.getId(), 0L),
                            last == null ? null : toMessageResponse(last, me),
                            organizer ? 0 : unread.getOrDefault(t.getId(), 0L),
                            organizer ? t.getCreatedAt() : mine.get(t.getId()).getRespondedAt()
                    );
                })
                .toList();
    }

    @Override
    @Transactional
    public List<TournamentMessageResponse> getMessages(String username, Long tournamentId, Long afterId, Long beforeId) {
        Player me = findPlayer(username);
        Tournament tournament = findTournament(tournamentId);
        TournamentParticipant participant = requireChatAccess(tournament, me);

        List<TournamentMessage> messages;
        if (afterId != null) {
            messages = messageRepository.findNewer(tournament, afterId, PageRequest.of(0, PAGE_SIZE));
        } else {
            // Initial load or "load older": newest-first from the database, flipped to oldest-first
            messages = new ArrayList<>(messageRepository.findOlder(
                    tournament, beforeId != null ? beforeId : Long.MAX_VALUE, PageRequest.of(0, PAGE_SIZE)));
            Collections.reverse(messages);
        }

        // Opening the chat means every announcement so far has been read
        if (participant != null) {
            Long lastId = messageRepository.findLastMessageId(tournament);
            if (participant.getLastReadMessageId() == null || participant.getLastReadMessageId() < lastId) {
                participant.setLastReadMessageId(lastId);
            }
        }
        return messages.stream().map(m -> toMessageResponse(m, me)).toList();
    }

    @Override
    @Transactional
    public TournamentMessageResponse sendMessage(String username, Long tournamentId, String content) {
        Player me = findPlayer(username);
        Tournament tournament = findTournament(tournamentId);
        if (!isOrganizer(tournament, me)) {
            throw new BadRequestException("Only the organizer can post in this chat");
        }
        TournamentMessage saved = messageRepository.save(TournamentMessage.builder()
                .tournament(tournament)
                .sender(me)
                .content(content.trim())
                .build());
        // One notification per tournament: a newer announcement replaces the previous one on the phone
        for (Long playerId : participantRepository.findAcceptedPlayerIds(tournament)) {
            events.publishEvent(new PushNotification(
                    playerId,
                    tournament.getName(),
                    preview(saved.getContent()),
                    PushNotification.CHANNEL_MESSAGES,
                    "tournament-" + tournament.getId(),
                    Map.of("type", "tournament_message", "tournamentId", String.valueOf(tournament.getId()), "tournamentName", tournament.getName())
            ));
        }
        return toMessageResponse(saved, me);
    }

    @Override
    @Transactional(readOnly = true)
    public List<PlayerTournamentResponse> getPlayerTournaments(Long playerId) {
        Player player = playerRepository.findById(playerId)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with ID: " + playerId));
        List<TournamentParticipant> entries = participantRepository.findAcceptedByPlayer(player);
        if (entries.isEmpty()) {
            return List.of();
        }
        Map<Long, Long> counts = toCountMap(participantRepository.countAcceptedByTournamentIds(
                entries.stream().map(p -> p.getTournament().getId()).collect(Collectors.toSet())));
        return entries.stream()
                .map(p -> {
                    Tournament t = p.getTournament();
                    return new PlayerTournamentResponse(
                            t.getId(),
                            t.getName(),
                            t.getGame(),
                            t.getStartsAt(),
                            t.getStatus(),
                            p.getPlacement(),
                            counts.getOrDefault(t.getId(), 0L),
                            t.getOrganizer().getUsername()
                    );
                })
                .toList();
    }

    @Override
    @Transactional
    public void removePlayerFromAllTournaments(Player player) {
        for (Tournament tournament : tournamentRepository.findAllByOrganizer(player)) {
            delete(tournament);
        }
        participantRepository.deleteAllByPlayer(player);
    }

    private void delete(Tournament tournament) {
        messageRepository.deleteAllByTournament(tournament);
        participantRepository.deleteAllByTournament(tournament);
        tournamentRepository.delete(tournament);
    }

    private List<TournamentSummaryResponse> toSummaries(List<Tournament> tournaments, Player me) {
        if (tournaments.isEmpty()) {
            return List.of();
        }
        Set<Long> ids = tournaments.stream().map(Tournament::getId).collect(Collectors.toSet());
        Map<Long, Long> counts = toCountMap(participantRepository.countAcceptedByTournamentIds(ids));
        Map<Long, ParticipantStatus> mine = participantRepository.findMine(me, ids).stream()
                .collect(Collectors.toMap(p -> p.getTournament().getId(), TournamentParticipant::getStatus));
        return tournaments.stream()
                .map(t -> toSummary(t, me, counts.getOrDefault(t.getId(), 0L), mine.get(t.getId())))
                .toList();
    }

    private TournamentSummaryResponse toSummary(Tournament t, Player me, long participantCount, ParticipantStatus myRequest) {
        MyStatus myStatus = isOrganizer(t, me) ? MyStatus.ORGANIZER
                : myRequest == null ? MyStatus.NONE
                : MyStatus.valueOf(myRequest.name());
        return new TournamentSummaryResponse(
                t.getId(),
                t.getName(),
                t.getGame(),
                t.getDescription(),
                t.getStartsAt(),
                t.getMaxParticipants(),
                participantCount,
                t.getStatus(),
                connectionMapper.toPlayerSummary(t.getOrganizer()),
                myStatus,
                t.getCompletedAt()
        );
    }

    private TournamentDetailResponse toDetail(Tournament tournament, Player me) {
        boolean organizer = isOrganizer(tournament, me);
        List<TournamentParticipant> all = participantRepository.findAllByTournament(tournament);
        long accepted = all.stream().filter(p -> p.getStatus() == ParticipantStatus.ACCEPTED).count();
        ParticipantStatus myRequest = all.stream()
                .filter(p -> p.getPlayer().getPlayerId().equals(me.getPlayerId()))
                .map(TournamentParticipant::getStatus)
                .findFirst().orElse(null);
        return new TournamentDetailResponse(
                toSummary(tournament, me, accepted, myRequest),
                all.stream()
                        // Requests are the organizer's business; everyone else sees who's playing
                        .filter(p -> organizer || p.getStatus() == ParticipantStatus.ACCEPTED)
                        .map(p -> new TournamentParticipantResponse(
                                p.getId(),
                                connectionMapper.toPlayerSummary(p.getPlayer()),
                                p.getStatus(),
                                p.getPlacement(),
                                p.getCreatedAt()))
                        .toList(),
                tournament.getResultNotes()
        );
    }

    private TournamentMessageResponse toMessageResponse(TournamentMessage message, Player me) {
        Player sender = message.getSender();
        return new TournamentMessageResponse(
                message.getId(),
                message.getTournament().getId(),
                sender.getPlayerId(),
                sender.getUsername(),
                message.getContent(),
                sender.getPlayerId().equals(me.getPlayerId()),
                message.getCreatedAt()
        );
    }

    // The organizer (returns null) or an accepted participant (returns their row) may read the chat
    private TournamentParticipant requireChatAccess(Tournament tournament, Player me) {
        if (isOrganizer(tournament, me)) {
            return null;
        }
        return participantRepository.findByTournamentAndPlayer(tournament, me)
                .filter(TournamentServiceImpl::isAccepted)
                .orElseThrow(() -> new BadRequestException("Only accepted participants can read this chat"));
    }

    private void requireRoom(Tournament tournament) {
        Integer max = tournament.getMaxParticipants();
        if (max != null && participantRepository.countByTournamentAndStatus(tournament, ParticipantStatus.ACCEPTED) >= max) {
            throw new BadRequestException(tournament.getName() + " is full");
        }
    }

    private static void requireOpen(Tournament tournament) {
        if (tournament.getStatus() != TournamentStatus.OPEN) {
            throw new BadRequestException("This tournament is over");
        }
    }

    private static void requireOrganizer(Tournament tournament, Player me) {
        if (!isOrganizer(tournament, me)) {
            throw new BadRequestException("Only the organizer can do that");
        }
    }

    private static boolean isOrganizer(Tournament tournament, Player player) {
        return tournament.getOrganizer().getPlayerId().equals(player.getPlayerId());
    }

    private static boolean isAccepted(TournamentParticipant participant) {
        return participant != null && participant.getStatus() == ParticipantStatus.ACCEPTED;
    }

    private void notify(Long recipientId, String title, String body, String channel, Tournament tournament, String type) {
        events.publishEvent(new PushNotification(
                recipientId,
                title,
                body,
                channel,
                type + "-" + tournament.getId(),
                Map.of("type", type, "tournamentId", String.valueOf(tournament.getId()), "tournamentName", tournament.getName())
        ));
    }

    private static Map<Long, Long> toCountMap(List<Object[]> rows) {
        Map<Long, Long> counts = new HashMap<>();
        for (Object[] row : rows) {
            counts.put((Long) row[0], (Long) row[1]);
        }
        return counts;
    }

    private static String preview(String content) {
        return content.length() <= PREVIEW_LENGTH ? content : content.substring(0, PREVIEW_LENGTH) + "…";
    }

    private Tournament findTournament(Long tournamentId) {
        return tournamentRepository.findById(tournamentId)
                .orElseThrow(() -> new ResourceNotFoundException("Tournament not found with ID: " + tournamentId));
    }

    private Player findPlayer(String username) {
        return playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));
    }
}
