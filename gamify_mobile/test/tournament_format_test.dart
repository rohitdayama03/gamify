import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamify_mobile/models/tournament_format_model.dart';
import 'package:gamify_mobile/screens/tournaments/fixtures_view.dart';
import 'package:gamify_mobile/screens/tournaments/format_builder_screen.dart';
import 'package:gamify_mobile/screens/tournaments/match_result_sheet.dart';
import 'package:gamify_mobile/screens/tournaments/standings_view.dart';
import 'package:google_fonts/google_fonts.dart';

Map<String, dynamic> _player(int id, String name) => {'playerId': id, 'username': name};

Map<String, dynamic> _side(String placeholder, [int? id, String? name, int? score]) => {
      'placeholder': placeholder,
      'participantId': id,
      'player': id == null ? null : _player(id, name!),
      'score': score,
      'stats': score == null ? [] : [
        {'statId': 1, 'value': 5.0},
      ],
    };

// Shaped like the server's answer for 8 players: 2 groups (top 2 through), then semi-finals
final _fixtures = TournamentFixtures.fromJson({
  'stages': [
    {
      'stageId': 1,
      'seq': 1,
      'type': 'LEAGUE',
      'finished': true,
      'current': false,
      'matches': [
        {
          'id': 10, 'groupNo': 1, 'groupName': 'Group A', 'roundNo': 1, 'roundName': 'Round 1', 'matchNo': 1,
          'home': _side('Slot 1', 1, 'a_really_long_username_for_layout', 2), 'away': _side('Slot 5', 5, 'eve', 0),
          'winnerId': 1, 'completed': true, 'editable': false,
        },
      ],
    },
    {
      'stageId': 2,
      'seq': 2,
      'type': 'KNOCKOUT',
      'finished': false,
      'current': true,
      'matches': [
        {
          'id': 20, 'roundNo': 1, 'roundName': 'Semi-final', 'matchNo': 1,
          'home': _side('Group A · 1st', 1, 'a_really_long_username_for_layout', 1), 'away': _side('Group B · 2nd', 4, 'dan', 1),
          'homePens': 4, 'awayPens': 3, 'winnerId': 1, 'completed': true, 'editable': false,
        },
        {
          'id': 21, 'roundNo': 1, 'roundName': 'Semi-final', 'matchNo': 2,
          'home': _side('Group B · 1st', 2, 'bob'), 'away': _side('Group A · 2nd', 3, 'cat'),
          'completed': false, 'editable': true,
        },
        {
          'id': 22, 'roundNo': 2, 'roundName': 'Final', 'matchNo': 1,
          'home': _side('Winner of SF 1', 1, 'a_really_long_username_for_layout'), 'away': _side('Winner of SF 2'),
          'completed': false, 'editable': false,
        },
        {
          'id': 23, 'roundNo': 2, 'roundName': 'Third place', 'matchNo': 2,
          'home': _side('Loser of SF 1', 4, 'dan'), 'away': _side('Loser of SF 2'),
          'completed': false, 'editable': false,
        },
      ],
    },
  ],
});

Map<String, dynamic> _record(int p, int w, int d, int l, int gf, int ga) =>
    {'played': p, 'won': w, 'drawn': d, 'lost': l, 'goalsFor': gf, 'goalsAgainst': ga, 'goalDifference': gf - ga, 'points': w * 2 + d};

final _leaderboard = TournamentLeaderboard.fromJson({
  'stats': [
    {'id': 1, 'label': 'Shots', 'aggregation': 'SUM'},
    {'id': 2, 'label': 'Possession %', 'aggregation': 'AVG'},
  ],
  'overall': [
    {
      'participantId': 1, 'player': _player(1, 'a_really_long_username_for_layout'), 'placement': 1,
      'record': _record(5, 3, 2, 0, 9, 4), 'stats': [{'statId': 1, 'value': 13.0}, {'statId': 2, 'value': 53.3}],
    },
    {'participantId': 2, 'player': _player(0, 'Deleted player'), 'placement': 2, 'record': _record(5, 3, 1, 1, 8, 2), 'stats': []},
  ],
  'stages': [
    {
      'stageId': 1,
      'seq': 1,
      'finished': true,
      'groups': [
        {
          'groupNo': 1, 'name': 'Group A', 'advancing': 2,
          'rows': [
            {'participantId': 1, 'player': _player(1, 'a_really_long_username_for_layout'), 'record': _record(3, 2, 1, 0, 5, 1), 'tied': true, 'tieBlock': 0, 'qualified': true},
            {'participantId': 3, 'player': _player(3, 'cat'), 'record': _record(3, 2, 1, 0, 5, 1), 'tied': true, 'tieBlock': 0, 'qualified': true},
            {'participantId': 5, 'player': _player(5, 'eve'), 'record': _record(3, 1, 0, 2, 2, 4), 'tied': false, 'tieBlock': 2, 'qualified': false},
          ],
        },
      ],
    },
    {'stageId': 3, 'seq': 2, 'finished': false, 'groups': []},
  ],
});

