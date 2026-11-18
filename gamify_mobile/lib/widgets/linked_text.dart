import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/links/tournament_links.dart';
import '../screens/tournaments/tournament_detail_screen.dart';

/// Selectable text whose web links can be tapped. A shared tournament link opens the tournament in the
/// app; any other link opens in the browser.
class LinkedText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color linkColor;

  const LinkedText(this.text, {super.key, required this.style, required this.linkColor});

  // Stops before whitespace; trailing punctuation is trimmed off afterwards
  static final RegExp _url = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);
  static final RegExp _trailing = RegExp(r'[.,;:!?)\]}>]+$');

  /// The text split into plain runs and links, in order.
  static List<({String text, Uri? link})> split(String text) {
    final parts = <({String text, Uri? link})>[];
    var start = 0;
    for (final match in _url.allMatches(text)) {
      var url = match.group(0)!;
      final trailing = _trailing.firstMatch(url);
      if (trailing != null) url = url.substring(0, trailing.start);
      final uri = Uri.tryParse(url);
      if (uri == null || uri.host.isEmpty) continue;
      if (match.start > start) parts.add((text: text.substring(start, match.start), link: null));
      parts.add((text: url, link: uri));
      start = match.start + url.length;
    }
    if (start < text.length) parts.add((text: text.substring(start), link: null));
    return parts;
  }

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _open(Uri uri) async {
    final tournamentId = TournamentLinks.tournamentIdFrom(uri);
    if (tournamentId != null) {
      await TournamentDetailScreen.open(context, tournamentId);
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open that link")));
    }
  }

  TapGestureRecognizer _recognizerFor(Uri link) {
    final recognizer = TapGestureRecognizer()..onTap = () => _open(link);
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    final parts = LinkedText.split(widget.text);
    if (parts.every((p) => p.link == null)) return SelectableText(widget.text, style: widget.style);

    _disposeRecognizers();
    return SelectableText.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (final part in parts)
            if (part.link == null)
              TextSpan(text: part.text)
            else
              TextSpan(
                text: part.text,
                style: TextStyle(color: widget.linkColor, decoration: TextDecoration.underline, decorationColor: widget.linkColor),
                recognizer: _recognizerFor(part.link!),
              ),
        ],
      ),
    );
  }
}
