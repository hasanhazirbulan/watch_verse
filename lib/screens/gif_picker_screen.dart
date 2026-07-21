import 'dart:async';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/services/giphy_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

/// Full-screen Giphy picker. Pops with the selected GIF URL (a String), or null
/// if the user backs out. Shows trending GIFs first, then live search results.
class GifPickerScreen extends StatefulWidget {
  const GifPickerScreen({super.key});

  @override
  State<GifPickerScreen> createState() => _GifPickerScreenState();
}

class _GifPickerScreenState extends State<GifPickerScreen> {
  final GiphyService _giphy = GiphyService();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<GiphyGif> _gifs = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(value));
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final results = await _giphy.search(query);
      if (!mounted) return;
      setState(() {
        _gifs = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gifPickerTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.gifSearchHint,
                prefixIcon: Icon(Icons.search_rounded,
                    color: context.colors.textSecondary),
              ),
              onChanged: _onChanged,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _body(context)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(l10n.gifPoweredBy,
                style: TextStyle(color: context.colors.textMuted, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return _message(context, Icons.wifi_off_rounded, l10n.gifLoadErrorTitle,
          l10n.gifLoadErrorSubtitle);
    }
    if (_gifs.isEmpty) {
      return _message(context, Icons.gif_box_outlined, l10n.gifEmptyTitle,
          l10n.gifEmptySubtitle);
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: _gifs.length,
      itemBuilder: (context, i) {
        final gif = _gifs[i];
        return GestureDetector(
          onTap: () => Navigator.pop(context, gif.gifUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: context.colors.surfaceAlt,
              child: Image.network(
                gif.previewUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const SizedBox.shrink(),
                errorBuilder: (context, __, ___) =>
                    Icon(Icons.broken_image_rounded,
                        color: context.colors.textMuted),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _message(
      BuildContext context, IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: context.colors.textMuted),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