// Phone width; [height] can be raised so a long scrolling page is built in full
Future<void> _pumpPhone(WidgetTester tester, Widget child, {double height = 740}) async {
  tester.view.physicalSize = Size(360, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: child));
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('format checks match the server', () {
    test('16 players in 4 groups, top 2 into a knockout with a third-place match', () {
      final draft = FormatDraft.fromTemplate(FormatTemplate.groupsKnockout, 16);
      expect(draft.problem, isNull);
      final checks = draft.check();
      expect(checks.map((c) => c.entrants), [16, 8]);
      expect(checks.map((c) => c.matches), [24, 8]);
    });

    test('templates work for common sizes', () {
      for (final slots in [4, 8, 16, 32]) {
        for (final template in FormatTemplate.values) {
          expect(FormatDraft.fromTemplate(template, slots).problem, isNull, reason: '${template.label} with $slots players');
        }
      }
    });

    test('explains formats that cannot work', () {
      expect(FormatDraft(slots: 6, stages: [StageDraft(type: StageType.knockout)], stats: []).problem, contains('not 6'));
      expect(
        FormatDraft(slots: 12, stages: [StageDraft(type: StageType.league, groupCount: 3), StageDraft(type: StageType.knockout)], stats: [])
            .problem,
        contains('not 6'),
      );
      expect(FormatDraft(slots: 8, stages: [StageDraft(type: StageType.league, groupCount: 2)], stats: []).problem, contains('single group'));
      expect(
        FormatDraft(slots: 8, stages: [StageDraft(type: StageType.knockout), StageDraft(type: StageType.league)], stats: []).problem,
        contains('last stage'),
      );
      expect(
        FormatDraft(slots: 8, stages: [StageDraft(type: StageType.league, groupCount: 2, advancePerGroup: 4), StageDraft(type: StageType.knockout)], stats: [])
            .problem,
        contains('Between 1 and 3'),
      );
    });

    test('odd group sizes and home-and-away count matches like the server', () {
      final draft = FormatDraft(slots: 10, stages: [StageDraft(type: StageType.league, groupCount: 3, rounds: 2, advancePerGroup: 1), StageDraft(type: StageType.league)], stats: []);
      // Groups of 4, 3, 3: (6 + 3 + 3) x 2 = 24, then 3 players once = 3
      expect(draft.check().map((c) => c.matches), [24, 3]);
      expect(draft.problem, isNull);
    });
  });

  testWidgets('the format builder fits a phone and reacts to changes', (tester) async {
    await _pumpPhone(tester, FormatBuilderScreen(initial: FormatDraft.initial()), height: 2400);
    expect(find.text('STAGE 1'), findsOneWidget);
    expect(find.text('STAGE 2'), findsOneWidget);
    expect(find.textContaining('16 players · 2 stages · 32 matches'), findsOneWidget);

    await tester.tap(find.text('8'));
    await tester.pump();
    expect(find.textContaining('8 players · 2 stages'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'League'));
    await tester.pump();
    expect(find.text('STAGE 2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixtures show a league round and a knockout bracket', (tester) async {
    TournamentMatch? tapped;
    await _pumpPhone(
      tester,
      Scaffold(body: FixturesView(fixtures: _fixtures, onRefresh: () async {}, onEditMatch: (m) => tapped = m)),
    );
    expect(find.text('Group A · Round 1'), findsOneWidget);
    expect(find.text('Semi-final'), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
    expect(find.text('Winner of SF 2'), findsOneWidget);
    expect(find.text('(4)'), findsOneWidget);
    // Only the editable semi-final opens the result sheet
    await tester.tap(find.text('bob'));
    expect(tapped?.id, 21);
    tapped = null;
    await tester.tap(find.text('eve'));
    expect(tapped, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standings and leaderboard render, including a deleted player', (tester) async {
    await _pumpPhone(tester, Scaffold(body: StandingsView(leaderboard: _leaderboard, onRefresh: () async {})));
    expect(find.text('Group A · top 2 go through'), findsOneWidget);
    expect(find.text('='), findsNWidgets(2));
    expect(find.textContaining('fills in once stage 1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpPhone(tester, Scaffold(body: LeaderboardView(leaderboard: _leaderboard, completed: true, onRefresh: () async {})));
    expect(find.text('POSSESSION %'), findsOneWidget);
    expect(find.text('53.3'), findsOneWidget);
    expect(find.text('Deleted player'), findsOneWidget);
    expect(find.text('1st'), findsOneWidget);
    // Sort by shots: the player without a value goes last
    await tester.tap(find.text('SHOTS'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the result sheet asks for penalties only when a knockout match is level', (tester) async {
    final semi = _fixtures.stages[1].matches[1];
    await _pumpPhone(
      tester,
      Scaffold(body: MatchResultSheet(tournamentId: 1, match: semi, knockout: true, stats: _leaderboard.stats)),
    );
    expect(find.text('PENALTY SHOOTOUT'), findsOneWidget); // 0-0
    expect(find.text("A penalty shootout can't end level"), findsOneWidget);
    await tester.tap(find.byTooltip('More').first);
    await tester.pump();
    expect(find.text('PENALTY SHOOTOUT'), findsNothing);
    expect(find.text('Shots'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
