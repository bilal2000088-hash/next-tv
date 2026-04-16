import 'package:flutter/material.dart';
import 'package:tv_filme/data/open_api_catalog.dart';
import 'package:tv_filme/l10n/app_localizations.dart';
import 'package:tv_filme/models/media_models.dart';
import 'package:tv_filme/screens/channels_screen.dart';
import 'package:tv_filme/widgets/media_card.dart';
import 'package:tv_filme/widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<LiveChannel> _featuredChannels = [];
  bool _channelsLoading = true;
  String? _channelsError;

  @override
  void initState() {
    super.initState();
    _loadFeaturedChannels();
  }

  Future<void> _loadFeaturedChannels() async {
    setState(() {
      _channelsLoading = true;
      _channelsError = null;
    });
    try {
      final result = await OpenApiCatalog.fetchArabicChannelsPage(
        pageIndex: 0,
        pageSize: 2,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _featuredChannels = result.items;
        _channelsLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _channelsError = e.toString();
        _channelsLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    OpenApiCatalog.invalidateChannelsCache();
    await _loadFeaturedChannels();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChannelsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.live_tv_rounded),
            tooltip: l10n.liveChannelsTooltip,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _HeroBanner(
                      onOpenChannels: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ChannelsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(title: l10n.featuredChannels),
                    const SizedBox(height: 12),
                    _buildChannelsSection(context, l10n),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelsSection(BuildContext context, AppLocalizations l10n) {
    if (_channelsError != null && _featuredChannels.isEmpty) {
      return _LoadError(l10n.channelsUnavailable);
    }
    if (_channelsLoading && _featuredChannels.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_featuredChannels.isEmpty) {
      return _LoadError(l10n.channelsUnavailable);
    }

    return Column(
      children: _featuredChannels.map((channel) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: MediaCard(
            imageUrl: channel.thumbnailUrl,
            title: channel.name,
            subtitle: '${channel.category} • ${channel.country}',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChannelsScreen(),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onOpenChannels});

  final VoidCallback onOpenChannels;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF396AF4), Color(0xFF2948FF), Color(0xFF6A11CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.heroTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(l10n.heroSubtitle),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onOpenChannels,
            icon: const Icon(Icons.ondemand_video_rounded),
            label: Text(l10n.browseLiveChannels),
          ),
        ],
      ),
    );
  }
}
