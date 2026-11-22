package com.example.gamify.service;

import com.example.gamify.dto.*;
import com.example.gamify.entity.*;
import com.example.gamify.exception.BadRequestException;
import com.example.gamify.exception.ResourceNotFoundException;
import com.example.gamify.mapper.ConnectionMapper;
import com.example.gamify.notification.PushNotification;
import com.example.gamify.repository.*;
import com.example.gamify.tournament.*;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Tournaments with a format: stages, fixtures, results and standings. {@link TournamentServiceImpl} checks who
 * is asking (organizer or not) and calls in here inside its transaction.
 * <p>
 * Flow: the format's fixtures are generated up front with placeholders. {@link #start} draws the players into
 * slots and fills the first stage. Results can be entered in any order within the current stage; a knockout
 * winner is moved into the next match straight away. {@link #finish} closes the current stage once every
 * result is in: it fills the next stage from the tables, or, after the last stage, sets everyone's placement
 * and completes the tournament.
 */
@Service
@RequiredArgsConstructor
public class TournamentFormatService {

    private static final String DELETED_PLAYER = "Deleted player";

    private final TournamentStageRepository stageRepository;
    private final TournamentStatRepository statRepository;
    private final TournamentMatchRepository matchRepository;
    private final TournamentMatchStatRepository matchStatRepository;
    private final TournamentParticipantRepository participantRepository;
    private final ConnectionMapper connectionMapper;
    private final ApplicationEventPublisher events;

    // ---- Format ----

    /** Replaces the format and regenerates the fixtures. The caller checks the format may still change. */
    public void saveFormat(Tournament tournament, TournamentFormatRequest request) {
        if (tournament.getGame() != Game.EFOOTBALL) {
            throw new BadRequestException("Stages and fixtures are only available for eFootball tournaments for now");
        }
        List<StageSpec> specs = request.stages().stream()
                .map(s -> new StageSpec(
                        s.type(),
                        orDefault(s.groupCount(), 1),
                        orDefault(s.rounds(), 1),
                        orDefault(s.advancePerGroup(), 0),
                        Boolean.TRUE.equals(s.thirdPlace())))
                .toList();
        List<PlannedStage> plan = FormatPlanner.plan(request.slots(), specs);
        List<TournamentFormatRequest.Stat> stats = checkStats(request.stats());
        Standings.Points points = checkPoints(request.points());

        deleteFormat(tournament);
        tournament.setSlots(request.slots());
        tournament.setMaxParticipants(request.slots());
        tournament.setWinPoints(points.win());
        tournament.setDrawPoints(points.draw());
        tournament.setLossPoints(points.loss());

        for (int i = 0; i < plan.size(); i++) {
            PlannedStage planned = plan.get(i);
            StageSpec spec = planned.spec();
            TournamentStage stage = stageRepository.save(TournamentStage.builder()
                    .tournament(tournament)
                    .seq(i + 1)
                    .type(spec.type())
                    .entrants(planned.entrants())
                    .groupCount(spec.groupCount())
                    .rounds(spec.rounds())
                    .advancePerGroup(spec.advancePerGroup())
                    .thirdPlace(spec.thirdPlace())
                    .build());
            matchRepository.saveAll(planned.matches().stream()
                    .map(m -> TournamentMatch.builder()
                            .stage(stage)
                            .groupNo(m.groupNo())
                            .roundNo(m.roundNo())
                            .matchNo(m.matchNo())
                            .homeSource(m.homeSource())
                            .awaySource(m.awaySource())
                            .build())
                    .toList());
        }
        for (int i = 0; i < stats.size(); i++) {
            statRepository.save(TournamentStat.builder()
                    .tournament(tournament)
                    .label(stats.get(i).label().trim())
                    .aggregation(stats.get(i).aggregation())
                    .seq(i + 1)
                    .build());
        }
    }

    // A win must be worth more than a loss, with a draw in between (or equal to either)
    private static Standings.Points checkPoints(TournamentFormatRequest.Points requested) {
        if (requested == null) {
            return Standings.Points.DEFAULT;
        }
        if (requested.win() <= requested.loss()) {
            throw new BadRequestException("A win must be worth more points than a loss");
        }
        if (requested.draw() > requested.win() || requested.draw() < requested.loss()) {
            throw new BadRequestException("A draw must be worth between a loss and a win");
        }
        return new Standings.Points(requested.win(), requested.draw(), requested.loss());
    }

    private static TournamentFormatResponse.Points toPointsResponse(Tournament tournament) {
        Standings.Points points = tournament.points();
        return new TournamentFormatResponse.Points(points.win(), points.draw(), points.loss());
    }

    public void deleteFormat(Tournament tournament) {
        matchStatRepository.deleteAllByTournament(tournament);
        matchRepository.deleteAllByTournament(tournament);
        statRepository.deleteAllByTournament(tournament);
        stageRepository.deleteAllByTournament(tournament);
    }

    public TournamentFormatResponse toResponse(Tournament tournament, long acceptedCount) {
        List<TournamentStage> stages = stageRepository.findAllByTournamentOrderBySeqAsc(tournament);
        Map<Long, List<TournamentMatch>> matches = matchesByStage(tournament);
        TournamentStage current = currentStage(tournament, stages);
        return new TournamentFormatResponse(
                tournament.getSlots(),
                stages.stream()
                        .map(s -> {
                            List<TournamentMatch> list = matches.getOrDefault(s.getId(), List.of());
                            return new TournamentFormatResponse.Stage(
                                    s.getId(), s.getSeq(), s.getType(), s.getEntrants(), s.getGroupCount(), s.getRounds(),
                                    s.getAdvancePerGroup(), s.isThirdPlace(), s.isFinished(),
                                    list.size(), (int) list.stream().filter(TournamentMatch::hasResult).count());
                        })
                        .toList(),
                toStatResponses(statRepository.findAllByTournamentOrderBySeqAsc(tournament)),
                current == null ? null : current.getId(),
                tournament.getStatus() == TournamentStatus.OPEN && acceptedCount == 0,
                toPointsResponse(tournament)
        );
    }

    // ---- Start ----

    /** Draws the accepted players into slots, closes registration and fills the first stage's fixtures. */
    public void start(Tournament tournament, StartTournamentRequest request, Player actor) {
        if (!tournament.hasFormat()) {
            throw new BadRequestException("This tournament has no stages to start");
        }
        if (tournament.getStatus() != TournamentStatus.OPEN) {
            throw new BadRequestException("This tournament has already started");
        }
        List<TournamentParticipant> all = participantRepository.findAllByTournament(tournament);
        List<TournamentParticipant> accepted = all.stream().filter(p -> p.getStatus() == ParticipantStatus.ACCEPTED).toList();
        int missing = tournament.getSlots() - accepted.size();
        if (missing > 0) {
            throw new BadRequestException("Waiting for " + missing + " more player" + (missing == 1 ? "" : "s"));
        }

        List<TournamentParticipant> order;
        if (request.seeding() == StartTournamentRequest.Seeding.RANDOM) {
            order = new ArrayList<>(accepted);
            Collections.shuffle(order);
        } else {
            Map<Long, TournamentParticipant> byId = accepted.stream()
                    .collect(Collectors.toMap(TournamentParticipant::getId, Function.identity()));
            List<Long> ids = request.order() == null ? List.of() : request.order();
            if (ids.size() != byId.size() || !byId.keySet().equals(new HashSet<>(ids))) {
                throw new BadRequestException("Put every player in a slot exactly once");
            }
            order = ids.stream().map(byId::get).toList();
        }

        Map<String, TournamentParticipant> slots = new HashMap<>();
        for (int i = 0; i < order.size(); i++) {
            order.get(i).setSlotNo(i + 1);
            slots.put(Sources.slot(i + 1), order.get(i));
        }
        TournamentStage first = stageRepository.findAllByTournamentOrderBySeqAsc(tournament).get(0);
        fill(matchesByStage(tournament).getOrDefault(first.getId(), List.of()), slots);

        // Registration is closed: turn down whoever is still waiting
        OffsetDateTime now = OffsetDateTime.now();
        for (TournamentParticipant p : all) {
            if (p.getStatus() == ParticipantStatus.PENDING) {
                p.setStatus(ParticipantStatus.REJECTED);
                p.setRespondedAt(now);
                notify(p, "Registration closed", tournament.getName() + " started before your request was accepted", tournament, actor);
            }
        }
        tournament.setStatus(TournamentStatus.IN_PROGRESS);
        tournament.setStartedAt(now);
        for (TournamentParticipant p : accepted) {
            notify(p, tournament.getName() + " has started", "The draw is done. See your fixtures.", tournament, actor);
        }
    }

    // ---- Results ----

    public void recordMatch(Tournament tournament, Long matchId, MatchResultRequest request, Player actor) {
        requireInProgress(tournament);
        TournamentMatch match = matchRepository.findById(matchId)
                .filter(m -> m.getStage().getTournament().getId().equals(tournament.getId()))
                .orElseThrow(() -> new ResourceNotFoundException("Match not found with ID: " + matchId));
        TournamentStage stage = match.getStage();
        TournamentStage current = currentStage(tournament, stageRepository.findAllByTournamentOrderBySeqAsc(tournament));
        if (!stage.getId().equals(current.getId())) {
            throw new BadRequestException(stage.isFinished()
                    ? "Stage " + stage.getSeq() + " is finished, so its results are locked"
                    : "Stage " + stage.getSeq() + " hasn't begun yet");
        }
        if (!match.isReady()) {
            throw new BadRequestException("The players for this match aren't decided yet");
        }
        boolean knockout = stage.getType() == StageType.KNOCKOUT;
        List<TournamentMatch> dependents = knockout
                ? matchesByStage(tournament).getOrDefault(stage.getId(), List.of()).stream()
                        .filter(other -> Sources.feedsFrom(other.getHomeSource(), match.getRoundNo(), match.getMatchNo())
                                || Sources.feedsFrom(other.getAwaySource(), match.getRoundNo(), match.getMatchNo()))
                        .toList()
                : List.of();
        if (dependents.stream().anyMatch(TournamentMatch::hasResult)) {
            throw new BadRequestException("The next match already has a result, so this one is locked");
        }

        int home = request.homeScore();
        int away = request.awayScore();
        Integer homePens = null;
        Integer awayPens = null;
        TournamentParticipant winner;
        if (request.winner() != null) {
            MatchResultRequest.Winner picked = request.winner();
            if (picked == MatchResultRequest.Winner.DRAW) {
                if (knockout) {
                    throw new BadRequestException("A knockout match needs a winner");
                }
                if (home != away) {
                    throw new BadRequestException("A draw needs a level final score");
                }
                winner = null;
            } else {
                boolean homeWon = picked == MatchResultRequest.Winner.HOME;
                winner = homeWon ? match.getHome() : match.getAway();
                if (home != away) {
                    if ((home > away) != homeWon) {
                        throw new BadRequestException("The final score has " + name(home > away ? match.getHome() : match.getAway()) + " winning");
                    }
                } else if (!knockout) {
                    throw new BadRequestException("The final score is level, so pick Draw");
                } else if (request.homePens() != null && request.awayPens() != null
                        && !request.homePens().equals(request.awayPens())) {
                    // The shootout score is optional, but when it's given it must agree with the winner
                    if ((request.homePens() > request.awayPens()) != homeWon) {
                        throw new BadRequestException("The penalty shootout has " + name(request.homePens() > request.awayPens() ? match.getHome() : match.getAway()) + " winning");
                    }
                    homePens = request.homePens();
                    awayPens = request.awayPens();
                }
            }
        } else if (home != away) {
            winner = home > away ? match.getHome() : match.getAway();
        } else if (knockout) {
            if (request.homePens() == null || request.awayPens() == null) {
                throw new BadRequestException("It's level, so enter the penalty shootout score");
            }
            if (request.homePens().equals(request.awayPens())) {
                throw new BadRequestException("A penalty shootout can't end level");
            }
            homePens = request.homePens();
            awayPens = request.awayPens();
            winner = homePens > awayPens ? match.getHome() : match.getAway();
        } else {
            winner = null;
        }
        match.setHomeScore(home);
        match.setAwayScore(away);
        match.setHomePens(homePens);
        match.setAwayPens(awayPens);
        match.setWinner(winner);
        match.setResultAt(OffsetDateTime.now());
        saveStats(tournament, match, request.stats());

        if (knockout) {
            TournamentParticipant loser = winner == match.getHome() ? match.getAway() : match.getHome();
            for (TournamentMatch next : dependents) {
                if (Sources.feedsFrom(next.getHomeSource(), match.getRoundNo(), match.getMatchNo())) {
                    next.setHome(Sources.isLoser(next.getHomeSource()) ? loser : winner);
                }
                if (Sources.feedsFrom(next.getAwaySource(), match.getRoundNo(), match.getMatchNo())) {
                    next.setAway(Sources.isLoser(next.getAwaySource()) ? loser : winner);
                }
            }
        }

        String score = name(match.getHome()) + " " + home + "–" + away + " " + name(match.getAway())
                + (homePens != null ? " (" + homePens + "–" + awayPens + " pens)"
                : knockout && home == away ? " (" + name(winner) + " won on pens)" : "");
        notify(match.getHome(), tournament.getName(), score, tournament, actor);
        notify(match.getAway(), tournament.getName(), score, tournament, actor);
    }

    private void saveStats(Tournament tournament, TournamentMatch match, List<MatchResultRequest.StatValue> values) {
        matchStatRepository.deleteAllByMatch(match);
        if (values == null || values.isEmpty()) {
            return;
        }
        Map<Long, TournamentStat> stats = statRepository.findAllByTournamentOrderBySeqAsc(tournament).stream()
                .collect(Collectors.toMap(TournamentStat::getId, Function.identity()));
        Set<Long> seen = new HashSet<>();
        for (MatchResultRequest.StatValue value : values) {
            TournamentStat stat = stats.get(value.statId());
            if (stat == null || !seen.add(value.statId())) {
                throw new BadRequestException("Unknown or repeated stat");
            }
            if (value.home() != null) {
                matchStatRepository.save(TournamentMatchStat.builder().match(match).participant(match.getHome()).stat(stat).value(value.home()).build());
            }
            if (value.away() != null) {
                matchStatRepository.save(TournamentMatchStat.builder().match(match).participant(match.getAway()).stat(stat).value(value.away()).build());
            }
        }
    }

    // ---- Finishing a stage ----

    public void finish(Tournament tournament, Long stageId, FinishStageRequest request, Player actor) {
        requireInProgress(tournament);
        List<TournamentStage> stages = stageRepository.findAllByTournamentOrderBySeqAsc(tournament);
        TournamentStage stage = stages.stream().filter(s -> s.getId().equals(stageId)).findFirst()
                .orElseThrow(() -> new ResourceNotFoundException("Stage not found with ID: " + stageId));
        TournamentStage current = currentStage(tournament, stages);
        if (!stage.getId().equals(current.getId())) {
            throw new BadRequestException(stage.isFinished()
                    ? "Stage " + stage.getSeq() + " is already finished"
                    : "Finish stage " + current.getSeq() + " first");
        }
        Map<Long, List<TournamentMatch>> byStage = matchesByStage(tournament);
        List<TournamentMatch> matches = byStage.getOrDefault(stage.getId(), List.of());
        long missing = matches.stream().filter(m -> !m.hasResult()).count();
        if (missing > 0) {
            throw new BadRequestException(missing + " match" + (missing == 1 ? " still needs a result" : "es still need a result"));
        }
        boolean last = stage.getSeq() == stages.size();

        if (stage.getType() == StageType.LEAGUE) {
            Map<Integer, List<Long>> overrides = new HashMap<>();
            if (request != null && request.groupOrders() != null) {
                for (FinishStageRequest.GroupOrder order : request.groupOrders()) {
                    overrides.put(order.groupNo(), order.participantIds());
                }
            }
            Map<Long, TournamentParticipant> participants = new HashMap<>();
            Map<Integer, List<Long>> finalOrder = new TreeMap<>();
            groupMatches(matches).forEach((groupNo, groupMatches) -> {
                List<TournamentParticipant> members = members(groupMatches);
                members.forEach(p -> participants.put(p.getId(), p));
                List<Standings.Row> rows = Standings.rank(members.stream().map(TournamentParticipant::getId).toList(), results(groupMatches), tournament.points());
                finalOrder.put(groupNo, applyOverride(stage, groupNo, rows, overrides.get(groupNo)));
            });

            if (last) {
                List<Long> order = finalOrder.values().iterator().next();
                for (int i = 0; i < order.size(); i++) {
                    participants.get(order.get(i)).setPlacement(i + 1);
                }
            } else {
                int advance = stage.getAdvancePerGroup();
                Map<String, TournamentParticipant> through = new HashMap<>();
                // How many players finished at each rank across the groups, to place those going out
                Map<Integer, Integer> atRank = new HashMap<>();
                finalOrder.forEach((groupNo, order) -> {
                    for (int i = 0; i < order.size(); i++) {
                        atRank.merge(i + 1, 1, Integer::sum);
                        if (i < advance) {
                            through.put(Sources.group(groupNo, i + 1), participants.get(order.get(i)));
                        }
                    }
                });
                // Going out at rank r: behind everyone still in, and everyone going out at a better rank
                int remaining = through.size();
                finalOrder.forEach((groupNo, order) -> {
                    for (int i = advance; i < order.size(); i++) {
                        int ahead = remaining;
                        for (int r = advance + 1; r <= i; r++) {
                            ahead += atRank.getOrDefault(r, 0);
                        }
                        participants.get(order.get(i)).setPlacement(ahead + 1);
                    }
                });
                TournamentStage next = stages.get(stage.getSeq());
                fill(byStage.getOrDefault(next.getId(), List.of()), through);
            }
        } else {
            int rounds = Integer.numberOfTrailingZeros(stage.getEntrants());
            for (TournamentMatch m : matches) {
                TournamentParticipant loser = m.getWinner() == m.getHome() ? m.getAway() : m.getHome();
                boolean thirdPlaceMatch = m.getRoundNo() == rounds && m.getMatchNo() == 2;
                if (thirdPlaceMatch) {
                    m.getWinner().setPlacement(3);
                    loser.setPlacement(4);
                } else if (m.getRoundNo() == rounds) {
                    m.getWinner().setPlacement(1);
                    loser.setPlacement(2);
                } else if (!(stage.isThirdPlace() && m.getRoundNo() == rounds - 1)) {
                    // Out in a round of N matches: joint (N + 1)th, e.g. quarter-final losers are 5th
                    loser.setPlacement((stage.getEntrants() >> m.getRoundNo()) + 1);
                }
            }
        }

        stage.setFinishedAt(OffsetDateTime.now());
        List<TournamentParticipant> accepted = participantRepository.findAllByTournament(tournament).stream()
                .filter(p -> p.getStatus() == ParticipantStatus.ACCEPTED)
                .toList();
        if (last) {
            tournament.setStatus(TournamentStatus.COMPLETED);
            tournament.setCompletedAt(OffsetDateTime.now());
            String champion = accepted.stream().filter(p -> Integer.valueOf(1).equals(p.getPlacement()))
                    .findFirst().map(this::name).orElse("The champion");
            for (TournamentParticipant p : accepted) {
                notify(p, "Results are in", champion + " won " + tournament.getName(), tournament, actor);
            }
        } else {
            for (TournamentParticipant p : accepted) {
                notify(p, tournament.getName(), "Stage " + stage.getSeq() + " is finished. See who goes through.", tournament, actor);
            }
        }
    }

    // The group's final order: the table's, or the organizer's where only level players swap places
    private static List<Long> applyOverride(TournamentStage stage, int groupNo, List<Standings.Row> rows, List<Long> override) {
        List<Long> computed = rows.stream().map(Standings.Row::participantId).toList();
        if (override == null) {
            return computed;
        }
        String group = stage.getGroupCount() > 1 ? "group " + Sources.groupLetter(groupNo) : "the table";
        if (override.size() != computed.size() || !new HashSet<>(override).equals(new HashSet<>(computed))) {
            throw new BadRequestException("The order for " + group + " must list each of its players once");
        }
        Map<Long, Integer> blockOf = rows.stream().collect(Collectors.toMap(Standings.Row::participantId, Standings.Row::tieBlock));
        for (int i = 0; i < override.size(); i++) {
            if (blockOf.get(override.get(i)) != rows.get(i).tieBlock()) {
                throw new BadRequestException("In " + group + ", only players level on every tiebreaker can swap places");
            }
        }
        return override;
    }

    // ---- Fixtures ----

    public TournamentFixturesResponse fixtures(Tournament tournament, boolean organizer) {
        List<TournamentStage> stages = stageRepository.findAllByTournamentOrderBySeqAsc(tournament);
        Map<Long, List<TournamentMatch>> byStage = matchesByStage(tournament);
        Map<Long, Map<Long, List<TournamentFixturesResponse.StatValue>>> values = statValuesByMatch(tournament);
        TournamentStage current = currentStage(tournament, stages);

        List<TournamentFixturesResponse.Stage> result = new ArrayList<>();
        for (TournamentStage stage : stages) {
            int previousGroups = stage.getSeq() > 1 ? stages.get(stage.getSeq() - 2).getGroupCount() : 1;
            boolean isCurrent = current != null && current.getId().equals(stage.getId());
            List<TournamentMatch> matches = byStage.getOrDefault(stage.getId(), List.of());
            Set<String> locked = lockedKnockoutMatches(stage, matches);
            int rounds = Integer.numberOfTrailingZeros(stage.getEntrants());
            result.add(new TournamentFixturesResponse.Stage(
                    stage.getId(), stage.getSeq(), stage.getType(), stage.isFinished(), isCurrent,
                    matches.stream().map(m -> {
                        boolean knockout = stage.getType() == StageType.KNOCKOUT;
                        String roundName = !knockout ? "Round " + m.getRoundNo()
                                : m.getRoundNo() == rounds && m.getMatchNo() == 2 ? "Third place"
                                : Sources.roundName(stage.getEntrants(), m.getRoundNo());
                        Map<Long, List<TournamentFixturesResponse.StatValue>> matchValues = values.getOrDefault(m.getId(), Map.of());
                        return new TournamentFixturesResponse.Match(
                                m.getId(),
                                m.getGroupNo(),
                                m.getGroupNo() != null && stage.getGroupCount() > 1 ? "Group " + Sources.groupLetter(m.getGroupNo()) : null,
                                m.getRoundNo(),
                                roundName,
                                m.getMatchNo(),
                                side(m.getHomeSource(), m.getHome(), m.getHomeScore(), matchValues, previousGroups, stage.getEntrants()),
                                side(m.getAwaySource(), m.getAway(), m.getAwayScore(), matchValues, previousGroups, stage.getEntrants()),
                                m.getHomePens(),
                                m.getAwayPens(),
                                m.getWinner() == null ? null : m.getWinner().getId(),
                                m.hasResult(),
                                organizer && isCurrent && m.isReady() && !locked.contains(m.getRoundNo() + ":" + m.getMatchNo()));
                    }).toList()));
        }
        return new TournamentFixturesResponse(result);
    }

    private TournamentFixturesResponse.Side side(String source, TournamentParticipant participant, Integer score,
                                                 Map<Long, List<TournamentFixturesResponse.StatValue>> values,
                                                 int previousGroups, int entrants) {
        return new TournamentFixturesResponse.Side(
                Sources.label(source, previousGroups, entrants),
                participant == null ? null : participant.getId(),
                participant == null ? null : summary(participant),
                score,
                participant == null ? List.of() : values.getOrDefault(participant.getId(), List.of()));
    }

    // "round:match" of knockout matches whose next match already has a result
    private static Set<String> lockedKnockoutMatches(TournamentStage stage, List<TournamentMatch> matches) {
        Set<String> locked = new HashSet<>();
        if (stage.getType() != StageType.KNOCKOUT) {
            return locked;
        }
        for (TournamentMatch m : matches) {
            if (m.hasResult()) {
                for (String source : List.of(m.getHomeSource(), m.getAwaySource())) {
                    String[] parts = source.split(":");
                    if (parts[0].equals("WINNER") || parts[0].equals("LOSER")) {
                        locked.add(parts[1] + ":" + parts[2]);
                    }
                }
            }
        }
        return locked;
    }

    // ---- Leaderboard ----

    public TournamentLeaderboardResponse leaderboard(Tournament tournament) {
        List<TournamentStage> stages = stageRepository.findAllByTournamentOrderBySeqAsc(tournament);
        List<TournamentStat> stats = statRepository.findAllByTournamentOrderBySeqAsc(tournament);
        Map<Long, List<TournamentMatch>> byStage = matchesByStage(tournament);
        List<TournamentMatch> allMatches = byStage.values().stream().flatMap(List::stream).toList();
        List<TournamentParticipant> players = participantRepository.findAllByTournament(tournament).stream()
                .filter(p -> p.getStatus() == ParticipantStatus.ACCEPTED)
                .sorted(Comparator.comparing(TournamentParticipant::getSlotNo, Comparator.nullsLast(Comparator.naturalOrder())))
                .toList();
        Map<Long, TournamentParticipant> byId = players.stream().collect(Collectors.toMap(TournamentParticipant::getId, Function.identity()));

        // Each player's stat totals or averages, in column order
        Map<Long, Map<Long, List<Double>>> raw = new HashMap<>();
        for (TournamentMatchStat v : matchStatRepository.findAllByTournament(tournament)) {
            raw.computeIfAbsent(v.getParticipant().getId(), k -> new HashMap<>())
                    .computeIfAbsent(v.getStat().getId(), k -> new ArrayList<>())
                    .add(v.getValue());
        }
        List<TournamentLeaderboardResponse.Row> overall = Standings.rank(
                        players.stream().map(TournamentParticipant::getId).toList(), results(allMatches), tournament.points()).stream()
                .map(row -> {
                    TournamentParticipant p = byId.get(row.participantId());
                    Map<Long, List<Double>> mine = raw.getOrDefault(p.getId(), Map.of());
                    List<TournamentFixturesResponse.StatValue> totals = stats.stream()
                            .filter(s -> mine.containsKey(s.getId()))
                            .map(s -> new TournamentFixturesResponse.StatValue(s.getId(), aggregate(s, mine.get(s.getId()))))
                            .toList();
                    return new TournamentLeaderboardResponse.Row(p.getId(), summary(p), p.getPlacement(), record(row), totals);
                })
                .toList();

        List<TournamentLeaderboardResponse.StageTable> tables = new ArrayList<>();
        for (TournamentStage stage : stages) {
            if (stage.getType() != StageType.LEAGUE) {
                continue;
            }
            boolean last = stage.getSeq() == stages.size();
            Set<Long> wentThrough = new HashSet<>();
            if (stage.isFinished() && !last) {
                for (TournamentMatch m : byStage.getOrDefault(stages.get(stage.getSeq()).getId(), List.of())) {
                    if (m.getHome() != null) wentThrough.add(m.getHome().getId());
                    if (m.getAway() != null) wentThrough.add(m.getAway().getId());
                }
            }
            List<TournamentLeaderboardResponse.Group> groups = new ArrayList<>();
            groupMatches(byStage.getOrDefault(stage.getId(), List.of())).forEach((groupNo, groupMatches) -> {
                List<TournamentParticipant> members = members(groupMatches);
                if (members.isEmpty()) {
                    return; // The stage hasn't begun
                }
                List<Standings.Row> rows = new ArrayList<>(Standings.rank(members.stream().map(TournamentParticipant::getId).toList(), results(groupMatches), tournament.points()));
                if (stage.isFinished()) {
                    // Level players in the order the organizer settled: whoever went through, then by placement
                    rows.sort(Comparator.<Standings.Row>comparingInt(Standings.Row::tieBlock)
                            .thenComparing(r -> !wentThrough.contains(r.participantId()))
                            .thenComparing(r -> byId.get(r.participantId()).getPlacement(), Comparator.nullsLast(Comparator.naturalOrder())));
                }
                List<TournamentLeaderboardResponse.StandingRow> standingRows = new ArrayList<>();
                for (int i = 0; i < rows.size(); i++) {
                    Standings.Row row = rows.get(i);
                    boolean qualified = stage.isFinished() ? wentThrough.contains(row.participantId()) : !last && i < stage.getAdvancePerGroup();
                    standingRows.add(new TournamentLeaderboardResponse.StandingRow(
                            row.participantId(), summary(byId.get(row.participantId())), record(row), Standings.isTied(rows, i), row.tieBlock(), qualified));
                }
                groups.add(new TournamentLeaderboardResponse.Group(
                        groupNo,
                        stage.getGroupCount() > 1 ? "Group " + Sources.groupLetter(groupNo) : "Table",
                        last ? 0 : stage.getAdvancePerGroup(),
                        standingRows));
            });
            tables.add(new TournamentLeaderboardResponse.StageTable(stage.getId(), stage.getSeq(), stage.isFinished(), groups));
        }
        return new TournamentLeaderboardResponse(toPointsResponse(tournament), toStatResponses(stats), overall, tables);
    }

    private static double aggregate(TournamentStat stat, List<Double> values) {
        double sum = values.stream().mapToDouble(Double::doubleValue).sum();
        double value = stat.getAggregation() == StatAggregation.AVG ? sum / values.size() : sum;
        return Math.round(value * 10) / 10.0;
    }

    private static TournamentLeaderboardResponse.Record record(Standings.Row row) {
        return new TournamentLeaderboardResponse.Record(row.played(), row.won(), row.drawn(), row.lost(),
                row.goalsFor(), row.goalsAgainst(), row.goalDifference(), row.points());
    }

    // ---- Players ----

    /** The player's summary, or a stand-in for someone who has deleted their account. */
    public PlayerSummaryResponse summary(TournamentParticipant participant) {
        if (participant.getPlayer() != null) {
            return connectionMapper.toPlayerSummary(participant.getPlayer());
        }
        return new PlayerSummaryResponse(null, name(participant), null, null, null, null);
    }

    private String name(TournamentParticipant participant) {
        if (participant.getPlayer() != null) {
            return participant.getPlayer().getUsername();
        }
        return participant.getFormerUsername() != null ? participant.getFormerUsername() : DELETED_PLAYER;
    }

    // ---- Helpers ----

    /** The first unfinished stage while the tournament is in progress, otherwise null. */
    private static TournamentStage currentStage(Tournament tournament, List<TournamentStage> stages) {
        if (tournament.getStatus() != TournamentStatus.IN_PROGRESS) {
            return null;
        }
        return stages.stream().filter(s -> !s.isFinished()).findFirst().orElse(null);
    }

    private Map<Long, List<TournamentMatch>> matchesByStage(Tournament tournament) {
        return matchRepository.findAllByTournament(tournament).stream()
                .collect(Collectors.groupingBy(m -> m.getStage().getId(), LinkedHashMap::new, Collectors.toList()));
    }

    private Map<Long, Map<Long, List<TournamentFixturesResponse.StatValue>>> statValuesByMatch(Tournament tournament) {
        Map<Long, Map<Long, List<TournamentFixturesResponse.StatValue>>> values = new HashMap<>();
        List<TournamentMatchStat> all = new ArrayList<>(matchStatRepository.findAllByTournament(tournament));
        all.sort(Comparator.comparingInt(v -> v.getStat().getSeq()));
        for (TournamentMatchStat v : all) {
            values.computeIfAbsent(v.getMatch().getId(), k -> new HashMap<>())
                    .computeIfAbsent(v.getParticipant().getId(), k -> new ArrayList<>())
                    .add(new TournamentFixturesResponse.StatValue(v.getStat().getId(), v.getValue()));
        }
        return values;
    }

    private static Map<Integer, List<TournamentMatch>> groupMatches(List<TournamentMatch> matches) {
        return matches.stream().collect(Collectors.groupingBy(
                m -> m.getGroupNo() == null ? 1 : m.getGroupNo(), TreeMap::new, Collectors.toList()));
    }

    // A group's players, by slot
    private static List<TournamentParticipant> members(List<TournamentMatch> matches) {
        Map<Long, TournamentParticipant> members = new LinkedHashMap<>();
        for (TournamentMatch m : matches) {
            if (m.getHome() != null) members.putIfAbsent(m.getHome().getId(), m.getHome());
            if (m.getAway() != null) members.putIfAbsent(m.getAway().getId(), m.getAway());
        }
        return members.values().stream()
                .sorted(Comparator.comparing(TournamentParticipant::getSlotNo, Comparator.nullsLast(Comparator.naturalOrder())))
                .toList();
    }

    private static List<Standings.Result> results(List<TournamentMatch> matches) {
        return matches.stream()
                .filter(TournamentMatch::hasResult)
                .map(m -> new Standings.Result(m.getHome().getId(), m.getAway().getId(), m.getHomeScore(), m.getAwayScore()))
                .toList();
    }

    private static void fill(List<TournamentMatch> matches, Map<String, TournamentParticipant> players) {
        for (TournamentMatch m : matches) {
            TournamentParticipant home = players.get(m.getHomeSource());
            TournamentParticipant away = players.get(m.getAwaySource());
            if (home != null) m.setHome(home);
            if (away != null) m.setAway(away);
        }
    }

    private static List<TournamentFormatRequest.Stat> checkStats(List<TournamentFormatRequest.Stat> stats) {
        if (stats == null) {
            return List.of();
        }
        Set<String> seen = new HashSet<>();
        for (TournamentFormatRequest.Stat stat : stats) {
            String key = stat.label().trim().toLowerCase();
            if (key.equals("goals")) {
                throw new BadRequestException("Goals come from the score, so there's no need to add them as a stat");
            }
            if (!seen.add(key)) {
                throw new BadRequestException("Each stat needs a different name");
            }
        }
        return stats;
    }

    private static List<TournamentFormatResponse.Stat> toStatResponses(List<TournamentStat> stats) {
        return stats.stream().map(s -> new TournamentFormatResponse.Stat(s.getId(), s.getLabel(), s.getAggregation())).toList();
    }

    private static void requireInProgress(Tournament tournament) {
        if (tournament.getStatus() == TournamentStatus.OPEN) {
            throw new BadRequestException("Start the tournament first");
        }
        if (tournament.getStatus() == TournamentStatus.COMPLETED) {
            throw new BadRequestException("This tournament is over");
        }
    }

    private static int orDefault(Integer value, int fallback) {
        return value == null ? fallback : value;
    }

    // [actor] is the organizer who caused this update: a player who is that organizer doesn't need telling
    private void notify(TournamentParticipant participant, String title, String body, Tournament tournament, Player actor) {
        if (participant == null || participant.getPlayer() == null
                || participant.getPlayer().getPlayerId().equals(actor.getPlayerId())) {
            return;
        }
        events.publishEvent(new PushNotification(
                participant.getPlayer().getPlayerId(),
                title,
                body,
                PushNotification.CHANNEL_REQUESTS,
                "tournament_update-" + tournament.getId(),
                Map.of("type", "tournament_update", "tournamentId", String.valueOf(tournament.getId()), "tournamentName", tournament.getName())
        ));
    }
}
