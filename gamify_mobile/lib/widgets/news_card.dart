import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/time_format.dart';
import '../models/news_item.dart';
import 'game_logo.dart';

/// A headline with its image and teaser; tapping opens the full article on the publisher's site.
class NewsCard extends StatelessWidget {
  final NewsItem item;

  const NewsCard({super.key, required this.item});

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(item.link);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open the article")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = timeAgo(item.publishedAt);
    final topic = item.game?.shortLabel ?? item.category;

    return Semantics(
      button: true,
      label:
          '${item.video ? 'Video: ' : ''}${item.title}. ${item.source}, $time. ${item.video ? 'Opens YouTube' : 'Opens in browser'}',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (item.imageUrl != null)
                _NewsImage(url: item.imageUrl!, video: item.video),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (topic != null)
                          Flexible(
                            child: Text(
                              topic.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.label(
                                fontSize: 11,
                                // Our own games stand out in mint; other topics stay muted
                                color: item.game != null
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (topic != null) const SizedBox(width: AppSpacing.xs),
                        Text(
                          time,
                          style: AppFonts.label(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Image-less game stories (e.g. from Google News) show the game's logo beside the headline
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontSize: 17, height: 1.25),
                          ),
                        ),
                        if (item.imageUrl == null && item.game != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          GameLogo(game: item.game!, width: 64, height: 44),
                        ],
                      ],
                    ),
                    if (item.summary != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.video
                                ? '${item.source} · Watch on YouTube'
                                : item.source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                        Icon(
                          item.video
                              ? Icons.smart_display_outlined
                              : Icons.open_in_new,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsImage extends StatelessWidget {
  final String url;
  // Shows a play badge over the thumbnail
  final bool video;

  const _NewsImage({required this.url, this.video = false});

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      url,
      fit: BoxFit.cover,
      // On web, fall back to a plain <img> when the image host doesn't allow cross-origin loading
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const ColoredBox(color: AppColors.surfaceAlt),
      errorBuilder: (_, _, _) => const ColoredBox(
        color: AppColors.surfaceAlt,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: !video
          ? image
          : Stack(
              fit: StackFit.expand,
              children: [
                image,
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 34,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
