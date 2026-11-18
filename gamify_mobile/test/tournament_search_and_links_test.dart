import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamify_mobile/core/links/tournament_links.dart';
import 'package:gamify_mobile/models/game.dart';
import 'package:gamify_mobile/models/tournament_model.dart';
import 'package:gamify_mobile/providers/tournament_provider.dart';
import 'package:gamify_mobile/screens/tournaments/share_tournament_sheet.dart';
import 'package:gamify_mobile/screens/tournaments/tournaments_screen.dart';
import 'package:gamify_mobile/widgets/linked_text.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

TournamentSummary _tournament(int id, String name, {String status = 'OPEN'}) => TournamentSummary.fromJson({
      'id': id,
      'name': name,
      'game': 'EFOOTBALL',
      'startsAt': DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String(),
      'participantCount': 3,
      'status': status,
      'organizer': {'playerId': 7, 'username': 'organizer_with_a_long_name'},
      'myStatus': 'NONE',
    });

/// Answers from memory instead of the server and records each search.
class _FakeTournaments extends TournamentProvider {
  final searches = <({String query, Game? game, TournamentStatusFilter status, TournamentSearchSort sort, int page})>[];

  @override
  Future<List<TournamentSummary>?> fetchOpen({Game? game}) async => [_tournament(1, 'Open One')];

  @override
  Future<List<TournamentSummary>?> searchTournaments({
    required String query,
    Game? game,
    TournamentStatusFilter status = TournamentStatusFilter.any,
    TournamentSearchSort sort = TournamentSearchSort.relevance,
    int page = 0,
    int pageSize = 20,
  }) async {
    searches.add((query: query, game: game, status: status, sort: sort, page: page));
    // A full first page, then a short second one
    final count = page == 0 ? pageSize : 3;
    return [for (var i = 0; i < count; i++) _tournament(100 * (page + 1) + i, 'Cup ${page * pageSize + i + 1}')];
  }
}

Future<void> _pumpPhone(WidgetTester tester, Widget child, {TournamentProvider? provider}) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider<TournamentProvider>.value(
    value: provider ?? _FakeTournaments(),
    child: MaterialApp(theme: ThemeData.dark(), home: child),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('tournament links', () {
    test('the shared link and the app link both name the tournament', () {
      expect(TournamentLinks.urlFor(42), 'https://gamify-api.duckdns.org/t/42');
      expect(TournamentLinks.tournamentIdFrom(Uri.parse(TournamentLinks.urlFor(42))), 42);
      expect(TournamentLinks.tournamentIdFrom(Uri.parse('gamify://tournament/42')), 42);
      // A local backend, and the older query form
      expect(TournamentLinks.tournamentIdFrom(Uri.parse('http://192.168.1.34:8080/t/7/')), 7);
      expect(TournamentLinks.tournamentIdFrom(Uri.parse('https://gamify-api.duckdns.org/t?id=7')), 7);
    });

    test('other links are not tournaments', () {
      for (final link in [
        'https://example.com/',
        'https://example.com/t/',
        'https://example.com/t/abc',
        'https://example.com/t/-3',
        'https://example.com/t/0',
        'https://example.com/t/5/fixtures',
        'https://example.com/players/t/5',
        'https://example.com/tournament?id=3',
        'gamify://player/3',
        'gamify://tournament/',
        'mailto:someone@example.com',
      ]) {
        expect(TournamentLinks.tournamentIdFrom(Uri.parse(link)), isNull, reason: link);
      }
    });

    test('links are found in message text without trailing punctuation', () {
      final parts = LinkedText.split('Join (https://example.com/t/?id=5). Or https://news.example.com/a, ok?');
      expect(parts.map((p) => p.text), ['Join (', 'https://example.com/t/?id=5', '). Or ', 'https://news.example.com/a', ', ok?']);
      expect(parts.where((p) => p.link != null).length, 2);
      expect(LinkedText.split('no links here').single.link, isNull);
    });
  });

  testWidgets('a tournament link in a message opens the tournament', (tester) async {
    await _pumpPhone(
      tester,
      Scaffold(
        body: LinkedText(
          'Play: ${TournamentLinks.urlFor(9)}',
          style: const TextStyle(fontSize: 15),
          linkColor: Colors.green,
        ),
      ),
    );
    // Tap inside the link, right of "Play: " on the first line
    await tester.tapAt(tester.getTopLeft(find.byType(LinkedText)) + const Offset(120, 8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // The tournament page is pushed (it shows its placeholder title while loading)
    expect(find.text('Tournament'), findsOneWidget);
  });

  testWidgets('the share sheet offers chat, other apps and copy', (tester) async {
    await _pumpPhone(tester, Scaffold(body: ShareTournamentSheet(tournament: _tournament(5, 'Friday Night Cup'))));
    expect(find.text('Send to friends'), findsOneWidget);
    expect(find.text('Share to other apps'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text(TournamentLinks.urlFor(5)), findsOneWidget);
    expect(
      ShareTournamentSheet(tournament: _tournament(5, 'Friday Night Cup')).message,
      'Friday Night Cup · eFootball tournament on Gamify\n${TournamentLinks.urlFor(5)}',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('searching lists matches, sorts, filters and loads more', (tester) async {
    final provider = _FakeTournaments();
    await _pumpPhone(tester, const TournamentsScreen(), provider: provider);
    expect(find.text('Open One'), findsOneWidget);
    expect(find.byIcon(Icons.sort), findsNothing);

    // One character waits for more
    await tester.enterText(find.byType(TextField), 'c');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Keep typing'), findsOneWidget);
    expect(provider.searches, isEmpty);

    await tester.enterText(find.byType(TextField), 'cup');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(provider.searches.single.query, 'cup');
    expect(find.text('Cup 1'), findsOneWidget);
    expect(find.text('Relevance'), findsOneWidget);
    expect(find.text('Any status'), findsOneWidget);

    await tester.tap(find.text('Relevance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Earliest start').last);
    await tester.pumpAndSettle();
    expect(provider.searches.last.sort, TournamentSearchSort.earliest);

    await tester.tap(find.text('Any status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open').last);
    await tester.pumpAndSettle();
    expect(provider.searches.last.status, TournamentStatusFilter.open);
    expect(provider.searches.last.sort, TournamentSearchSort.earliest);

    // Scrolling to the end fetches the next page
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(provider.searches.last.page, 1);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Cup 23'), findsOneWidget);
    // The short page was the last one
    expect(provider.searches.where((s) => s.page == 2), isEmpty);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Open One'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
