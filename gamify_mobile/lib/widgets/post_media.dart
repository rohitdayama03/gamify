import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/constants/app_colors.dart';
import '../providers/post_provider.dart';

/// A post image from its signed S3 link.
class PostNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  // Decodes at roughly this width to save memory in grids
  final int? cacheWidth;

  const PostNetworkImage({super.key, required this.url, this.fit = BoxFit.cover, this.cacheWidth});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      PostProvider.mediaUrl(url),
      fit: fit,
      cacheWidth: cacheWidth,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const ColoredBox(color: AppColors.surfaceAlt, child: SizedBox.expand()),
      errorBuilder: (_, _, _) => const ColoredBox(
        color: AppColors.surfaceAlt,
        child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary)),
      ),
    );
  }
}

/// Plays a post's video from its signed S3 link: tap to play or pause, with a mute toggle and a progress bar.
/// Starts paused on its [thumbnailPath] so nothing plays or downloads until asked.
class PostVideoPlayer extends StatefulWidget {
  final String url;
  final String? thumbnailUrl;
  final double aspectRatio;

  const PostVideoPlayer({super.key, required this.url, this.thumbnailUrl, required this.aspectRatio});

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  VideoPlayerController? _controller;
  bool _starting = false;
  bool _failed = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    final controller = VideoPlayerController.networkUrl(Uri.parse(PostProvider.mediaUrl(widget.url)));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
      return;
    } finally {
      if (mounted) setState(() => _starting = false);
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    controller.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() => _controller = controller);
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) {
      _start();
    } else {
      controller.value.isPlaying ? controller.pause() : controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Semantics(
        button: true,
        label: ready && controller.value.isPlaying ? 'Pause video' : 'Play video',
        child: GestureDetector(
          onTap: _failed ? null : _togglePlay,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              if (ready)
                FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                )
              else if (widget.thumbnailUrl != null)
                PostNetworkImage(url: widget.thumbnailUrl!, fit: BoxFit.contain),
              if (_failed)
                const Center(child: Text("Couldn't play this video", style: TextStyle(color: AppColors.textSecondary)))
              else if (_starting)
                const Center(child: CircularProgressIndicator())
              else if (!ready || !controller.value.isPlaying)
                const Center(child: _PlayBadge()),
              if (ready) ...[
                Positioned(
                  right: 8,
                  bottom: 12,
                  child: IconButton.filledTonal(
                    tooltip: controller.value.volume == 0 ? 'Unmute' : 'Mute',
                    onPressed: () => controller.setVolume(controller.value.volume == 0 ? 1 : 0),
                    icon: Icon(controller.value.volume == 0 ? Icons.volume_off : Icons.volume_up, size: 18),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(playedColor: AppColors.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
      child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
    );
  }
}
