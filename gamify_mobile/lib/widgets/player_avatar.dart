import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// A player's round profile picture. Shows their initial until the picture loads, and instead of it when
/// they haven't set one or it can't be loaded. Colours default to the app's usual initial avatar.
class PlayerAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  // Overrides the initial's style, e.g. the display font on the profile header
  final TextStyle? textStyle;

  const PlayerAvatar({
    super.key,
    required this.name,
    this.url,
    this.radius = 20,
    this.backgroundColor = AppColors.surfaceAlt,
    this.foregroundColor = AppColors.primary,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundImage: url == null ? null : SignedUrlImage(url),
      // The initial underneath stays visible if the picture fails
      onForegroundImageError: url == null ? null : (_, _) {},
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: textStyle ?? TextStyle(color: foregroundColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// An image at a signed S3 link. The signature changes with every API response but the file doesn't, so
/// this is cached by the link's path: the same picture isn't downloaded again for each new signature.
@immutable
class SignedUrlImage extends ImageProvider<SignedUrlImage> {
  final String url;
  final String _path;

  SignedUrlImage(this.url) : _path = Uri.tryParse(url)?.path ?? url;

  @override
  Future<SignedUrlImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(SignedUrlImage key, ImageDecoderCallback decode) {
    final network = NetworkImage(key.url);
    return network.loadImage(network, decode);
  }

  @override
  bool operator ==(Object other) => other is SignedUrlImage && other._path == _path;

  @override
  int get hashCode => _path.hashCode;
}
