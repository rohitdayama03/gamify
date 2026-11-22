import 'connection_model.dart';

/// League: everyone in a group plays everyone. Knockout: lose once and you're out.
enum StageType {
  league('LEAGUE', 'League'),
  knockout('KNOCKOUT', 'Knockout');

  final String apiValue;
  final String label;
  const StageType(this.apiValue, this.label);

  static StageType fromApi(String? value) => value == 'KNOCKOUT' ? knockout : league;
}

/// How a stat adds up on the leaderboard: a running total, or an average (e.g. possession).
enum StatAggregation {
  sum('SUM'),
  avg('AVG');

  final String apiValue;
  const StatAggregation(this.apiValue);

  static StatAggregation fromApi(String? value) => value == 'AVG' ? avg : sum;
}

// ---- Designing a format ----

/// A stage being designed. League fields are ignored for a knockout and vice versa.
class StageDraft {
  StageType type;
  int groupCount;
  // 1 = everyone meets once, 2 = home and away
  int rounds;
  int advancePerGroup;
  bool thirdPlace;

  StageDraft({
    required this.type,
    this.groupCount = 1,
    this.rounds = 1,
    this.advancePerGroup = 2,
    this.thirdPlace = false,
  });

  StageDraft copy() => StageDraft(
        type: type,
        groupCount: groupCount,
        rounds: rounds,
        advancePerGroup: advancePerGroup,
        thirdPlace: thirdPlace,
      );

  Map<String, dynamic> toJson() => {
        'type': type.apiValue,
        'groupCount': groupCount,
        'rounds': rounds,
        'advancePerGroup': advancePerGroup,
        'thirdPlace': thirdPlace,
      };
}

class StatDraft {
  final String label;
  final StatAggregation aggregation;

  const StatDraft(this.label, this.aggregation);

  Map<String, dynamic> toJson() => {'label': label, 'aggregation': aggregation.apiValue};
}

/// Stats organizers can tick for eFootball. Goals come from the score.
const List<StatDraft> efootballStatPresets = [
  StatDraft('Shots', StatAggregation.sum),
  StatDraft('Shots on target', StatAggregation.sum),
  StatDraft('Possession %', StatAggregation.avg),
  StatDraft('Passes', StatAggregation.sum),
  StatDraft('Fouls', StatAggregation.sum),
  StatDraft('Yellow cards', StatAggregation.sum),
  StatDraft('Red cards', StatAggregation.sum),
];

/// What one stage works out to, or why it doesn't work.
class StageCheck {
  final int entrants;
  final int matches;
  final String? problem;

  const StageCheck({required this.entrants, required this.matches, this.problem});
}

/// Ready-made formats the organizer can start from.
enum FormatTemplate {
  knockout('Knockout'),
  league('League'),
  groupsKnockout('Groups + Knockout'),
  leaguePlayoffs('League + Playoffs');

  final String label;
  const FormatTemplate(this.label);
}

/// What a league or group match is worth: points for a win, a draw and a loss (a loss may cost points).
class FormatPoints {
  static const int min = -10;
  static const int max = 10;
  static const standard = FormatPoints(win: 3, draw: 1, loss: 0);
  // How tournaments were scored before points could be chosen; an older server sends no points
  static const legacy = FormatPoints(win: 2, draw: 1, loss: 0);

  final int win;
  final int draw;
  final int loss;

  const FormatPoints({required this.win, required this.draw, required this.loss});

  factory FormatPoints.fromJson(Map<String, dynamic>? json) =>
      json == null ? legacy : FormatPoints(win: json['win'], draw: json['draw'], loss: json['loss']);

  Map<String, dynamic> toJson() => {'win': win, 'draw': draw, 'loss': loss};

  FormatPoints copyWith({int? win, int? draw, int? loss}) =>
      FormatPoints(win: win ?? this.win, draw: draw ?? this.draw, loss: loss ?? this.loss);

  bool get isStandard => win == standard.win && draw == standard.draw && loss == standard.loss;

  // The server makes the same checks
  String? get problem {
    if (win <= loss) return 'A win must be worth more points than a loss';
    if (draw > win || draw < loss) return 'A draw must be worth between a loss and a win';
    return null;
  }

