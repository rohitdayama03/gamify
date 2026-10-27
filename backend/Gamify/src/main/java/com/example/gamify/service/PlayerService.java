package com.example.gamify.service;

import com.example.gamify.dto.*;

public interface PlayerService {
    PlayerResponse getProfileByUsername(String username);
    PlayerResponse getProfileById(Long playerId);
    PlayerResponse updateProfile(String username, UpdatePlayerRequest request);
    void deleteAccount(String username);

    GtaProfileResponse upsertGtaProfile(String username, GtaProfileRequest request);

    void deleteGtaProfile(String username);

    BgmiProfileResponse upsertBgmiProfile(String username, BgmiProfileRequest request);
    void deleteBgmiProfile(String username);

    EfootballProfileResponse upsertEfootballProfile(String username, EfootballProfileRequest request);
    void deleteEfootballProfile(String username);
}