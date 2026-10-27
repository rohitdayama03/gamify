package com.example.gamify.service;

import com.example.gamify.dto.*;
import com.example.gamify.entity.BgmiProfile;
import com.example.gamify.entity.EfootballProfile;
import com.example.gamify.entity.Game;
import com.example.gamify.entity.GtaProfile;
import com.example.gamify.entity.Player;
import com.example.gamify.exception.ResourceNotFoundException;
import com.example.gamify.mapper.PlayerMapper;
import com.example.gamify.repository.BgmiProfileRepository;
import com.example.gamify.repository.ChatMessageRepository;
import com.example.gamify.repository.EfootballProfileRepository;
import com.example.gamify.repository.GtaProfileRepository;
import com.example.gamify.repository.PlayerConnectionRepository;
import com.example.gamify.repository.PlayerRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PlayerServiceImpl implements PlayerService {

    private final PlayerRepository playerRepository;
    private final GtaProfileRepository gtaProfileRepository;
    private final BgmiProfileRepository bgmiProfileRepository;
    private final EfootballProfileRepository efootballProfileRepository;
    private final PlayerConnectionRepository connectionRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final PlayerMapper playerMapper;

    @Override
    @Transactional(readOnly = true)
    public PlayerResponse getProfileByUsername(String username) {
        Player player = playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));
        return playerMapper.toOwnPlayerResponse(player);
    }

    @Override
    @Transactional(readOnly = true)
    public PlayerResponse getProfileById(Long playerId) {
        Player player = playerRepository.findById(playerId)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with ID: " + playerId));
        return playerMapper.toPlayerResponse(player);
    }

    @Override
    @Transactional
    public PlayerResponse updateProfile(String username, UpdatePlayerRequest request) {
        Player player = playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));

        if (request.playerBio() != null) player.setPlayerBio(request.playerBio());
        if (request.language() != null) player.setLanguage(request.language());
        if (request.country() != null) player.setCountry(request.country());
        if (request.interestedGames() != null) player.setInterestedGames(Game.join(request.interestedGames()));
        if (request.lastGame() != null) player.setLastGame(request.lastGame());

        Player updatedPlayer = playerRepository.save(player);
        return playerMapper.toOwnPlayerResponse(updatedPlayer);
    }

    @Override
    @Transactional
    public void deleteAccount(String username) {
        Player player = playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));
        // Invites and messages reference the player by foreign key, so remove them first
        chatMessageRepository.deleteAllInvolving(player);
        connectionRepository.deleteAllInvolving(player);
        playerRepository.delete(player);
    }

    // --- GTA Online Profile Operations ---

    @Override
    @Transactional
    public GtaProfileResponse upsertGtaProfile(String username, GtaProfileRequest request) {
        Player player = playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));

        GtaProfile gtaProfile = gtaProfileRepository.findByPlayer(player)
                .orElseGet(() -> GtaProfile.builder().player(player).build());

        gtaProfile.setCharacterName(request.characterName().trim());
        gtaProfile.setPlatform(request.platform());
        gtaProfile.setActivities(PlayerMapper.joinList(request.activities()));
        gtaProfile.setRank(request.rank());

        GtaProfile savedProfile = gtaProfileRepository.save(gtaProfile);
        return playerMapper.toGtaProfileResponse(savedProfile);
    }

    @Override
    @Transactional
    public void deleteGtaProfile(String username) {
        Player player = playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));
        // Clearing the reference lets orphanRemoval delete the row; deleting through the
        // repository alone is undone at flush because Player still cascades to the profile
        player.setGtaProfile(null);
    }

    // --- BGMI Profile Operations ---

    @Override
    @Transactional
    public BgmiProfileResponse upsertBgmiProfile(String username, BgmiProfileRequest request) {
        Player player = playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));

        BgmiProfile bgmiProfile = bgmiProfileRepository.findByPlayer(player)
                .orElseGet(() -> BgmiProfile.builder().player(player).build());

        bgmiProfile.setBgmiId(request.bgmiId());
        bgmiProfile.setCurrentRole(request.currentRole());
        bgmiProfile.setExperience(request.experience());
        bgmiProfile.setAvailableTime(request.availableTime());
        bgmiProfile.setAchievements(request.achievements());
        bgmiProfile.setLookingFor(request.lookingFor());

        BgmiProfile savedProfile = bgmiProfileRepository.save(bgmiProfile);
        return playerMapper.toBgmiProfileResponse(savedProfile);
    }

    @Override
    @Transactional
    public void deleteBgmiProfile(String username) {
        Player player = playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));
        // Clearing the reference lets orphanRemoval delete the row; deleting through the
        // repository alone is undone at flush because Player still cascades to the profile
        player.setBgmiProfile(null);
    }

    // --- E-Football Profile Operations ---

    @Override
    @Transactional
    public EfootballProfileResponse upsertEfootballProfile(String username, EfootballProfileRequest request) {
        Player player = playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));

        EfootballProfile efootballProfile = efootballProfileRepository.findByPlayer(player)
                .orElseGet(() -> EfootballProfile.builder().player(player).build());

        efootballProfile.setEfootballId(request.efootballId());
        efootballProfile.setHighTier(request.highTier());

        EfootballProfile savedProfile = efootballProfileRepository.save(efootballProfile);
        return playerMapper.toEfootballProfileResponse(savedProfile);
    }

    @Override
    @Transactional
    public void deleteEfootballProfile(String username) {
        Player player = playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));
        // Clearing the reference lets orphanRemoval delete the row; deleting through the
        // repository alone is undone at flush because Player still cascades to the profile
        player.setEfootballProfile(null);
    }
}