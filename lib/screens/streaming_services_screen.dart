import 'dart:async';

import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/streaming/streaming_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/streaming_widgets.dart';

/// Settings → "My streaming services": pick a region and the services the
/// user subscribes to. Every change is saved straight to the profile
/// (`users/{uid}.streamingRegion` / `.streamingProviderIds`).
class StreamingServicesScreen extends StatefulWidget {
  final StreamingDeps? deps;
  const StreamingServicesScreen({super.key, this.deps});

  @override
  State<StreamingServicesScreen> createState() =>
      _StreamingServicesScreenState();
}

class _StreamingServicesScreenState extends State<StreamingServicesScreen> {
  late final StreamingDeps _deps = widget.deps ?? StreamingDeps.instance;

  late Future<StreamingPrefs> _initial;
  late Future<List<StreamingRegion>> _regions;
  Future<List<WatchProvider>>? _catalog;

  String? _region;
  Set<int> _selected = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    // Regions only feed the picker (and the default); if they fail the
    // device/saved region still works, so this never blocks the list.
    _regions = _deps.source.regions().catchError(
      (Object _) => <StreamingRegion>[],
    );
    _initial = _deps.prefs.watch().first.then((p) async {
      var region = p.region;
      if (region == null) {
        final regions = await _regions;
        region = defaultStreamingRegion(
          _deps.deviceCountry(),
          regions.isEmpty ? null : regions.map((r) => r.code),
        );
      }
      _region = region;
      _selected = {...p.providerIds};
      _catalog = _loadCatalog(region);
      return p;
    });
  }

  /// The catalog can fail before its FutureBuilder is mounted (it's started
  /// while the prefs load), so mark the error handled here — the builder
  /// still receives it and shows a retry.
  Future<List<WatchProvider>> _loadCatalog(String region) {
    final f = _deps.source.catalog(region);
    f.ignore();
    return f;
  }

  Future<void> _save() async {
    try {
      await _deps.prefs.save(
        StreamingPrefs(region: _region, providerIds: _selected),
      );
    } catch (e) {
      debugPrint('StreamingServicesScreen: save failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.streamingSaveError),
        ),
      );
    }
  }

  void _toggle(int id) {
    setState(() {
      _selected = {..._selected};
      if (!_selected.remove(id)) _selected.add(id);
    });
    unawaited(_save());
  }

  void _setRegion(String code) {
    if (code == _region) return;
    setState(() {
      _region = code;
      _catalog = _loadCatalog(code);
    });
    unawaited(_save());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text(l10n.streamingSetupTitle)),
      body: FutureBuilder<StreamingPrefs>(
        future: _initial,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return asyncLoadingIndicator();
          }
          if (snap.hasError) {
            return asyncErrorView(
              context,
              snap.error!,
              onRetry: () => setState(_load),
            );
          }
          return _body(context);
        },
      ),
    );
  }

  Widget _body(BuildContext context) {
    // One scroll view for header + providers: on a 320×568 screen a fixed
    // header left the provider list almost no room.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(context)),
              _providerList(context),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _selectedCount(context),
              const SizedBox(height: 2),
              const JustWatchCredit(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            l10n.streamingSetupIntro,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _regionPicker(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: l10n.streamingSearchHint,
              filled: true,
              fillColor: context.colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
      ],
    );
  }

  Widget _selectedCount(BuildContext context) {
    return Text(
      AppLocalizations.of(context)!.streamingSelectedCount(_selected.length),
      style: TextStyle(color: context.colors.textMuted, fontSize: 12),
    );
  }

  Widget _regionPicker(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<StreamingRegion>>(
      future: _regions,
      builder: (context, snap) {
        var regions = snap.data ?? const <StreamingRegion>[];
        // Keep the current region selectable even if the list failed to
        // load or doesn't carry it.
        if (!regions.any((r) => r.code == _region)) {
          regions = [
            StreamingRegion(code: _region!, name: _region!),
            ...regions,
          ];
        }
        return DropdownButtonFormField<String>(
          key: const ValueKey('streaming-region'),
          initialValue: _region,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.streamingRegionLabel,
            isDense: true,
            filled: true,
            fillColor: context.colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: [
            for (final r in regions)
              DropdownMenuItem(
                value: r.code,
                child: Text(r.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (code) {
            if (code != null) _setRegion(code);
          },
        );
      },
    );
  }

  Widget _providerList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<WatchProvider>>(
      // Keyed by region so a region switch shows a spinner, not stale logos.
      key: ValueKey(_region),
      future: _catalog,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: asyncLoadingIndicator(),
          );
        }
        if (snap.hasError) {
          return SliverToBoxAdapter(
            child: asyncErrorView(
              context,
              snap.error!,
              onRetry: () => setState(() {
                _catalog = _loadCatalog(_region!);
              }),
            ),
          );
        }
        final all = snap.data ?? const <WatchProvider>[];
        if (all.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.streamingNoProviders,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
          );
        }
        final shown = _query.isEmpty
            ? all
            : all.where((p) => p.name.toLowerCase().contains(_query)).toList();
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          sliver: SliverList.builder(
            itemCount: shown.length,
            itemBuilder: (context, i) {
              final p = shown[i];
              final selected = _selected.contains(p.id);
              return CheckboxListTile(
                key: ValueKey('provider-${p.id}'),
                value: selected,
                onChanged: (_) => _toggle(p.id),
                controlAffinity: ListTileControlAffinity.trailing,
                activeColor: context.colors.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                secondary: ProviderLogo(provider: p, size: 36, radius: 8),
                title: Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
