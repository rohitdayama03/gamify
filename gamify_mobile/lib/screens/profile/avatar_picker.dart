import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../core/constants/app_colors.dart';

/// What the player chose to do with their profile picture.
enum AvatarAction { gallery, camera, remove }

/// Picking and cropping a profile picture.
class AvatarPicker {
  // Matches app.media.max-avatar-size on the backend
  static const int maxBytes = 2 * 1024 * 1024;
  // Square side of the saved picture; plenty for the largest avatar on screen
  static const double outputSide = 800;

  static final ImagePicker _picker = ImagePicker();

  /// Asks whether to choose, take or remove a picture; Remove is offered only when they have one.
  static Future<AvatarAction?> askAction(BuildContext context, {required bool hasPicture}) {
    return showModalBottomSheet<AvatarAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, AvatarAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, AvatarAction.camera),
            ),
            if (hasPicture)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Remove picture', style: TextStyle(color: AppColors.error)),
                onTap: () => Navigator.pop(sheetContext, AvatarAction.remove),
              ),
          ],
        ),
      ),
    );
  }

  /// Picks a photo and lets the player crop it square. Returns the JPEG, or null if they backed out.
  /// Throws [AvatarPickerException] with a message to show when the photo can't be used.
  static Future<Uint8List?> pickAndCrop(BuildContext context, ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 2048, maxHeight: 2048, imageQuality: 90);
    if (picked == null || !context.mounted) return null;
    final original = await picked.readAsBytes();
    if (!context.mounted) return null;
    final cropped = await _crop(context, original);
    if (cropped == null) return null;
    if (!_isJpeg(cropped)) throw const AvatarPickerException("Couldn't prepare that photo. Try another one.");
    if (cropped.length > maxBytes) throw const AvatarPickerException('That picture is too large. Try another one.');
    return cropped;
  }

  static Future<Uint8List?> _crop(BuildContext context, Uint8List image) async {
    Uint8List? cropped;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (editorContext) => CropRotateEditor.memory(
          image,
          initConfigs: CropRotateEditorInitConfigs(
            // The editor uses material_ui's theme types; dark with the app's mint accent
            theme: material_ui.ThemeData(
              colorScheme: material_ui.ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.dark),
            ),
            convertToUint8List: true,
            configs: const ProImageEditorConfigs(
              imageGeneration: ImageGenerationConfigs(
                outputFormat: OutputFormat.jpg,
                jpegQuality: 85,
                maxOutputSize: Size(outputSide, outputSide),
              ),
              // Square only, so no aspect ratio choice
              cropRotateEditor: CropRotateEditorConfigs(
                initAspectRatio: 1,
                aspectRatios: [AspectRatioItem(text: '1:1', value: 1)],
                tools: [CropRotateTool.rotate, CropRotateTool.flip, CropRotateTool.reset],
              ),
            ),
            callbacks: ProImageEditorCallbacks(
              // The editor calls onCloseEditor right after this, so only that one leaves the editor
              onImageEditingComplete: (bytes) async => cropped = bytes,
              onCloseEditor: (_) => Navigator.pop(editorContext),
            ),
          ),
        ),
      ),
    );
    return cropped;
  }

  static bool _isJpeg(Uint8List bytes) =>
      bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
}

class AvatarPickerException implements Exception {
  final String message;

  const AvatarPickerException(this.message);
}
