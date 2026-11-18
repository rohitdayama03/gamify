package com.example.gamify.service;

import com.example.gamify.dto.*;
import com.example.gamify.entity.Game;
import com.example.gamify.entity.Player;
import com.example.gamify.entity.TournamentStatus;

import java.util.List;

public interface TournamentService {
    List<TournamentSummaryResponse> getOpenTournaments(String username, Game game);
    List<TournamentSummaryResponse> getMyTournaments(String username);
    List<TournamentSummaryResponse> searchTournaments(String username, String text, Game game, TournamentStatus status,
                                                      TournamentSearchSort sort, int page, int size);
    TournamentDetailResponse createTournament(String username, CreateTournamentRequest request);
    TournamentDetailResponse getTournament(String username, Long tournamentId);
    void deleteTournament(String username, Long tournamentId);

    TournamentDetailResponse requestToJoin(String username, Long tournamentId);
    TournamentDetailResponse withdraw(String username, Long tournamentId);
    List<TournamentRequestResponse> getPendingRequests(String username);
    TournamentDetailResponse acceptRequest(String username, Long requestId);
    TournamentDetailResponse rejectRequest(String username, Long requestId);

    TournamentDetailResponse recordResult(String username, Long tournamentId, RecordResultRequest request);

    // Tournaments with a format (stages and fixtures)
    TournamentDetailResponse updateFormat(String username, Long tournamentId, TournamentFormatRequest request);
    TournamentDetailResponse startTournament(String username, Long tournamentId, StartTournamentRequest request);
    TournamentFixturesResponse getFixtures(String username, Long tournamentId);
    TournamentFixturesResponse recordMatchResult(String username, Long tournamentId, Long matchId, MatchResultRequest request);
    TournamentDetailResponse finishStage(String username, Long tournamentId, Long stageId, FinishStageRequest request);
    TournamentLeaderboardResponse getLeaderboard(String username, Long tournamentId);

    List<TournamentChatResponse> getChats(String username);
    List<TournamentMessageResponse> getMessages(String username, Long tournamentId, Long afterId, Long beforeId);
    TournamentMessageResponse sendMessage(String username, Long tournamentId, String content);

    List<PlayerTournamentResponse> getPlayerTournaments(Long playerId);

    /** Deletes the tournaments a player organizes and their join requests, before their account is deleted. */
    void removePlayerFromAllTournaments(Player player);
}
