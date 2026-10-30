package com.example.gamify.service;

import com.example.gamify.dto.*;

public interface PlayerService {
    PlayerResponse getProfileByUsername(String username);
    PlayerResponse getProfileById(Long playerId);
    PlayerResponse updateProfile(String username, UpdatePlayerRequest request);
    void deleteAccount(String username);

    /** Step 1 of a new profile picture: a signed link to upload it straight to S3. */
    UploadSessionResponse startAvatarUpload(String username, AvatarUploadRequest request);
    /** Step 2, once it's uploaded: checks the file and makes it their picture, deleting the old one. */
    PlayerResponse setAvatar(String username, String key);
    /** Back to showing their initial. */
    PlayerResponse removeAvatar(String username);

    GtaProfileResponse upsertGtaProfile(String username, GtaProfileRequest request);

    void deleteGtaProfile(String username);

    BgmiProfileResponse upsertBgmiProfile(String username, BgmiProfileRequest request);
    void deleteBgmiProfile(String username);

    EfootballProfileResponse upsertEfootballProfile(String username, EfootballProfileRequest request);
    void deleteEfootballProfile(String username);
}