  static String _pts(int value) => '$value ${value == 1 || value == -1 ? 'pt' : 'pts'}';

  /// "Win 3 pts · Draw 1 pt · Loss 0 pts"
  String get summary => 'Win ${_pts(win)} · Draw ${_pts(draw)} · Loss ${_pts(loss)}';
}

class FormatDraft {
  static const int minSlots = 2;
  static const int maxSlots = 64;
  static const int maxStages = 4;
  static const int maxStats = 8;
  static const int maxMatches = 1000;

  int slots;
  List<StageDraft> stages;
  List<StatDraft> stats;
  FormatPoints points;

  FormatDraft({required this.slots, required this.stages, required this.stats, this.points = FormatPoints.standard});

  // Points only matter for league and group stages
  bool get hasLeague => stages.any((s) => s.type == StageType.league);

  factory FormatDraft.initial() => FormatDraft.fromTemplate(FormatTemplate.groupsKnockout, 16, stats: const [
        StatDraft('Shots', StatAggregation.sum),
        StatDraft('Possession %', StatAggregation.avg),
      ]);

  /// [template] shaped for [slots] players, as close to valid as it can be.
  factory FormatDraft.fromTemplate(FormatTemplate template, int slots, {List<StatDraft> stats = const []}) {
    final stages = switch (template) {
      FormatTemplate.knockout => [StageDraft(type: StageType.knockout, thirdPlace: slots >= 4)],
      FormatTemplate.league => [StageDraft(type: StageType.league)],
      FormatTemplate.groupsKnockout => [
          StageDraft(type: StageType.league, groupCount: (slots ~/ 4).clamp(1, 16), advancePerGroup: 2),
          // A third-place match needs semi-finals, i.e. at least 4 players in the knockout
          StageDraft(type: StageType.knockout, thirdPlace: (slots ~/ 4).clamp(1, 16) * 2 >= 4),
        ],
      FormatTemplate.leaguePlayoffs => [
          StageDraft(type: StageType.league, advancePerGroup: slots >= 8 ? 4 : 2),
          StageDraft(type: StageType.knockout),
        ],
    };
    return FormatDraft(slots: slots, stages: stages, stats: List.of(stats));
  }

  factory FormatDraft.fromFormat(TournamentFormat format) => FormatDraft(
        slots: format.slots,
        stages: [
          for (final s in format.stages)
            StageDraft(
              type: s.type,
              groupCount: s.groupCount,
              rounds: s.rounds,
              advancePerGroup: s.advancePerGroup == 0 ? 2 : s.advancePerGroup,
              thirdPlace: s.thirdPlace,
            ),
        ],
        stats: [for (final s in format.stats) StatDraft(s.label, s.aggregation)],
        points: format.points,
      );

  FormatDraft copy() =>
      FormatDraft(slots: slots, stages: stages.map((s) => s.copy()).toList(), stats: List.of(stats), points: points);

  Map<String, dynamic> toJson() => {
        'slots': slots,
        'stages': stages.map((s) => s.toJson()).toList(),
        'stats': stats.map((s) => s.toJson()).toList(),
        'points': points.toJson(),
      };

  /// The same checks the server makes, so the builder can explain problems as they happen.
  List<StageCheck> check() {
    final checks = <StageCheck>[];
    var entrants = slots;
    for (var i = 0; i < stages.length; i++) {
      final stage = stages[i];
      final last = i == stages.length - 1;
      final number = i + 1;
      if (stage.type == StageType.league) {
        final groups = stage.groupCount;
        String? problem;
        var next = 0;
        if (groups < 1 || entrants ~/ groups < 2) {
          problem = '$entrants players is too few for $groups groups of at least 2';
        } else if (last && groups != 1) {
          problem = 'The last stage needs a single group so there\'s one winner';
        } else if (!last) {
          final smallest = entrants ~/ groups;
          if (stage.advancePerGroup < 1 || stage.advancePerGroup >= smallest) {
            problem = 'Between 1 and ${smallest - 1} players per group can go through';
          } else if (groups * stage.advancePerGroup < 2) {
            problem = 'At least 2 players must go through to stage ${number + 1}';
          }
          next = groups * stage.advancePerGroup;
        }
        var matches = 0;
        if (groups >= 1) {
          for (var g = 0; g < groups; g++) {
            final size = entrants ~/ groups + (g < entrants % groups ? 1 : 0);
            matches += size * (size - 1) ~/ 2 * stage.rounds;
          }
        }
        checks.add(StageCheck(entrants: entrants, matches: matches, problem: problem));
        entrants = next;
      } else {
        String? problem;
        if (!last) {
          problem = 'A knockout has to be the last stage';
        } else if (entrants < 2 || (entrants & (entrants - 1)) != 0) {
          problem = 'A knockout needs 2, 4, 8, 16, 32 or 64 players, not $entrants';
        } else if (stage.thirdPlace && entrants < 4) {
          problem = 'A third-place match needs at least 4 players';
        }
        final matches = entrants >= 2 ? entrants - 1 + (stage.thirdPlace && entrants >= 4 ? 1 : 0) : 0;
        checks.add(StageCheck(entrants: entrants, matches: matches, problem: problem));
        entrants = 0;
      }
    }
    return checks;
  }

