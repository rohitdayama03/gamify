package com.example.gamify.service;

import com.example.gamify.dto.*;
import com.example.gamify.entity.Player;
import com.example.gamify.entity.Squad;
import com.example.gamify.entity.SquadMember;
import com.example.gamify.entity.SquadMemberStatus;
import com.example.gamify.entity.SquadMessage;
import com.example.gamify.exception.BadRequestException;
import com.example.gamify.exception.ResourceNotFoundException;
import com.example.gamify.mapper.SquadMapper;
import com.example.gamify.notification.PushNotification;
import com.example.gamify.repository.PlayerConnectionRepository;
import com.example.gamify.repository.PlayerRepository;
import com.example.gamify.repository.SquadMemberRepository;
import com.example.gamify.repository.SquadMessageRepository;
import com.example.gamify.repository.SquadRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class SquadServiceImpl implements SquadService {

    // Joined members plus pending invites
    private static final int MAX_MEMBERS = 50;

    private static final int PAGE_SIZE = 50;

    // Longest message text shown in a notification
    private static final int PREVIEW_LENGTH = 150;

    private final PlayerRepository playerRepository;
    private final PlayerConnectionRepository connectionRepository;
    private final SquadRepository squadRepository;
    private final SquadMemberRepository memberRepository;
    private final SquadMessageRepository messageRepository;
    private final SquadMapper squadMapper;
    private final ApplicationEventPublisher events;

    @Override
    @Transactional(readOnly = true)
    public List<SquadSummaryResponse> getMySquads(String username) {
        Player me = findPlayer(username);
        List<SquadMember> memberships = memberRepository.findAllByPlayerAndStatus(me, SquadMemberStatus.JOINED);
        if (memberships.isEmpty()) {
            return List.of();
        }

        Set<Long> squadIds = memberships.stream().map(m -> m.getSquad().getId()).collect(Collectors.toSet());
        Map<Long, Long> memberCounts = toCountMap(memberRepository.countJoinedBySquadIds(squadIds));
        Map<Long, Long> unread = toCountMap(messageRepository.countUnreadBySquad(me));
        Map<Long, SquadMessage> lastMessages = messageRepository.findLastMessages(squadIds).stream()
                .collect(Collectors.toMap(m -> m.getSquad().getId(), m -> m));

        return memberships.stream()
                .map(membership -> {
                    Squad squad = membership.getSquad();
                    SquadMessage last = lastMessages.get(squad.getId());
                    return new SquadSummaryResponse(
                            squad.getId(),
                            squad.getName(),
                            squad.getOwner().getPlayerId(),
                            memberCounts.getOrDefault(squad.getId(), 0L),
                            last == null ? null : squadMapper.toMessageResponse(last, me),
                            unread.getOrDefault(squad.getId(), 0L),
                            membership.getJoinedAt()
                    );
                })
                .toList();
    }

    @Override
    @Transactional
    public SquadDetailResponse createSquad(String username, CreateSquadRequest request) {
        Player me = findPlayer(username);
        // Collapse runs of spaces so "Night  Owls" and "Night Owls" count as the same name
        String name = request.name().trim().replaceAll("\\s+", " ");
        String nameKey = name.toLowerCase(Locale.ROOT);
        if (name.length() < 3) {
            throw new BadRequestException("Squad name must be 3 to 30 characters");
        }
        if (squadRepository.existsByNameKey(nameKey)) {
            throw new BadRequestException("A squad called \"" + name + "\" already exists. Pick another name.");
        }

        Squad squad;
        try {
            squad = squadRepository.saveAndFlush(Squad.builder().name(name).nameKey(nameKey).owner(me).build());
        } catch (DataIntegrityViolationException e) {
            // Someone else took the name between the check and the insert
            throw new BadRequestException("A squad called \"" + name + "\" already exists. Pick another name.");
        }
        memberRepository.save(SquadMember.builder()
                .squad(squad)
                .player(me)
                .status(SquadMemberStatus.JOINED)
                .joinedAt(OffsetDateTime.now())
                .lastReadMessageId(0L)
                .build());

        List<Long> memberIds = request.memberIds() == null ? List.of() : request.memberIds();
        if (!memberIds.isEmpty()) {
            inviteFriends(me, squad, memberIds);
        }
        return toDetail(squad, me);
    }

    @Override
    @Transactional(readOnly = true)
    public SquadDetailResponse getSquad(String username, Long squadId) {
        Player me = findPlayer(username);
        Squad squad = findJoinedSquad(me, squadId).getSquad();
        return toDetail(squad, me);
    }

    // Any member can invite their own friends
    @Override
    @Transactional
    public SquadDetailResponse invite(String username, Long squadId, List<Long> playerIds) {
        Player me = findPlayer(username);
        Squad squad = findJoinedSquad(me, squadId).getSquad();
        inviteFriends(me, squad, playerIds);
        return toDetail(squad, me);
    }

    // Owner only: removes a member or withdraws a pending invite
    @Override
    @Transactional
    public SquadDetailResponse removeMember(String username, Long squadId, Long playerId) {
        Player me = findPlayer(username);
        Squad squad = findJoinedSquad(me, squadId).getSquad();
        if (!isOwner(squad, me)) {
            throw new BadRequestException("Only the squad owner can remove members");
        }
        if (me.getPlayerId().equals(playerId)) {
            throw new BadRequestException("Use Leave squad to leave your own squad");
        }
        Player other = playerRepository.findById(playerId)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with ID: " + playerId));
        SquadMember member = memberRepository.findBySquadAndPlayer(squad, other)
                .orElseThrow(() -> new ResourceNotFoundException(other.getUsername() + " is not in this squad"));
        memberRepository.delete(member);
        return toDetail(squad, me);
    }

    @Override
    @Transactional
    public void leave(String username, Long squadId) {
        Player me = findPlayer(username);
        leaveSquad(findJoinedSquad(me, squadId));
    }

    @Override
    @Transactional(readOnly = true)
    public List<SquadInviteResponse> getMyInvites(String username) {
        Player me = findPlayer(username);
        List<SquadMember> invites = memberRepository.findAllByPlayerAndStatus(me, SquadMemberStatus.INVITED);
        if (invites.isEmpty()) {
            return List.of();
        }
        Set<Long> squadIds = invites.stream().map(i -> i.getSquad().getId()).collect(Collectors.toSet());
        Map<Long, Long> memberCounts = toCountMap(memberRepository.countJoinedBySquadIds(squadIds));
        return invites.stream()
                .map(invite -> squadMapper.toInviteResponse(invite, memberCounts.getOrDefault(invite.getSquad().getId(), 0L)))
                .toList();
    }

    @Override
    @Transactional
    public SquadDetailResponse acceptInvite(String username, Long inviteId) {
        Player me = findPlayer(username);
        SquadMember invite = findMyInvite(me, inviteId);
        invite.setStatus(SquadMemberStatus.JOINED);
        invite.setJoinedAt(OffsetDateTime.now());
        // Earlier messages are visible but don't count as unread
        invite.setLastReadMessageId(messageRepository.findLastMessageId(invite.getSquad()));
        memberRepository.save(invite);
        return toDetail(invite.getSquad(), me);
    }

    // The row is deleted, so the player can be invited again later
    @Override
    @Transactional
    public void declineInvite(String username, Long inviteId) {
        Player me = findPlayer(username);
        memberRepository.delete(findMyInvite(me, inviteId));
    }

    @Override
    @Transactional
    public List<SquadMessageResponse> getMessages(String username, Long squadId, Long afterId, Long beforeId) {
        Player me = findPlayer(username);
        SquadMember membership = findJoinedSquad(me, squadId);
        Squad squad = membership.getSquad();

        List<SquadMessage> messages;
        if (afterId != null) {
            messages = messageRepository.findNewer(squad, afterId, PageRequest.of(0, PAGE_SIZE));
        } else {
            // Initial load or "load older": newest-first from the database, flipped to oldest-first
            messages = new ArrayList<>(messageRepository.findOlder(
                    squad, beforeId != null ? beforeId : Long.MAX_VALUE, PageRequest.of(0, PAGE_SIZE)));
            Collections.reverse(messages);
        }

        // Opening the chat means everything sent so far has been read
        Long lastId = messageRepository.findLastMessageId(squad);
        if (membership.getLastReadMessageId() == null || membership.getLastReadMessageId() < lastId) {
            membership.setLastReadMessageId(lastId);
        }

        return messages.stream().map(message -> squadMapper.toMessageResponse(message, me)).toList();
    }

    @Override
    @Transactional
    public SquadMessageResponse sendMessage(String username, Long squadId, String content) {
        Player me = findPlayer(username);
        SquadMember membership = findJoinedSquad(me, squadId);
        Squad squad = membership.getSquad();

        SquadMessage saved = messageRepository.save(SquadMessage.builder()
                .squad(squad)
                .sender(me)
                .content(content.trim())
                .build());
        // Your own message is never unread
        membership.setLastReadMessageId(saved.getId());

        // One notification per squad: a newer message replaces the previous one on the phone
        String body = me.getUsername() + ": " + preview(saved.getContent());
        for (Long memberId : memberRepository.findJoinedPlayerIds(squad)) {
            if (memberId.equals(me.getPlayerId())) {
                continue;
            }
            events.publishEvent(new PushNotification(
                    memberId,
                    squad.getName(),
                    body,
                    PushNotification.CHANNEL_MESSAGES,
                    "squad-" + squad.getId(),
                    Map.of("type", "squad_message", "squadId", String.valueOf(squad.getId()), "squadName", squad.getName())
            ));
        }
        return squadMapper.toMessageResponse(saved, me);
    }

    @Override
    @Transactional
    public void removePlayerFromAllSquads(Player player) {
        for (SquadMember membership : memberRepository.findAllByPlayerAndStatus(player, SquadMemberStatus.JOINED)) {
            leaveSquad(membership);
        }
        messageRepository.deleteAllBySender(player);
        memberRepository.clearInvitedBy(player);
        memberRepository.deleteAllByPlayer(player);
    }

    // The owner leaving hands the squad to whoever joined earliest; the last member leaving deletes it
    private void leaveSquad(SquadMember membership) {
        Squad squad = membership.getSquad();
        Player leaving = membership.getPlayer();
        memberRepository.delete(membership);

        if (!isOwner(squad, leaving)) {
            return;
        }
        Optional<SquadMember> successor = memberRepository.findAllBySquad(squad).stream()
                .filter(m -> m.getStatus() == SquadMemberStatus.JOINED && !m.getId().equals(membership.getId()))
                .findFirst();
        if (successor.isPresent()) {
            squad.setOwner(successor.get().getPlayer());
            squadRepository.save(squad);
        } else {
            messageRepository.deleteAllBySquad(squad);
            memberRepository.deleteAllBySquad(squad);
            squadRepository.delete(squad);
        }
    }

    private void inviteFriends(Player me, Squad squad, List<Long> playerIds) {
        Set<Long> uniqueIds = new LinkedHashSet<>(playerIds);
        if (memberRepository.countBySquad(squad) + uniqueIds.size() > MAX_MEMBERS) {
            throw new BadRequestException("A squad can have at most " + MAX_MEMBERS + " members and invites");
        }
        for (Long playerId : uniqueIds) {
            Player friend = playerRepository.findById(playerId)
                    .orElseThrow(() -> new ResourceNotFoundException("Player not found with ID: " + playerId));
            if (friend.getPlayerId().equals(me.getPlayerId())) {
                continue;
            }
            if (!connectionRepository.areFriends(me, friend)) {
                throw new BadRequestException("You can only invite your friends. " + friend.getUsername() + " isn't one yet.");
            }
            Optional<SquadMember> existing = memberRepository.findBySquadAndPlayer(squad, friend);
            if (existing.isPresent()) {
                // Already in or already invited: nothing to do
                continue;
            }
            memberRepository.save(SquadMember.builder()
                    .squad(squad)
                    .player(friend)
                    .status(SquadMemberStatus.INVITED)
                    .invitedBy(me)
                    .build());
            events.publishEvent(new PushNotification(
                    friend.getPlayerId(),
                    "Squad invite",
                    me.getUsername() + " invited you to join " + squad.getName(),
                    PushNotification.CHANNEL_REQUESTS,
                    "squad-invite-" + squad.getId(),
                    Map.of("type", "squad_invite", "squadId", String.valueOf(squad.getId()), "squadName", squad.getName())
            ));
        }
    }

    private SquadDetailResponse toDetail(Squad squad, Player me) {
        return new SquadDetailResponse(
                squad.getId(),
                squad.getName(),
                squad.getOwner().getPlayerId(),
                isOwner(squad, me),
                memberRepository.findAllBySquad(squad).stream().map(squadMapper::toMemberResponse).toList(),
                squad.getCreatedAt()
        );
    }

    private static boolean isOwner(Squad squad, Player player) {
        return squad.getOwner().getPlayerId().equals(player.getPlayerId());
    }

    // Squads the player hasn't joined are hidden behind a 404
    private SquadMember findJoinedSquad(Player me, Long squadId) {
        return squadRepository.findById(squadId)
                .flatMap(squad -> memberRepository.findBySquadAndPlayer(squad, me))
                .filter(m -> m.getStatus() == SquadMemberStatus.JOINED)
                .orElseThrow(() -> new ResourceNotFoundException("Squad not found with ID: " + squadId));
    }

    private SquadMember findMyInvite(Player me, Long inviteId) {
        return memberRepository.findById(inviteId)
                .filter(m -> m.getPlayer().getPlayerId().equals(me.getPlayerId()) && m.getStatus() == SquadMemberStatus.INVITED)
                .orElseThrow(() -> new ResourceNotFoundException("Squad invite not found with ID: " + inviteId));
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

    private Player findPlayer(String username) {
        return playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));
    }
}
