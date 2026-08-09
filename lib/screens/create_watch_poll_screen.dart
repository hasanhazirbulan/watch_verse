import 'dart:async';

import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/watch_poll_detail_screen.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/social_service.dart';
import 'package:watch_verse/services/watch_poll_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/social_widgets.dart';

/// Pick 2-6 candidate titles and (optionally) which friends to invite, then
/// creates a [WatchPollService] poll everyone invited can vote on.
class CreateWatchPollScreen extends StatefulWidget {
  const CreateWatchPollScreen({super.key});

  @override
  State<CreateWatchPollScreen> createState() => _CreateWatchPollScreenState();
}

class _CreateWatchPollScreenState extends State<CreateWatchPollScreen> {
  static const _maxOptions = 6;

  final _api = APIservices();
  final _titleController = TextEditingController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<MediaItem> _searchResults = [];
  final List<MediaItem> _selectedOptions = [];
  final Set<String> _selectedMemberUids = {};
  bool _creating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await _api.searchMulti(q.trim()).catchError((_) => <MediaItem>[]);
      if (mounted) setState(() => _searchResults = results);
    });
  }

  bool _isSelected(MediaItem item) => _selectedOptions
      .any((o) => o.id == item.id && o.mediaType == item.mediaType);

  void _toggleOption(MediaItem item) {
    setState(() {
      if (_isSelected(item)) {
        _selectedOptions
            .removeWhere((o) => o.id == item.id && o.mediaType == item.mediaType);
      } else if (_selectedOptions.length < _maxOptions) {
        _selectedOptions.add(item);
      }
    });
  }

  Future<void> _create() async {
    if (_selectedOptions.length < 2 || _creating) return;
    setState(() => _creating = true);
    final id = await WatchPollService.instance.createPoll(
      title: _titleController.text,
      options: _selectedOptions,
      invitedUids: _selectedMemberUids.toList(),
    );
    if (!mounted) return;
    setState(() => _creating = false);
    if (id != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => WatchPollDetailScreen(pollId: id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canCreate = _selectedOptions.length >= 2 && !_creating;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createWatchPollTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l10n.watchPollTitleHint),
          ),
          const SizedBox(height: 22),
          Text(l10n.watchPollOptionsLabel(_selectedOptions.length, _maxOptions),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          if (_selectedOptions.isNotEmpty) _selectedOptionsRow(context),
          if (_selectedOptions.isNotEmpty) const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.watchPollSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
            onChanged: _onSearchChanged,
          ),
          for (final item in _searchResults) _resultTile(context, item),
          const SizedBox(height: 26),
          Text(l10n.watchPollInviteLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text(l10n.watchPollInviteSubtitle,
              style: TextStyle(color: context.colors.textMuted, fontSize: 12.5)),
          const SizedBox(height: 12),
          _memberPicker(context),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canCreate ? _create : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(l10n.watchPollCreateAction,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedOptionsRow(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = _selectedOptions[i];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 96,
                  child: TmdbImage(url: Tmdb.poster(item.posterPath, size: 'w185')),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _toggleOption(item),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded,
                        size: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _resultTile(BuildContext context, MediaItem item) {
    final selected = _isSelected(item);
    final full = !selected && _selectedOptions.length >= _maxOptions;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: !full,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40,
          height: 56,
          child: TmdbImage(url: Tmdb.poster(item.posterPath, size: 'w185')),
        ),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(item.year),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
        color: selected ? context.colors.success : context.colors.textMuted,
      ),
      onTap: full ? null : () => _toggleOption(item),
    );
  }

  Widget _memberPicker(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: SocialService.instance.myStream(),
      builder: (context, snap) {
        final following =
            (snap.data?['following'] as List?)?.cast<String>() ?? const [];
        if (following.isEmpty) {
          return Text(
            AppLocalizations.of(context)!.watchPollNoFriendsYet,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          );
        }
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: SocialService.instance.usersByIds(following),
          builder: (context, userSnap) {
            final users = userSnap.data ?? const <Map<String, dynamic>>[];
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final u in users) _memberChip(context, u),
              ],
            );
          },
        );
      },
    );
  }

  Widget _memberChip(BuildContext context, Map<String, dynamic> user) {
    final uid = user['uid'] as String;
    final name = (user['name'] ?? '') as String;
    final selected = _selectedMemberUids.contains(uid);
    return GestureDetector(
      onTap: () => setState(() =>
          selected ? _selectedMemberUids.remove(uid) : _selectedMemberUids.add(uid)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.primary.withValues(alpha: 0.16)
              : context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: context.colors.primary, width: 1.3)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(photoURL: user['photoURL'] as String?, name: name, radius: 11),
            const SizedBox(width: 6),
            Text(name,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? context.colors.primary
                        : context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