  /// The first thing stopping this format from being saved, or null.
  String? get problem {
    if (slots < minSlots || slots > maxSlots) return 'Pick between $minSlots and $maxSlots players';
    if (stages.isEmpty) return 'Add at least one stage';
    final checks = check();
    for (var i = 0; i < checks.length; i++) {
      if (checks[i].problem != null) return 'Stage ${i + 1}: ${checks[i].problem}';
    }
    final total = checks.fold(0, (sum, c) => sum + c.matches);
    if (total > maxMatches) return 'This format has $total matches; keep it to $maxMatches or fewer';
    if (hasLeague) return points.problem;
    return null;
  }

  int get totalMatches => check().fold(0, (sum, c) => sum + c.matches);
}

// ---- A tournament's format, as saved ----

class FormatStage {
  final int id;
  final int seq;
  final StageType type;
  final int entrants;
  final int groupCount;
  final int rounds;
  final int advancePerGroup;
  final bool thirdPlace;
  final bool finished;
  final int matchCount;
  final int completedCount;

  FormatStage({
    required this.id,
    required this.seq,
    required this.type,
    required this.entrants,
    required this.groupCount,
    required this.rounds,
    required this.advancePerGroup,
    required this.thirdPlace,
    required this.finished,
    required this.matchCount,
    required this.completedCount,
  });

  /// e.g. "4 groups · top 2 go through" or "Knockout · third-place match".
  String get summary {
    if (type == StageType.knockout) return thirdPlace ? 'Knockout · third-place match' : 'Knockout';
    final groups = groupCount == 1 ? 'League' : '$groupCount groups';
    final legs = rounds == 2 ? ' · home & away' : '';
    final through = advancePerGroup > 0 ? ' · top $advancePerGroup go through' : '';
    return '$groups$legs$through';
  }

  factory FormatStage.fromJson(Map<String, dynamic> json) => FormatStage(
        id: json['id'],
        seq: json['seq'],
        type: StageType.fromApi(json['type']),
        entrants: json['entrants'] ?? 0,
        groupCount: json['groupCount'] ?? 1,
        rounds: json['rounds'] ?? 1,
        advancePerGroup: json['advancePerGroup'] ?? 0,
        thirdPlace: json['thirdPlace'] ?? false,
        finished: json['finished'] ?? false,
        matchCount: json['matchCount'] ?? 0,
        completedCount: json['completedCount'] ?? 0,
      );
}

class FormatStat {
  final int id;
  final String label;
  final StatAggregation aggregation;

  FormatStat({required this.id, required this.label, required this.aggregation});

  factory FormatStat.fromJson(Map<String, dynamic> json) =>
      FormatStat(id: json['id'], label: json['label'], aggregation: StatAggregation.fromApi(json['aggregation']));
}

class TournamentFormat {
  final int slots;
  final List<FormatStage> stages;
  final List<FormatStat> stats;
  // The stage results are being entered for; null before the start and after the end
  final int? currentStageId;
  // The organizer may still change it (nobody accepted yet)
  final bool editable;
  final FormatPoints points;

  TournamentFormat({
    required this.slots,
    required this.stages,
    required this.stats,
    this.currentStageId,
    required this.editable,
    this.points = FormatPoints.legacy,
  });

