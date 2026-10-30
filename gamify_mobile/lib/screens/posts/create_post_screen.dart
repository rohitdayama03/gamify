import 'dart:io';
import 'dart:ui' as ui;

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/post_model.dart';
import '../../providers/post_provider.dart';
import '../../widgets/primary_button.dart';

/// New post: write text, or pick a photo (edited in the image editor: crop, filters, text, stickers,
/// drawing) or a video (up to 60 s and 50 MB), add a caption and share. Pops with the new post.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  static Future<Post?> open(BuildContext context) =>
      Navigator.push<Post>(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _picker = ImagePicker();
  final _textController = TextEditingController();

  PostType _type = PostType.text;
  // The edited photo, or the picked video
  Uint8List? _mediaBytes;
  // image/jpeg for edited photos; video/mp4 or video/quicktime for videos
  String? _mediaContentType;
  Uint8List? _thumbnailBytes;
  int? _width;
  int? _height;
  // Plays the picked video in the preview
  VideoPlayerController? _videoController;
  bool _picking = false;
  bool _sharing = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  bool get _hasMedia => _mediaBytes != null;

  bool get _canShare {
    if (_sharing || _picking) return false;
    final text = _textController.text.trim();
    if (text.length > PostLimits.maxTextLength) return false;
    return _type == PostType.text ? text.isNotEmpty : _hasMedia;
  }

  void _clearMedia() {
    _videoController?.dispose();
    _videoController = null;
    _mediaBytes = null;
    _mediaContentType = null;
    _thumbnailBytes = null;
    _width = null;
    _height = null;
  }

  void _selectType(PostType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _error = null;
      _clearMedia();
    });
  }

  Future<ImageSource?> _askSource(String what) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Choose $what from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            // The browser can't open the camera through image_picker reliably
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(what == 'photo' ? 'Take a photo' : 'Record a video'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final source = await _askSource('photo');
    if (source == null || !mounted) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      // Scale big camera photos down before editing, so the editor stays fast
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: PostLimits.maxImageSide.toDouble(),
        maxHeight: PostLimits.maxImageSide.toDouble(),
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;
      final original = await picked.readAsBytes();
      if (!mounted) return;
      final edited = await _edit(original);
      if (edited == null || !mounted) return;
      if (!_isJpeg(edited)) {
        setState(() => _error = "Couldn't prepare that photo. Try another one.");
        return;
      }
      if (edited.length > PostLimits.maxImageBytes) {
        setState(() => _error = 'That photo is over 10 MB even after editing. Try another one.');
        return;
      }
      final size = await _imageSize(edited);
      setState(() {
        _clearMedia();
        _mediaBytes = edited;
        // The editor always exports JPEG
        _mediaContentType = 'image/jpeg';
        _width = size?.width.round();
        _height = size?.height.round();
      });
    } catch (e) {
      debugPrint('Could not open photo: $e');
      if (mounted) setState(() => _error = "Couldn't open that photo");
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  // Opens the image editor; returns the edited JPEG, or null if the player backed out
  Future<Uint8List?> _edit(Uint8List image) async {
    Uint8List? edited;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (editorContext) => ProImageEditor.memory(
          image,
          configs: ProImageEditorConfigs(
            // The editor uses material_ui's theme types; dark with the app's mint accent
            theme: material_ui.ThemeData(
              colorScheme: material_ui.ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.dark),
            ),
            imageGeneration: const ImageGenerationConfigs(
              outputFormat: OutputFormat.jpg,
              jpegQuality: 85,
              maxOutputSize: Size(2048, 2048),
              // Otherwise an unedited JPEG comes back as the original file, location metadata and all
              enableUseOriginalBytes: false,
            ),
          ),
          callbacks: ProImageEditorCallbacks(
            // The editor calls onCloseEditor right after this, so only that one leaves the editor;
            // popping in both closed the New post screen too
            onImageEditingComplete: (bytes) async => edited = bytes,
            onCloseEditor: (_) => Navigator.pop(editorContext),
          ),
        ),
      ),
    );
    return edited;
  }

  Future<void> _pickVideo() async {
    final source = await _askSource('video');
    if (source == null || !mounted) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    VideoPlayerController? controller;
    try {
      final picked = await _picker.pickVideo(source: source, maxDuration: PostLimits.maxVideoDuration);
      if (picked == null || !mounted) return;
      final bytes = await picked.length();
      if (bytes > PostLimits.maxVideoBytes) {
        setState(() => _error = 'Videos can be up to 50 MB. That one is ${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB.');
        return;
      }
      controller = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(picked.path))
          : VideoPlayerController.file(File(picked.path));
      await controller.initialize();
      final duration = controller.value.duration;
      // A little slack, since recorders often run a few milliseconds over
      if (duration > PostLimits.maxVideoDuration + const Duration(milliseconds: 500)) {
        setState(() => _error = 'Videos can be up to 60 seconds. That one is ${duration.inSeconds} seconds.');
        return;
      }
      final videoBytes = await picked.readAsBytes();
      final contentType = _videoContentType(videoBytes);
      if (contentType == null) {
        setState(() => _error = 'Videos must be MP4 or MOV.');
        return;
      }
      final thumbnail = await _videoThumbnail(picked.path);
      if (!mounted) return;
      await controller.setLooping(true);
      final size = controller.value.size;
      setState(() {
        _clearMedia();
        _mediaBytes = videoBytes;
        _mediaContentType = contentType;
        _thumbnailBytes = thumbnail;
        _width = size.width > 0 ? size.width.round() : null;
        _height = size.height > 0 ? size.height.round() : null;
        _videoController = controller;
      });
      controller = null; // now owned by the state
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't open that video. Try an MP4 or MOV file.");
    } finally {
      await controller?.dispose();
      if (mounted) setState(() => _picking = false);
    }
  }

  // MP4 and MOV files start with an "ftyp" box at byte 4; MOV's brand is "qt  ". Same check as the backend.
  static bool _isJpeg(Uint8List bytes) =>
      bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;

  static String? _videoContentType(Uint8List bytes) {
    if (bytes.length < 12 || String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') return null;
    return String.fromCharCodes(bytes.sublist(8, 12)) == 'qt  ' ? 'video/quicktime' : 'video/mp4';
  }

  // A still for the profile grid; without one the grid shows a video icon, so failures don't block posting
  static Future<Uint8List?> _videoThumbnail(String path) async {
    if (kIsWeb) return null;
    try {
      return await FcNativeVideoThumbnail().saveThumbnailToBytes(
        srcFile: path,
        width: 720,
        height: 720,
        format: 'jpeg',
        quality: 75,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Size?> _imageSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  Future<void> _share() async {
    if (!_canShare) return;
    _videoController?.pause();
    setState(() {
      _sharing = true;
      _progress = 0;
      _error = null;
    });
    final provider = Provider.of<PostProvider>(context, listen: false);
    final text = _textController.text.trim();
    final post = await provider.createPost(
      type: _type,
      text: text.isEmpty ? null : text,
      mediaBytes: _mediaBytes,
      mediaContentType: _mediaContentType,
      thumbnailBytes: _thumbnailBytes,
      width: _width,
      height: _height,
      onProgress: (value) {
        if (mounted) setState(() => _progress = value);
      },
    );
    if (!mounted) return;
    setState(() => _sharing = false);
    if (post == null) {
      setState(() => _error = provider.errorMessage ?? 'Could not share your post');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted')));
    Navigator.pop(context, post);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Don't lose an upload in progress to a stray back press
      canPop: !_sharing,
      child: Scaffold(
        appBar: AppBar(title: const Text('New post')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            SegmentedButton<PostType>(
              segments: const [
                ButtonSegment(value: PostType.text, label: Text('Text'), icon: Icon(Icons.notes)),
                ButtonSegment(value: PostType.image, label: Text('Photo'), icon: Icon(Icons.image_outlined)),
                ButtonSegment(value: PostType.video, label: Text('Video'), icon: Icon(Icons.videocam_outlined)),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: _sharing ? null : (value) => _selectType(value.first),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_type != PostType.text) ...[
              _buildMediaArea(),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _type == PostType.image
                    ? 'Crop, add filters, text and stickers before posting. Up to 10 MB.'
                    : 'MP4 or MOV, up to 60 seconds and 50 MB.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              controller: _textController,
              enabled: !_sharing,
              minLines: _type == PostType.text ? 6 : 2,
              maxLines: 12,
              maxLength: PostLimits.maxTextLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _type == PostType.text ? "What's on your mind? Share a clutch moment, a tip, a squad call…" : 'Write a caption…',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              MessageBanner(message: _error!),
            ],
            const SizedBox(height: AppSpacing.md),
            if (_sharing && _hasMedia) ...[
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _progress >= 1 ? 'Finishing up…' : 'Uploading ${(_progress * 100).round()}%',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            PrimaryButton(label: 'Share', icon: Icons.send, loading: _sharing, onPressed: _canShare ? _share : null),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaArea() {
    final bytes = _mediaBytes;
    final isPhoto = _type == PostType.image;
    if (bytes == null) {
      return _PickBox(
        icon: isPhoto ? Icons.add_photo_alternate_outlined : Icons.video_call_outlined,
        label: isPhoto ? 'Add a photo' : 'Add a video',
        loading: _picking,
        onTap: isPhoto ? _pickPhoto : _pickVideo,
      );
    }
    final aspect = (_width != null && _height != null && _height! > 0) ? (_width! / _height!).clamp(0.8, 1.91) : 1.0;
    final controller = _videoController;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: AspectRatio(
            aspectRatio: aspect.toDouble(),
            child: isPhoto
                ? Image.memory(bytes, fit: BoxFit.cover)
                : controller == null
                    ? const ColoredBox(color: Colors.black)
                    : GestureDetector(
                        onTap: () => setState(() {
                          controller.value.isPlaying ? controller.pause() : controller.play();
                        }),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Colors.black),
                            FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: controller.value.size.width,
                                height: controller.value.size.height,
                                child: VideoPlayer(controller),
                              ),
                            ),
                            if (!controller.value.isPlaying)
                              const Center(child: Icon(Icons.play_circle_fill, size: 56, color: Colors.white70)),
                          ],
                        ),
                      ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text(
              '${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const Spacer(),
            if (isPhoto)
              TextButton.icon(
                onPressed: _sharing
                    ? null
                    : () async {
                        final edited = await _edit(bytes);
                        if (edited == null || !mounted) return;
                        final size = await _imageSize(edited);
                        setState(() {
                          _mediaBytes = edited;
                          _width = size?.width.round();
                          _height = size?.height.round();
                        });
                      },
                icon: const Icon(Icons.tune),
                label: const Text('Edit'),
              ),
            TextButton.icon(
              onPressed: _sharing ? null : (isPhoto ? _pickPhoto : _pickVideo),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Replace'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PickBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PickBox({required this.icon, required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: loading
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 48, color: AppColors.primary),
                      const SizedBox(height: AppSpacing.xs),
                      Text(label.toUpperCase(), style: AppFonts.label(color: AppColors.textPrimary)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
