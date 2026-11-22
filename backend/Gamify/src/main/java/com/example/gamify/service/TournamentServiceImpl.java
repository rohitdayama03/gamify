package com.example.gamify.service;

import com.example.gamify.dto.*;
import com.example.gamify.dto.TournamentSummaryResponse.MyStatus;
import com.example.gamify.entity.*;
import com.example.gamify.exception.BadRequestException;
import com.example.gamify.exception.ResourceNotFoundException;
import com.example.gamify.mapper.ConnectionMapper;
import com.example.gamify.notification.PushNotification;
import com.example.gamify.repository.PlayerRepository;
import com.example.gamify.repository.TournamentCoOrganizerRepository;
import com.example.gamify.repository.TournamentMessageRepository;
import com.example.gamify.repository.TournamentParticipantRepository;
import com.example.gamify.repository.TournamentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
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

    // Most players the creator can add to help run a tournament
    static final int MAX_CO_ORGANIZERS = 5;

    private final PlayerRepository playerRepository;
    private final TournamentRepository tournamentRepository;
    private final TournamentParticipantRepository participantRepository;
    private final TournamentCoOrganizerRepository coOrganizerRepository;
    private final TournamentMessageRepository messageRepository;
    private final ConnectionMapper connectionMapper;
    private final ApplicationEventPublisher events;
    private final TournamentFormatService formatService;

    @Override
    @Transactional(readOnly = true)
    public List<TournamentSummaryResponse> getOpenTournaments(String username, Game game) {
        Player me = findPlayer(username);
        PageRequest page = PageRequest.of(0, OPEN_LIST_SIZE);
        return toSummaries(game == null ? tournamentRepository.findOpen(page) : tournamentRepository.findOpenByGame(game, page), me);
    }

    @Override
    @Transactional(readOnly = true)
    public List<TournamentSummaryResponse> searchTournaments(String username, String text, Game game, TournamentStatus status,
                                                             TournamentSearchSort sort, int page, int size) {
        Player me = findPlayer(username);
        String exact = text.trim().toLowerCase(Locale.ROOT);
        String escaped = escapeLike(exact);
        String prefix = escaped + "%";
        String contains = "%" + escaped + "%";
        List<Tournament> found = switch (sort) {
            case RELEVANCE -> tournamentRepository.searchByRelevance(
                    exact, prefix, contains, "% " + prefix, game, status, PageRequest.of(page, size));
            case STARTS_EARLIEST -> tournamentRepository.search(
                    prefix, contains, game, status, PageRequest.of(page, size, Sort.by("startsAt").ascending().and(Sort.by("id"))));
            case STARTS_LATEST -> tournamentRepository.search(
                    prefix, contains, game, status, PageRequest.of(page, size, Sort.by("startsAt").descending().and(Sort.by("id").descending())));
        };
        return toSummaries(found, me);
    }

    // Treat % and _ typed by the player as literal characters
    private static String escapeLike(String value) {
        return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
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
        if (request.format() != null) {
            formatService.saveFormat(tournament, request.format());
        }
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
        requireOwner(tournament, me, "Only the creator can cancel the tournament");
        Set<Long> toTell = new LinkedHashSet<>(playersExcept(tournament, me));
        toTell.addAll(coOrganizerRepository.findPlayerIds(tournament));
        for (Long playerId : toTell) {
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
        requireOpen(tournament);
        // A tournament with a format takes requests until the organizer starts it
        if (!tournament.hasFormat() && !tournament.getStartsAt().isAfter(OffsetDateTime.now())) {
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

        // Organizers don't need to ask themselves: they're in straight away
        if (isOrganizer(tournament, me)) {
            participantRepository.save(TournamentParticipant.builder()
                    .tournament(tournament)
                    .player(me)
                    .status(ParticipantStatus.ACCEPTED)
                    .respondedAt(OffsetDateTime.now())
                    .build());
            return toDetail(tournament, me);
        }

        participantRepository.save(TournamentParticipant.builder()
                .tournament(tournament)
                .player(me)
                .status(ParticipantStatus.PENDING)
                .build());
        for (Long organizerId : organizerIds(tournament)) {
            notify(organizerId, "Join request",
                    me.getUsername() + " wants to join " + tournament.getName(),
                    PushNotification.CHANNEL_REQUESTS, tournament, "tournament_request");
        }
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
        if (tournament.hasFormat()) {
            throw new BadRequestException("This tournament is settled match by match. Enter the results in its fixtures.");
        }

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
            if (playerId.equals(me.getPlayerId())) {
                continue;
            }
            notify(playerId, firstTime ? "Results are in" : "Results updated",
                    tournament.getName() + ": see where you placed",
                    PushNotification.CHANNEL_REQUESTS, tournament, "tournament_update");
        }
        return toDetail(tournament, me);
    }

    @Override
    @Transactional
    public TournamentDetailResponse updateFormat(String username, Long tournamentId, TournamentFormatRequest request) {
        Player me = findPlayer(username);
        Tournament tournament = findTournament(tournamentId);
        requireOrganizer(tournament, me);
        requireOpen(tournament);
        // Organizers' own entries don't lock it: only other players signed up for this format
        if (acceptedNonOrganizers(tournament) > 0) {
            throw new BadRequestException("The format is locked once you've accepted a player");
        }
        formatService.saveFormat(tournament, request);
        return toDetail(tournament, me);
    }

    @Override
    @Transactional
    public TournamentDetailResponse startTournament(String username, Long tournamentId, StartTournamentRequest request) {
        Player me = findPlayer(username);
        Tournament tournament = findTournament(tournamentId);
        requireOrganizer(tournament, me);
        formatService.start(tournament, request, me);
        return toDetail(tournament, me);
    }

    @Override
    @Transactional(readOnly = true)
    public TournamentFixturesResponse getFixtures(String username, Long tournamentId) {
        Player me = findPlayer(username);
        Tournament tournament = findFormatTournament(tournamentId);
        return formatService.fixtures(tournament, isOrganizer(tournament, me));
    }

    @Override
    @Transactional
    public TournamentFixturesResponse recordMatchResult(String username, Long tournamentId, Long matchId, MatchResultRequest request) {
        Player me = findPlayer(username);
        Tournament tournament = findFormatTournament(tournamentId);
        requireOrganizer(tournament, me);
        formatService.recordMatch(tournament, matchId, request, me);
        return formatService.fixtures(tournament, true);
    }

    @Override
    @Transactional
    public TournamentDetailResponse finishStage(String username, Long tournamentId, Long stageId, FinishStageRequest request) {
        Player me = findPlayer(username);
        Tournament tournament = findFormatTournament(tournamentId);
        requireOrganizer(tournament, me);
        formatService.finish(tournament, stageId, request, me);
        return toDetail(tournament, me);
    }

    @Override
    @Transactional(readOnly = true)
    public TournamentLeaderboardResponse getLeaderboard(String username, Long tournamentId) {
        findPlayer(username);
        return formatService.leaderboard(findFormatTournament(tournamentId));
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
        Set<Long> coOrganized = new HashSet<>(coOrganizerRepository.findTournamentIds(me));

        return involved.stream()
                // Only organizers and accepted players are in the chat
                .filter(t -> isOrganizer(t, me, coOrganized) || isAccepted(mine.get(t.getId())))
                .map(t -> {
                    boolean organizer = isOrganizer(t, me, coOrganized);
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
            throw new BadRequestException("Only organizers can post in this chat");
        }
        TournamentMessage saved = messageRepository.save(TournamentMessage.builder()
                .tournament(tournament)
                .sender(me)
                .content(content.trim())
                .build());
        // One notification per tournament: a newer announcement replaces the previous one on the phone
        for (Long playerId : playersExcept(tournament, me)) {
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
    @Transactional
    public TournamentDetailResponse addCoOrganizer(String username, Long tournamentId, Long playerId) {
        Player me = findPlayer(username);
        Tournament tournament = findTournament(tournamentId);
        requireOwner(tournament, me, "Only the creator can add organizers");
        Player player = playerRepository.findById(playerId)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with ID: " + playerId));
        if (isOwner(tournament, player)) {
            throw new BadRequestException("You're already organizing this tournament");
        }
        if (coOrganizerRepository.existsByTournamentAndPlayer(tournament, player)) {
            throw new BadRequestException(player.getUsername() + " is already an organizer");
        }
        if (coOrganizerRepository.countByTournament(tournament) >= MAX_CO_ORGANIZERS) {
            throw new BadRequestException("A tournament can have up to " + MAX_CO_ORGANIZERS + " co-organizers");
        }
        coOrganizerRepository.save(TournamentCoOrganizer.builder().tournament(tournament).player(player).build());
        notify(player.getPlayerId(), "You're an organizer",
                me.getUsername() + " added you as an organizer of " + tournament.getName(),
                PushNotification.CHANNEL_REQUESTS, tournament, "tournament_update");
        return toDetail(tournament, me);
    }

    // The creator removes anyone; a co-organizer can only step down themselves
    @Override
    @Transactional
    public TournamentDetailResponse removeCoOrganizer(String username, Long tournamentId, Long playerId) {
        Player me = findPlayer(username);
        Tournament tournament = findTournament(tournamentId);
        boolean steppingDown = me.getPlayerId().equals(playerId);
        if (!steppingDown) {
            requireOwner(tournament, me, "Only the creator can remove organizers");
        }
        Player player = steppingDown ? me : playerRepository.findById(playerId)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with ID: " + playerId));
        TournamentCoOrganizer coOrganizer = coOrganizerRepository.findByTournamentAndPlayer(tournament, player)
                .orElseThrow(() -> new BadRequestException(steppingDown
                        ? "You're not a co-organizer of this tournament"
                        : player.getUsername() + " isn't a co-organizer"));
        coOrganizerRepository.delete(coOrganizer);
        if (!steppingDown) {
            notify(player.getPlayerId(), "Organizer removed",
                    "You're no longer an organizer of " + tournament.getName(),
                    PushNotification.CHANNEL_REQUESTS, tournament, "tournament_update");
        }
        return toDetail(tournament, me);
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
        coOrganizerRepository.deleteAllByPlayer(player);
        for (TournamentParticipant participant : participantRepository.findAllByPlayer(player)) {
            Tournament tournament = participant.getTournament();
            boolean inFixtures = tournament.hasFormat() && tournament.getStatus() != TournamentStatus.OPEN
                    && participant.getStatus() == ParticipantStatus.ACCEPTED;
            if (inFixtures) {
                // The fixtures point at this row, so keep it under the name they played as
                participant.setFormerUsername(player.getUsername());
                participant.setPlayer(null);
            } else {
                participantRepository.delete(participant);
            }
        }
        participantRepository.flush();
    }

    private void delete(Tournament tournament) {
        formatService.deleteFormat(tournament);
        messageRepository.deleteAllByTournament(tournament);
        participantRepository.deleteAllByTournament(tournament);
        coOrganizerRepository.deleteAllByTournament(tournament);
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
        Set<Long> coOrganized = new HashSet<>(coOrganizerRepository.findTournamentIds(me));
        return tournaments.stream()
                .map(t -> toSummary(t, me, isOrganizer(t, me, coOrganized), counts.getOrDefault(t.getId(), 0L), mine.get(t.getId())))
                .toList();
    }

    private TournamentSummaryResponse toSummary(Tournament t, Player me, boolean organizer, long participantCount,
                                                ParticipantStatus myRequest) {
        MyStatus myStatus = organizer ? MyStatus.ORGANIZER
                : myRequest == null ? MyStatus.NONE
                : MyStatus.valueOf(myRequest.name());
        boolean amPlaying = myRequest == ParticipantStatus.ACCEPTED;
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
                amPlaying,
                isOwner(t, me),
                t.getCompletedAt(),
                t.getSlots()
        );
    }

    private TournamentDetailResponse toDetail(Tournament tournament, Player me) {
        boolean organizer = isOrganizer(tournament, me);
        List<TournamentParticipant> all = participantRepository.findAllByTournament(tournament);
        long accepted = all.stream().filter(p -> p.getStatus() == ParticipantStatus.ACCEPTED).count();
        List<TournamentCoOrganizer> coOrganizers = coOrganizerRepository.findAllByTournament(tournament);
        Set<Long> organizerIds = new HashSet<>();
        organizerIds.add(tournament.getOrganizer().getPlayerId());
        coOrganizers.forEach(c -> organizerIds.add(c.getPlayer().getPlayerId()));
        long acceptedOthers = all.stream()
                .filter(p -> p.getStatus() == ParticipantStatus.ACCEPTED)
                .filter(p -> p.getPlayer() == null || !organizerIds.contains(p.getPlayer().getPlayerId()))
                .count();
        ParticipantStatus myRequest = all.stream()
                .filter(p -> p.getPlayer() != null && p.getPlayer().getPlayerId().equals(me.getPlayerId()))
                .map(TournamentParticipant::getStatus)
                .findFirst().orElse(null);
        return new TournamentDetailResponse(
                toSummary(tournament, me, organizer, accepted, myRequest),
                all.stream()
                        // Requests are the organizers' business; everyone else sees who's playing
                        .filter(p -> organizer || p.getStatus() == ParticipantStatus.ACCEPTED)
                        .map(p -> new TournamentParticipantResponse(
                                p.getId(),
                                formatService.summary(p),
                                p.getStatus(),
                                p.getPlacement(),
                                p.getCreatedAt(),
                                p.getSlotNo()))
                        .toList(),
                tournament.getResultNotes(),
                tournament.hasFormat() ? formatService.toResponse(tournament, acceptedOthers) : null,
                coOrganizers.stream().map(c -> connectionMapper.toPlayerSummary(c.getPlayer())).toList()
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

    // An organizer (returns null) or an accepted participant (returns their row) may read the chat
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
        if (tournament.getStatus() == TournamentStatus.IN_PROGRESS) {
            throw new BadRequestException("This tournament has already started");
        }
        if (tournament.getStatus() != TournamentStatus.OPEN) {
            throw new BadRequestException("This tournament is over");
        }
    }

    private void requireOrganizer(Tournament tournament, Player me) {
        if (!isOrganizer(tournament, me)) {
            throw new BadRequestException("Only an organizer can do that");
        }
    }

    private static void requireOwner(Tournament tournament, Player me, String message) {
        if (!isOwner(tournament, me)) {
            throw new BadRequestException(message);
        }
    }

    // Accepted players to tell about something an organizer did, leaving out that organizer if they're playing
    private List<Long> playersExcept(Tournament tournament, Player actor) {
        return participantRepository.findAcceptedPlayerIds(tournament).stream()
                .filter(id -> !id.equals(actor.getPlayerId()))
                .toList();
    }

    // The creator first, then co-organizers
    private List<Long> organizerIds(Tournament tournament) {
        List<Long> ids = new ArrayList<>();
        ids.add(tournament.getOrganizer().getPlayerId());
        ids.addAll(coOrganizerRepository.findPlayerIds(tournament));
        return ids;
    }

    private long acceptedNonOrganizers(Tournament tournament) {
        Set<Long> organizers = new HashSet<>(organizerIds(tournament));
        return participantRepository.findAcceptedPlayerIds(tournament).stream()
                .filter(id -> !organizers.contains(id))
                .count();
    }

    // The creator or a co-organizer
    private boolean isOrganizer(Tournament tournament, Player player) {
        return isOwner(tournament, player) || coOrganizerRepository.existsByTournamentAndPlayer(tournament, player);
    }

    // For lists: [coOrganized] holds the ids of tournaments the player co-organizes
    private static boolean isOrganizer(Tournament tournament, Player player, Set<Long> coOrganized) {
        return isOwner(tournament, player) || coOrganized.contains(tournament.getId());
    }

    private static boolean isOwner(Tournament tournament, Player player) {
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

    private Tournament findFormatTournament(Long tournamentId) {
        Tournament tournament = findTournament(tournamentId);
        if (!tournament.hasFormat()) {
            throw new BadRequestException("This tournament has no stages or fixtures");
        }
        return tournament;
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