  bool get hasLeague => stages.any((s) => s.type == StageType.league);

  FormatStage? get currentStage {
    for (final s in stages) {
      if (s.id == currentStageId) return s;
    }
    return null;
  }

  factory TournamentFormat.fromJson(Map<String, dynamic> json) => TournamentFormat(
        slots: json['slots'],
        stages: ((json['stages'] ?? []) as List).map((e) => FormatStage.fromJson(e)).toList(),
        stats: ((json['stats'] ?? []) as List).map((e) => FormatStat.fromJson(e)).toList(),
        currentStageId: json['currentStageId'],
        editable: json['editable'] ?? false,
        points: FormatPoints.fromJson(json['points']),
      );
}

// ---- Fixtures ----

class StatValue {
  final int statId;
  final double value;

  StatValue({required this.statId, required this.value});

  factory StatValue.fromJson(Map<String, dynamic> json) =>
      StatValue(statId: json['statId'], value: (json['value'] as num).toDouble());
}

/// One side of a fixture. [player] is null until it's decided; [placeholder] says where they come from.
class MatchSide {
  final String placeholder;
  final int? participantId;
  final PlayerSummary? player;
  final int? score;
  final List<StatValue> stats;

  MatchSide({required this.placeholder, this.participantId, this.player, this.score, required this.stats});

  String get name => player?.username ?? placeholder;

  double? statValue(int statId) {
    for (final s in stats) {
      if (s.statId == statId) return s.value;
    }
    return null;
  }

  factory MatchSide.fromJson(Map<String, dynamic> json) => MatchSide(
        placeholder: json['placeholder'] ?? '',
        participantId: json['participantId'],
        player: json['player'] == null ? null : PlayerSummary.fromJson(json['player']),
        score: json['score'],
        stats: ((json['stats'] ?? []) as List).map((e) => StatValue.fromJson(e)).toList(),
      );
}

class TournamentMatch {
  final int id;
  final int? groupNo;
  final String? groupName;
  final int roundNo;
  final String roundName;
  final int matchNo;
  final MatchSide home;
  final MatchSide away;
  final int? homePens;
  final int? awayPens;
  final int? winnerId;
  final bool completed;
  // The organizer can enter or correct the result now
  final bool editable;

  TournamentMatch({
    required this.id,
    this.groupNo,
    this.groupName,
    required this.roundNo,
    required this.roundName,
    required this.matchNo,
    required this.home,
    required this.away,
    this.homePens,
    this.awayPens,
    this.winnerId,
    required this.completed,
    required this.editable,
  });

  bool get isReady => home.participantId != null && away.participantId != null;

  factory TournamentMatch.fromJson(Map<String, dynamic> json) => TournamentMatch(
        id: json['id'],
        groupNo: json['groupNo'],
        groupName: json['groupName'],
        roundNo: json['roundNo'],
        roundName: json['roundName'] ?? '',
        matchNo: json['matchNo'],
        home: MatchSide.fromJson(json['home']),
        away: MatchSide.fromJson(json['away']),
        homePens: json['homePens'],
        awayPens: json['awayPens'],
        winnerId: json['winnerId'],
        completed: json['completed'] ?? false,
        editable: json['editable'] ?? false,
      );
}

class StageFixtures {
  final int stageId;
  final int seq;
  final StageType type;
  final bool finished;
  final bool current;
  final List<TournamentMatch> matches;

  StageFixtures({
    required this.stageId,
    required this.seq,
    required this.type,
    required this.finished,
    required this.current,
    required this.matches,
  });

  factory StageFixtures.fromJson(Map<String, dynamic> json) => StageFixtures(
        stageId: json['stageId'],
        seq: json['seq'],
        type: StageType.fromApi(json['type']),
        finished: json['finished'] ?? false,
        current: json['current'] ?? false,
        matches: ((json['matches'] ?? []) as List).map((e) => TournamentMatch.fromJson(e)).toList(),
      );
}

class TournamentFixtures {
  final List<StageFixtures> stages;

  TournamentFixtures({required this.stages});

  factory TournamentFixtures.fromJson(Map<String, dynamic> json) =>
      TournamentFixtures(stages: ((json['stages'] ?? []) as List).map((e) => StageFixtures.fromJson(e)).toList());
}

