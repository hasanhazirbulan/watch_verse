import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/responsive.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

class PersonScreen extends StatefulWidget {
  final int personId;
  final String name;
  const PersonScreen({super.key, required this.personId, required this.name});

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  final APIservices _api = APIservices();
  late final Future<Person> _person;
  late final Future<List<MediaItem>> _credits;
  bool _bioExpanded = false;

  @override
  void initState() {
    super.initState();
    _person = _api.getPersonDetails(widget.personId);
    _credits = _api.getPersonCredits(widget.personId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureValueView<Person>(
              future: _person,
              builder: (context, person) => _header(context, person),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(l10n.personKnownForTitle,
                  style:
                      const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            FutureListView<MediaItem>(
              future: _credits,
              emptyBuilder: (context) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.personNoCredits,
                    style: TextStyle(color: context.colors.textSecondary)),
              ),
              builder: (context, items) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                // 3 columns on phones, more on wide windows.
                gridDelegate: const SliverGridDelegateWithAdaptiveCount(
                  compactCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.5,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => PosterCard(item: items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Person p) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 110,
                  height: 165,
                  child: TmdbImage(
                    url: Tmdb.poster(p.profilePath, size: 'w342'),
                    placeholderIcon: Icons.person,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    if (p.knownFor.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(p.knownFor,
                            style: TextStyle(
                                color: context.colors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (p.biography.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.personBiographyTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              p.biography,
              maxLines: _bioExpanded ? null : 5,
              overflow: _bioExpanded ? null : TextOverflow.ellipsis,
              style: TextStyle(
                  color: context.colors.textSecondary, height: 1.45),
            ),
            if (p.biography.length > 260)
              GestureDetector(
                onTap: () => setState(() => _bioExpanded = !_bioExpanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_bioExpanded ? l10n.personShowLess : l10n.personReadMore,
                      style: TextStyle(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
