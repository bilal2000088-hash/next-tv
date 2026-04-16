import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tv_filme/data/open_api_catalog.dart';
import 'package:tv_filme/l10n/app_localizations.dart';
import 'package:tv_filme/models/media_models.dart';
import 'package:tv_filme/widgets/remote_image.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.title,
    required this.sourceUrl,
  });

  final String title;
  final String sourceUrl;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  Future<void>? _initFuture;
  Future<void>? _channelsFuture;
  String? _error;
  bool _isFullscreen = false;
  String _currentTitle = '';
  String _currentSourceUrl = '';
  final List<LiveChannel> _allChannels = <LiveChannel>[];

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.title;
    _currentSourceUrl = widget.sourceUrl;
    _channelsFuture = _loadChannels();
    _initFuture = _initializePlayer(_currentSourceUrl);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    try {
      final result = await OpenApiCatalog.fetchArabicChannelsPage(
        pageIndex: 0,
        pageSize: 200,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _allChannels
          ..clear()
          ..addAll(result.items);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _allChannels.clear();
      });
    }
  }

  Future<void> _initializePlayer(String sourceUrl) async {
    final previous = _controller;
    final next = VideoPlayerController.networkUrl(
      Uri.parse(sourceUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    setState(() {
      _error = null;
      _controller = next;
    });
    await previous?.dispose();

    try {
      await next.initialize();
      await next.setLooping(false);
      await next.setVolume(1.0);
      await next.play();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _playChannel(LiveChannel channel) async {
    if (channel.streamUrl == _currentSourceUrl) {
      return;
    }
    setState(() {
      _currentTitle = channel.name;
      _currentSourceUrl = channel.streamUrl;
      _initFuture = _initializePlayer(channel.streamUrl);
    });
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  void _restartVideo() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    controller.seekTo(Duration.zero);
    controller.play();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = _controller;
    final canControl = controller != null && controller.value.isInitialized;

    return Scaffold(
      appBar: _isFullscreen ? null : AppBar(title: Text(_currentTitle)),
      body: Row(
        children: [
          if (!_isFullscreen)
            SizedBox(
              width: 240,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF121A30),
                  border: Border(
                    right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: FutureBuilder<void>(
                  future: _channelsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done &&
                        _allChannels.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (_allChannels.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('تعذر تحميل قائمة القنوات'),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final channel = _allChannels[index];
                        final selected = _currentSourceUrl == channel.streamUrl;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.16)
                                : const Color(0xFF19233D),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 1.1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _playChannel(channel),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      width: 44,
                                      height: 28,
                                      child: RemoteImage(
                                        url: channel.thumbnailUrl,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          channel.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          channel.country,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withValues(
                                              alpha: 0.72,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemCount: _allChannels.length,
                    );
                  },
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(_isFullscreen ? 0 : 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _isFullscreen
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF2A2F3C), Color(0xFF1B1F29)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: _isFullscreen ? Colors.black : null,
                  border: _isFullscreen
                      ? null
                      : Border.all(color: const Color(0xFF434A5C), width: 4),
                  boxShadow: _isFullscreen
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x80000000),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: Offset(0, 10),
                          ),
                        ],
                  borderRadius: _isFullscreen
                      ? BorderRadius.zero
                      : BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: EdgeInsets.all(_isFullscreen ? 0 : 10),
                  child: ClipRRect(
                    borderRadius: _isFullscreen
                        ? BorderRadius.zero
                        : BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_error != null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(l10n.playbackFailed(_error!)),
                            ),
                          )
                        else
                          FutureBuilder<void>(
                            future: _initFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                      ConnectionState.done ||
                                  controller == null ||
                                  !controller.value.isInitialized) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              return FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: controller.value.size.width,
                                  height: controller.value.size.height,
                                  child: VideoPlayer(controller),
                                ),
                              );
                            },
                          ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: _tvCircleButton(
                            tooltip: _isFullscreen
                                ? 'الخروج من ملء الشاشة'
                                : 'ملء الشاشة',
                            onPressed: _toggleFullscreen,
                            icon: Icon(
                              _isFullscreen
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xD9192434), Color(0xD90F1725)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                                children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    _currentTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                  ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _tvPillButton(
                                      onPressed: canControl
                                          ? _togglePlayPause
                                          : null,
                                      icon: (controller?.value.isPlaying ?? false)
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      label:
                                          (controller?.value.isPlaying ?? false)
                                          ? l10n.pause
                                          : l10n.play,
                                    ),
                                    const SizedBox(width: 6),
                                    _tvPillButton(
                                      onPressed: canControl
                                          ? _restartVideo
                                          : null,
                                      icon: Icons.replay_rounded,
                                      label: l10n.restart,
                                      primary: false,
                                    ),
                                  ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tvCircleButton({
    required String tooltip,
    required VoidCallback onPressed,
    required Widget icon,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xB3121B2B),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onPressed,
          icon: icon,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _tvPillButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    bool primary = true,
  }) {
    final background = primary
        ? const Color(0xFF2563EB)
        : const Color(0xFF253042);
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        disabledBackgroundColor: background.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
