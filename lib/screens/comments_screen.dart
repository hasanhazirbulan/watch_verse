import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/gif_picker_screen.dart';
import 'package:watch_verse/services/comment_service.dart';
import 'package:watch_verse/services/giphy_service.dart';
import 'package:watch_verse/services/social_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/comment_widgets.dart';
import 'package:watch_verse/widgets/text_prompt.dart';

/// Public comments for one title. Users can post text + an image/GIF and like
/// each other's comments. Kept on its own screen so spoilers stay off the
/// detail page.
class CommentsScreen extends StatefulWidget {
  final MediaType mediaType;
  final int mediaId;
  final String title;
  const CommentsScreen({
    super.key,
    required this.mediaType,
    required this.mediaId,
    required this.title,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _svc = CommentService.instance;
  final _controller = TextEditingController();
  // Created once: building these inside build() handed StreamListView a new
  // stream on every setState (sending, attaching, a blocked-list update),
  // which flashed the spinner and threw the list back to the top each time.
  late final Stream<List<Comment>> _comments =
      _svc.stream(widget.mediaType, widget.mediaId);
  late final Stream<List<String>> _blocked =
      SocialService.instance.blockedStream();

  File? _pendingImage; // uploaded on send
  String? _pendingUrl; // pasted GIF/image URL
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasAttachment => _pendingImage != null || _pendingUrl != null;

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _pendingImage = File(picked.path);
        _pendingUrl = null;
      });
    } catch (e) {
      // e.g. photo-library access denied — used to fail with no feedback.
      debugPrint('Comments: image pick failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.errorGeneric)));
    }
  }

  Future<void> _pickGif() async {
    final url = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const GifPickerScreen()),
    );
    if (url != null && url.isNotEmpty && mounted) {
      setState(() {
        _pendingUrl = url;
        _pendingImage = null;
      });
    }
  }

  Future<void> _pasteUrl() async {
    final l10n = AppLocalizations.of(context)!;
    final url = await promptForText(
      context,
      title: l10n.commentsAddLinkTitle,
      hint: l10n.commentsLinkHint,
      actionLabel: l10n.commentsAddAction,
      keyboardType: TextInputType.url,
    );
    if (url != null && url.isNotEmpty && mounted) {
      setState(() {
        _pendingUrl = url;
        _pendingImage = null;
      });
    }
  }

  void _openAttachMenu() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library_rounded,
                    color: context.colors.primary),
                title: Text(l10n.commentsUploadPhoto),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto();
                },
              ),
              // Once a Giphy key is configured, show proper GIF search and
              // drop the fiddly "paste a link" fallback entirely.
              if (GiphyService.isConfigured)
                ListTile(
                  leading: Icon(Icons.gif_box_rounded,
                      color: context.colors.primary),
                  title: Text(l10n.commentsSearchGifs),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickGif();
                  },
                )
              else
                ListTile(
                  leading:
                      Icon(Icons.link_rounded, color: context.colors.primary),
                  title: Text(l10n.commentsAddGifByLink),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pasteUrl();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && !_hasAttachment) return;
    setState(() => _sending = true);
    try {
      String? imageUrl = _pendingUrl;
      if (_pendingImage != null) {
        imageUrl = await _svc.uploadImage(_pendingImage!);
      }
      await _svc.add(
        type: widget.mediaType,
        id: widget.mediaId,
        text: text,
        imageUrl: imageUrl,
      );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _pendingImage = null;
        _pendingUrl = null;
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commentsCouldNotPost(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final signedIn = FirebaseAuth.instance.currentUser != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.commentsTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 13)),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: _blocked,
              builder: (context, blockedSnap) {
                final blocked = blockedSnap.data ?? const <String>[];
                return StreamListView<Comment>(
                  stream: _comments,
                  emptyBuilder: (_) => _empty(),
                  builder: (context, all) {
                    final comments =
                        all.where((c) => !blocked.contains(c.uid)).toList();
                    if (comments.isEmpty) return _empty();
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: comments.length,
                      itemBuilder: (context, i) =>
                          CommentCard(comment: comments[i]),
                    );
                  },
                );
              },
            ),
          ),
          signedIn ? _composer() : _signInHint(),
        ],
      ),
    );
  }

  Widget _composer() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasAttachment) _attachmentPreview(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.add_photo_alternate_rounded,
                    color: context.colors.primary),
                onPressed: _openAttachMenu,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: l10n.commentsAddCommentHint,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: Icon(Icons.send_rounded,
                          color: context.colors.primary),
                      onPressed: _send,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attachmentPreview() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: _pendingImage != null
                    ? Image.file(_pendingImage!, fit: BoxFit.cover)
                    : Image.network(_pendingUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: context.colors.surfaceAlt,
                            child: const Icon(Icons.broken_image_rounded))),
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () => setState(() {
                  _pendingImage = null;
                  _pendingUrl = null;
                }),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.black87, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _signInHint() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Text(l10n.commentsSignInHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary)),
    );
  }

  Widget _empty() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 56, color: context.colors.textMuted),
            const SizedBox(height: 14),
            Text(l10n.commentsEmptyTitle,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(l10n.commentsEmptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
