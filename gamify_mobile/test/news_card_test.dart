import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamify_mobile/models/game.dart';
import 'package:gamify_mobile/models/news_item.dart';
import 'package:gamify_mobile/widgets/game_logo.dart';
import 'package:gamify_mobile/widgets/news_card.dart';

NewsItem _item({bool video = false, String? imageUrl, Game? game, String source = 'IGN India'}) => NewsItem(
      id: 1,
      title: 'BMIC 2026 Grand Finals',
      link: 'https://example.com/story',
      source: source,
      video: video,
      imageUrl: imageUrl,
      game: game,
      publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

Future<void> _pump(WidgetTester tester, NewsItem item) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: NewsCard(item: item)))));
}

void main() {
  testWidgets('a video shows a play badge and points to YouTube', (tester) async {
    await _pump(tester, _item(video: true, imageUrl: 'https://i4.ytimg.com/vi/abc/hqdefault.jpg', source: 'KRAFTON INDIA ESPORTS'));

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.text('KRAFTON INDIA ESPORTS · Watch on YouTube'), findsOneWidget);
    expect(find.byIcon(Icons.smart_display_outlined), findsOneWidget);
  });

  testWidgets('an article has no play badge and opens in the browser', (tester) async {
    await _pump(tester, _item(imageUrl: 'https://example.com/photo.jpg'));

    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.text('IGN India'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
  });

  testWidgets('a game story without an image shows the game logo instead', (tester) async {
    await _pump(tester, _item(game: Game.bgmi, source: 'The Times'));

    final logo = tester.widget<GameLogo>(find.byType(GameLogo));
    expect(logo.game, Game.bgmi);
    expect(find.text('BGMI'), findsOneWidget);
  });
}
