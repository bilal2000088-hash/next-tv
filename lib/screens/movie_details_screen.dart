import 'package:flutter/material.dart';
import 'package:tv_filme/l10n/app_localizations.dart';
import 'package:tv_filme/models/media_models.dart';
import 'package:tv_filme/screens/video_player_screen.dart';
import 'package:tv_filme/screens/web_embed_player_screen.dart';
import 'package:tv_filme/widgets/remote_image.dart';

class MovieDetailsScreen extends StatelessWidget {
  const MovieDetailsScreen({super.key, required this.movie});

  final MovieItem movie;

  bool get _fromArchive =>
      movie.videoUrl.contains('archive.org') ||
      movie.posterUrl.contains('archive.org');
  bool get _isEmbedUrl =>
      movie.videoUrl.contains('vidsrc.') ||
      movie.videoUrl.contains('/embed/');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(movie.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RemoteImage(url: movie.posterUrl),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            movie.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text('${movie.genre} • ${movie.year}'),
          const SizedBox(height: 12),
          Text(movie.description),
          if (_fromArchive) ...[
            const SizedBox(height: 12),
            Text(
              l10n.sourceArchive,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _isEmbedUrl
                      ? WebEmbedPlayerScreen(
                          title: movie.title,
                          url: movie.videoUrl,
                        )
                      : VideoPlayerScreen(
                          title: movie.title,
                          sourceUrl: movie.videoUrl,
                        ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l10n.playNow),
          ),
        ],
      ),
    );
  }
}