// ---- Standings and leaderboard ----

class TeamRecord {
  final int played, won, drawn, lost, goalsFor, goalsAgainst, goalDifference, points;

  TeamRecord({
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
  });

  factory TeamRecord.fromJson(Map<String, dynamic> json) => TeamRecord(
        played: json['played'] ?? 0,
        won: json['won'] ?? 0,
        drawn: json['drawn'] ?? 0,
        lost: json['lost'] ?? 0,
        goalsFor: json['goalsFor'] ?? 0,
        goalsAgainst: json['goalsAgainst'] ?? 0,
        goalDifference: json['goalDifference'] ?? 0,
        points: json['points'] ?? 0,
      );
}

class LeaderboardRow {
  final int participantId;
  final PlayerSummary player;
  final int? placement;
  final TeamRecord record;
  final List<StatValue> stats;

  LeaderboardRow({required this.participantId, required this.player, this.placement, required this.record, required this.stats});

  double? statValue(int statId) {
    for (final s in stats) {
      if (s.statId == statId) return s.value;
    }
    return null;
  }

  factory LeaderboardRow.fromJson(Map<String, dynamic> json) => LeaderboardRow(
        participantId: json['participantId'],
        player: PlayerSummary.fromJson(json['player']),
        placement: json['placement'],
        record: TeamRecord.fromJson(json['record']),
        stats: ((json['stats'] ?? []) as List).map((e) => StatValue.fromJson(e)).toList(),
      );
}

class StandingRow {
  final int participantId;
  final PlayerSummary player;
  final TeamRecord record;
  // Level with a neighbour on every tiebreaker; rows with the same tieBlock may swap places
  final bool tied;
  final int tieBlock;
  final bool qualified;

  StandingRow({
    required this.participantId,
    required this.player,
    required this.record,
    required this.tied,
    required this.tieBlock,
    required this.qualified,
  });

  factory StandingRow.fromJson(Map<String, dynamic> json) => StandingRow(
        participantId: json['participantId'],
        player: PlayerSummary.fromJson(json['player']),
        record: TeamRecord.fromJson(json['record']),
        tied: json['tied'] ?? false,
        tieBlock: json['tieBlock'] ?? 0,
        qualified: json['qualified'] ?? false,
      );
}

class GroupTable {
  final int groupNo;
  final String name;
  final int advancing;
  final List<StandingRow> rows;

  GroupTable({required this.groupNo, required this.name, required this.advancing, required this.rows});

  factory GroupTable.fromJson(Map<String, dynamic> json) => GroupTable(
        groupNo: json['groupNo'],
        name: json['name'] ?? '',
        advancing: json['advancing'] ?? 0,
        rows: ((json['rows'] ?? []) as List).map((e) => StandingRow.fromJson(e)).toList(),
      );
}

class StageTable {
  final int stageId;
  final int seq;
  final bool finished;
  // Empty until the stage has begun
  final List<GroupTable> groups;

  StageTable({required this.stageId, required this.seq, required this.finished, required this.groups});

  factory StageTable.fromJson(Map<String, dynamic> json) => StageTable(
        stageId: json['stageId'],
        seq: json['seq'],
        finished: json['finished'] ?? false,
        groups: ((json['groups'] ?? []) as List).map((e) => GroupTable.fromJson(e)).toList(),
      );
}

class TournamentLeaderboard {
  final FormatPoints points;
  final List<FormatStat> stats;
  final List<LeaderboardRow> overall;
  final List<StageTable> stages;

  TournamentLeaderboard({this.points = FormatPoints.legacy, required this.stats, required this.overall, required this.stages});

  factory TournamentLeaderboard.fromJson(Map<String, dynamic> json) => TournamentLeaderboard(
        points: FormatPoints.fromJson(json['points']),
        stats: ((json['stats'] ?? []) as List).map((e) => FormatStat.fromJson(e)).toList(),
        overall: ((json['overall'] ?? []) as List).map((e) => LeaderboardRow.fromJson(e)).toList(),
        stages: ((json['stages'] ?? []) as List).map((e) => StageTable.fromJson(e)).toList(),
      );
}

/// "2" or "53.3": whole numbers without the decimal.
String formatStatValue(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
