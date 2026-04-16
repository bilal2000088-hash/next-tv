import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv_filme/data/open_api_catalog.dart';
import 'package:tv_filme/l10n/app_localizations.dart';
import 'package:tv_filme/models/media_models.dart';
import 'package:tv_filme/widgets/remote_image.dart';
import 'package:video_player/video_player.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  static const String _prefsLastStreamUrl = 'last_stream_url';
  static const String _prefsLastCountry = 'last_country';
  static const String _prefsLastCategory = 'last_category';

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _selectedChannelItemKey = GlobalKey(debugLabel: 'selected-channel-row');
  final ScrollController _countriesScrollController = ScrollController();
  final GlobalKey _selectedCountryFilterKey = GlobalKey(
    debugLabel: 'selected-country-filter',
  );
  final FocusNode _remoteFocusNode = FocusNode(debugLabel: 'channels-remote');
  static const List<String> _preferredCountryOrder = [
    'السعودية',
    'الإمارات',
    'مصر',
    'قطر',
    'الكويت',
    'البحرين',
    'عُمان',
    'إريتريا',
    'تشاد',
    'الأردن',
    'لبنان',
    'سوريا',
    'العراق',
    'المغرب',
    'الجزائر',
    'تونس',
    'ليبيا',
    'السودان',
    'جنوب السودان',
    'فلسطين',
    'اليمن',
    'موريتانيا',
    'جيبوتي',
    'الصومال',
    'جزر القمر',
  ];

  final List<LiveChannel> _channels = [];
  final List<LiveChannel> _importedChannels = [];
  int _page = 0;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  String selectedCategory = 'الكل';
  /// قيمة التصفية الداخلية؛ العرض للمستخدم: [_allCountriesDisplayLabel].
  static const String _allCountriesFilterValue = 'كل الدول';
  static const String _allCountriesDisplayLabel = 'قنوات كل الدول';
  String selectedCountry = _allCountriesFilterValue;
  static const String _newsFilterLabel = 'قنوات الأخبار';
  static const String _mbcFilterLabel = 'MBC';
  static const String _beinSportFilterLabel = 'beIN Sport';
  bool _isSideUiVisible = false;
  int _remoteSelectedIndex = 0;
  int _remoteFilterIndex = 0;
  int _remoteSection = 2; // 0: filters, 1: channels, 2: player
  Timer? _hideSideUiTimer;
  VideoPlayerController? _playerController;
  Future<void>? _playerInitFuture;
  String? _playerError;
  LiveChannel? _currentChannel;
  bool _isPlayerFullscreen = false;
  static const String _autoM3uUrl = String.fromEnvironment(
    'AUTO_M3U_URL',
    defaultValue: '',
  );
  static const String _autoM3uFilePath = String.fromEnvironment(
    'AUTO_M3U_FILE_PATH',
    defaultValue: '',
  );
  static const String _bundledM3uAssetPath = String.fromEnvironment(
    'BUNDLED_M3U_ASSET_PATH',
    defaultValue: 'assets/channels/app_channels.m3u',
  );
  static const String _iptvMasterPlaylistsPrefix =
      'assets/channels/IPTV-master/playlists/';
  static const List<String> _iptvPreferredTokens = <String>[
    'zz_news_ar',
    'zz_documentaries_ar',
    'saudi_arabia',
    'united_arab_emirates',
    'qatar',
    'kuwait',
    'bahrain',
    'oman',
    'yemen',
    'jordan',
    'palestine',
    'lebanon',
    'syria',
    'iraq',
    'egypt',
    'libya',
    'tunisia',
    'algeria',
    'morocco',
    'sudan',
    'somalia',
    'djibouti',
    'mauritania',
    'comoros',
    'eritrea',
    'chad',
    'south_sudan',
    'sports',
    'sport',
    'bein',
    'bein',
    'alkass',
  ];

  List<LiveChannel> get _allChannelsForView {
    final map = <String, LiveChannel>{};
    for (final channel in [..._importedChannels, ..._channels]) {
      final key = channel.streamUrl.trim().isEmpty
          ? channel.id
          : channel.streamUrl.trim();
      map.putIfAbsent(key, () => channel);
    }
    return map.values.toList();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initAsync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _remoteFocusNode.requestFocus();
      }
    });
  }

  Future<void> _initAsync() async {
    await _restoreLastSelections();
    await _loadInitial();
    await _autoImportM3uIfConfigured();
    await _restoreLastChannelIfPossible();
  }

  @override
  void dispose() {
    _hideSideUiTimer?.cancel();
    _remoteFocusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _countriesScrollController.dispose();
    _playerController?.dispose();
    super.dispose();
  }

  void _showSideUiTemporarily() {
    _hideSideUiTimer?.cancel();
    if (!_isSideUiVisible && !_isPlayerFullscreen) {
      setState(() => _isSideUiVisible = true);
    }
    if (_isPlayerFullscreen) {
      return;
    }
    _hideSideUiTimer = Timer(const Duration(minutes: 1), () {
      if (!mounted || _isPlayerFullscreen) {
        return;
      }
      setState(() => _isSideUiVisible = false);
    });
  }

  void _scrollToRemoteSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      void ensureSelectedVisible() {
        final ctx = _selectedChannelItemKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: 0.35,
          );
        }
      }

      ensureSelectedVisible();
      if (_selectedChannelItemKey.currentContext == null) {
        const itemExtentEstimate = 74.0;
        final maxExtent = _scrollController.position.maxScrollExtent;
        final target = (_remoteSelectedIndex * itemExtentEstimate).clamp(
          0.0,
          maxExtent,
        );
        _scrollController.jumpTo(target);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ensureSelectedVisible();
        });
      }
    });
  }

  void _maybeLoadMoreNearEnd(List<LiveChannel> visible, int index) {
    if (!_hasMore || _loadingMore || _loadingInitial || visible.isEmpty) {
      return;
    }
    const threshold = 4;
    if (index >= visible.length - threshold) {
      _loadMore();
    }
  }

  void _scrollToCountryFilterSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_countriesScrollController.hasClients) {
        return;
      }
      void ensureSelectedVisible() {
        final ctx = _selectedCountryFilterKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: 0.35,
          );
        }
      }

      ensureSelectedVisible();
      if (_selectedCountryFilterKey.currentContext == null) {
        const itemExtentEstimate = 50.0;
        final maxExtent = _countriesScrollController.position.maxScrollExtent;
        final target = (_remoteFilterIndex * itemExtentEstimate).clamp(
          0.0,
          maxExtent,
        );
        _countriesScrollController.jumpTo(target);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ensureSelectedVisible();
        });
      }
    });
  }

  List<String> _remoteFilterOptions(List<String> countries) {
    return <String>[
      ...countries,
      _newsFilterLabel,
      _mbcFilterLabel,
      _beinSportFilterLabel,
    ];
  }

  bool _isNewsChannel(LiveChannel item) {
    final cat = item.category.trim();
    final catLower = cat.toLowerCase();
    if (cat == 'إخباري' ||
        catLower.contains('news') ||
        cat.contains('إخبار') ||
        cat.contains('اخبار')) {
      return true;
    }
    final n = item.name.toLowerCase();
    const hints = <String>[
      'news',
      'جزيرة',
      'jazeera',
      'العربية',
      'الحدث',
      'bbc',
      'cnn',
      'sky news',
      'france 24',
      'euronews',
      'rt ',
      'اخبار',
      'إخبار',
      'خبر',
    ];
    for (final h in hints) {
      if (n.contains(h)) {
        return true;
      }
    }
    return false;
  }

  void _moveRemoteSection(int delta) {
    if (_isPlayerFullscreen) {
      return;
    }
    if (!_isSideUiVisible) {
      setState(() {
        _isSideUiVisible = true;
        _remoteSection = 1;
      });
      return;
    }
    setState(() {
      _remoteSection = (_remoteSection + delta).clamp(0, 2);
    });
  }

  void _selectFilterByRemoteDelta(int delta) {
    final countries = _countries(_allChannelsForView);
    final options = _remoteFilterOptions(countries);
    if (options.isEmpty) {
      return;
    }
    var next = _remoteFilterIndex + delta;
    if (next < 0) {
      next = options.length - 1;
    } else if (next >= options.length) {
      next = 0;
    }
    setState(() {
      _remoteFilterIndex = next;
    });
  }

  Future<void> _selectChannelByRemoteDelta(int delta) async {
    final visible = _filtered(_allChannelsForView);
    if (visible.isEmpty) {
      return;
    }
    var nextIndex = _remoteSelectedIndex + delta;
    if (nextIndex < 0) {
      nextIndex = visible.length - 1;
    } else if (nextIndex >= visible.length) {
      nextIndex = 0;
    }
    setState(() => _remoteSelectedIndex = nextIndex);
    _maybeLoadMoreNearEnd(visible, nextIndex);
    _scrollToRemoteSelection();
  }

  Future<void> _playRemoteSelectedChannel() async {
    final visible = _filtered(_allChannelsForView);
    if (visible.isEmpty) {
      return;
    }
    final selected = _remoteSelectedIndex.clamp(0, visible.length - 1);
    await _playChannel(visible[selected]);
    if (mounted && !_isPlayerFullscreen) {
      setState(() {
        _isSideUiVisible = false;
        _remoteSection = 2;
      });
    }
  }

  KeyEventResult _handleRemoteKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    _showSideUiTemporarily();

    final key = event.logicalKey;
    final label = key.keyLabel.toLowerCase();
    final isVolumeKey = label.contains('volume');
    final isDownKey =
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown ||
        (!isVolumeKey &&
            (label.contains('down') ||
                label.contains('next') ||
                label.contains('channel+') ||
                label.contains('ch+')));
    final isUpKey =
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp ||
        (!isVolumeKey &&
            (label.contains('up') ||
                label.contains('prev') ||
                label.contains('previous') ||
                label.contains('channel-') ||
                label.contains('ch-')));

    if (key == LogicalKeyboardKey.arrowRight) {
      _moveRemoteSection(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveRemoteSection(1);
      return KeyEventResult.handled;
    }

    if (isDownKey) {
      if (_remoteSection == 0) {
        _selectFilterByRemoteDelta(1);
      } else {
        if (!_isSideUiVisible || _remoteSection != 1) {
          setState(() {
            _isSideUiVisible = true;
            _remoteSection = 1;
          });
        }
        _selectChannelByRemoteDelta(1);
      }
      return KeyEventResult.handled;
    }
    if (isUpKey) {
      if (_remoteSection == 0) {
        _selectFilterByRemoteDelta(-1);
      } else {
        if (!_isSideUiVisible || _remoteSection != 1) {
          setState(() {
            _isSideUiVisible = true;
            _remoteSection = 1;
          });
        }
        _selectChannelByRemoteDelta(-1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_remoteSection == 0) {
        final countries = _countries(_allChannelsForView);
        final options = _remoteFilterOptions(countries);
        if (options.isNotEmpty) {
          final selected = _remoteFilterIndex.clamp(0, options.length - 1);
          setState(() => selectedCountry = options[selected]);
          _scrollToCountryFilterSelection();
        }
      } else if (_remoteSection == 1) {
        _playRemoteSelectedChannel();
      } else if (_remoteSection == 2) {
        setState(() => _isPlayerFullscreen = !_isPlayerFullscreen);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.backspace) {
      // Back behavior (TV-like):
      // 1) Exit fullscreen if active.
      // 2) If navigating inside side UI, move focus to player (keep side UI visible).
      // 3) If already on player, then hide side UI.
      if (_isPlayerFullscreen) {
        setState(() => _isPlayerFullscreen = false);
        return KeyEventResult.handled;
      }
      if (_isSideUiVisible && _remoteSection != 2) {
        setState(() => _remoteSection = 2);
        return KeyEventResult.handled;
      }
      setState(() {
        _isSideUiVisible = false;
        _remoteSection = 2;
      });
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (!_hasMore || _loadingMore || _loadingInitial) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _error = null;
    });
    try {
      final result = await OpenApiCatalog.fetchArabicChannelsPage(
        pageIndex: 0,
        pageSize: 100000,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _channels
          ..clear()
          ..addAll(result.items);
        _hasMore = result.hasMore;
        _page = 0;
        _loadingInitial = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _loadingInitial = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final result = await OpenApiCatalog.fetchArabicChannelsPage(
        pageIndex: nextPage,
        pageSize: 20,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _channels.addAll(result.items);
        _hasMore = result.hasMore;
        _page = nextPage;
        _loadingMore = false;
      });
      _scrollToRemoteSelection();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _playChannel(LiveChannel channel) async {
    final visibleBeforePlay = _filtered(_allChannelsForView);
    final selectedIndex = visibleBeforePlay.indexWhere(
      (c) => c.streamUrl.trim() == channel.streamUrl.trim(),
    );
    final previous = _playerController;
    final next = VideoPlayerController.networkUrl(
      Uri.parse(channel.streamUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    setState(() {
      _currentChannel = channel;
      _playerError = null;
      _playerController = next;
      _playerInitFuture = next
          .initialize()
          .then((_) async {
            await next.setLooping(false);
            await next.setVolume(1.0);
            await next.play();
          })
          .catchError((Object error) {
            if (mounted) {
              setState(() {
                _playerError = _buildPlaybackErrorMessage(error);
              });
            }
          });
      if (selectedIndex != -1) {
        _remoteSelectedIndex = selectedIndex;
      }
    });
    await _persistLastPlayed(channel);
    await previous?.dispose();
  }

  Future<void> _persistLastPlayed(LiveChannel channel) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsLastStreamUrl, channel.streamUrl.trim());
      await prefs.setString(_prefsLastCountry, selectedCountry);
      await prefs.setString(_prefsLastCategory, selectedCategory);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _restoreLastSelections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final country = prefs.getString(_prefsLastCountry);
      final category = prefs.getString(_prefsLastCategory);
      if (!mounted) {
        return;
      }
      setState(() {
        if (country != null && country.trim().isNotEmpty) {
          selectedCountry = country;
        }
        if (category != null && category.trim().isNotEmpty) {
          selectedCategory = category;
        }
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _restoreLastChannelIfPossible() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUrl = prefs.getString(_prefsLastStreamUrl)?.trim();
      if (lastUrl == null || lastUrl.isEmpty) {
        _playDefaultIfNeeded();
        return;
      }
      final all = _allChannelsForView;
      if (all.isEmpty) {
        return;
      }
      final match = all.where((c) => c.streamUrl.trim() == lastUrl);
      if (match.isNotEmpty) {
        await _playChannel(match.first);
        return;
      }
      _playDefaultIfNeeded();
    } catch (_) {
      _playDefaultIfNeeded();
    }
  }

  void _playDefaultIfNeeded() {
    if (_currentChannel != null) {
      return;
    }
    final all = _allChannelsForView;
    if (all.isEmpty) {
      return;
    }
    _playChannel(_pickDefaultChannel(all));
  }

  LiveChannel _pickDefaultChannel(List<LiveChannel> channels) {
    // Prefer a sensible default name if available.
    const preferred = 'الجزيرة مباشر';
    final exact = channels.where((c) => c.name.trim() == preferred).toList();
    if (exact.isNotEmpty) {
      return exact.first;
    }
    final contains = channels.where(
      (c) => c.name.toLowerCase().contains(preferred.toLowerCase()),
    );
    if (contains.isNotEmpty) {
      return contains.first;
    }
    return channels.first;
  }

  String _buildPlaybackErrorMessage(Object error) {
    final raw = error.toString();
    final isSourceError = raw.toLowerCase().contains('source error');
    if (isSourceError) {
      return 'مصدر البث غير متاح الآن (الرابط متوقف أو يحتاج تصريح). جرّب قناة أخرى.';
    }
    return raw;
  }

  Future<void> _playNextChannel() async {
    final pool = _filtered(_allChannelsForView);
    if (pool.isEmpty) {
      return;
    }
    if (_currentChannel == null) {
      await _playChannel(pool.first);
      return;
    }
    final currentIndex = pool.indexWhere(
      (item) => item.streamUrl.trim() == _currentChannel!.streamUrl.trim(),
    );
    if (currentIndex == -1) {
      await _playChannel(pool.first);
      return;
    }
    final nextIndex = (currentIndex + 1) % pool.length;
    await _playChannel(pool[nextIndex]);
  }

  Future<void> _onRefresh() async {
    OpenApiCatalog.invalidateChannelsCache();
    setState(() {
      _channels.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadInitial();
  }

  List<LiveChannel> _filtered(List<LiveChannel> items) {
    return items.where((item) {
      final matchCategory =
          selectedCategory == 'الكل' || item.category == selectedCategory;
      final loweredName = item.name.toLowerCase();
      final isMbcChannel = loweredName.contains('mbc');
      final isBeinChannel =
          loweredName.contains('bein') ||
          loweredName.contains('be in') ||
          loweredName.contains('بين');
      final matchCountry = selectedCountry == _allCountriesFilterValue
          ? true
          : selectedCountry == _newsFilterLabel
          ? _isNewsChannel(item)
          : selectedCountry == _mbcFilterLabel
          ? isMbcChannel
          : selectedCountry == _beinSportFilterLabel
          ? isBeinChannel
          : item.country == selectedCountry;
      return matchCategory && matchCountry;
    }).toList();
  }

  List<String> _categories(List<LiveChannel> items) {
    final set = <String>{};
    for (final item in items) {
      if (item.category.trim().isNotEmpty) {
        set.add(item.category);
      }
    }
    final list = set.toList()..sort();
    return ['الكل', ...list];
  }

  List<String> _countries(List<LiveChannel> items) {
    final set = <String>{};
    for (final item in items) {
      if (item.country.trim().isNotEmpty) {
        set.add(item.country);
      }
    }
    final list = set.toList();
    list.sort((a, b) {
      final indexA = _preferredCountryOrder.indexOf(a);
      final indexB = _preferredCountryOrder.indexOf(b);
      final rankA = indexA == -1 ? 999 : indexA;
      final rankB = indexB == -1 ? 999 : indexB;
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }
      return a.compareTo(b);
    });
    return [_allCountriesFilterValue, ...list];
  }

  String _labelForCountryFilter(String country) {
    if (country == _allCountriesFilterValue) {
      return _allCountriesDisplayLabel;
    }
    return country;
  }

  Map<String, String> _countryCodeByName(List<LiveChannel> items) {
    final map = <String, String>{};
    for (final item in items) {
      if (item.country.trim().isEmpty || item.countryCode.trim().isEmpty) {
        continue;
      }
      map.putIfAbsent(item.country, () => item.countryCode);
    }
    return map;
  }

  String _flagFromCountryCode(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.length != 2) {
      return '';
    }
    final first = normalized.codeUnitAt(0);
    final second = normalized.codeUnitAt(1);
    if (first < 65 || first > 90 || second < 65 || second > 90) {
      return '';
    }
    return String.fromCharCode(first + 127397) +
        String.fromCharCode(second + 127397);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final channelsBase = _allChannelsForView;
    final categories = _categories(channelsBase);
    final countries = _countries(channelsBase);
    final countryCodeByName = _countryCodeByName(channelsBase);
    if (!categories.contains(selectedCategory)) {
      selectedCategory = 'الكل';
    }
    if (selectedCountry != _newsFilterLabel &&
        selectedCountry != _mbcFilterLabel &&
        selectedCountry != _beinSportFilterLabel &&
        !countries.contains(selectedCountry)) {
      selectedCountry = _allCountriesFilterValue;
    }
    final filterOptions = _remoteFilterOptions(countries);
    if (_remoteSection != 0) {
      final selectedFilterIndex = filterOptions.indexOf(selectedCountry);
      if (selectedFilterIndex != -1) {
        _remoteFilterIndex = selectedFilterIndex;
      } else {
        _remoteFilterIndex = 0;
      }
    } else if (filterOptions.isNotEmpty) {
      _remoteFilterIndex = _remoteFilterIndex.clamp(0, filterOptions.length - 1);
    } else {
      _remoteFilterIndex = 0;
    }
    final visible = _filtered(channelsBase);
    if (visible.isNotEmpty) {
      _remoteSelectedIndex = _remoteSelectedIndex.clamp(0, visible.length - 1);
    } else {
      _remoteSelectedIndex = 0;
    }

    return Scaffold(
      appBar: null,
      body: Focus(
        focusNode: _remoteFocusNode,
        autofocus: true,
        onKeyEvent: _handleRemoteKey,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A1020), Color(0xFF101A33), Color(0xFF0A1020)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: (_isPlayerFullscreen || !_isSideUiVisible) ? 0 : 468,
                child: (_isPlayerFullscreen || !_isSideUiVisible)
                    ? const SizedBox.shrink()
                    : Row(
                        children: [
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 26,
                            child: _buildFiltersSidebar(
                              l10n,
                              categories,
                              countries,
                              countryCodeByName,
                              isActive: _remoteSection == 0,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 24,
                            child: _buildChannelsListPanel(
                              l10n,
                              visible,
                              countryCodeByName,
                              isActive: _remoteSection == 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ),
              ),
              Expanded(
                child: _buildInlinePlayer(l10n, isActive: _remoteSection == 2),
              ),
              if (!_isPlayerFullscreen && _isSideUiVisible)
                const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersSidebar(
    AppLocalizations l10n,
    List<String> categories,
    List<String> countries,
    Map<String, String> countryCodeByName, {
    required bool isActive,
  }) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xDD121A30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? const Color(0xFF8DC2FF).withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      countries.length > 1
                          ? '$_allCountriesDisplayLabel (${countries.length - 1})'
                          : _allCountriesDisplayLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showCategoryFilterDialog(categories),
                    icon: const Icon(Icons.filter_alt_rounded, size: 16),
                    label: const Text('فلتر'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  controller: _countriesScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ...countries.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final country = entry.value;
                      final selected = country == selectedCountry;
                      final remoteFocused =
                          _remoteSection == 0 && _remoteFilterIndex == idx;
                      final code = countryCodeByName[country] ?? '';
                      final flag = _flagFromCountryCode(code);
                      return Padding(
                        key: selected
                            ? _selectedCountryFilterKey
                            : ValueKey('country-filter-$country'),
                        padding: const EdgeInsets.only(bottom: 6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: remoteFocused
                                ? Border.all(
                                    color: const Color(0xFF8DC2FF),
                                    width: 1.4,
                                  )
                                : null,
                            boxShadow: remoteFocused
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF8DC2FF).withValues(
                                        alpha: 0.30,
                                      ),
                                      blurRadius: 14,
                                      spreadRadius: 0.4,
                                    ),
                                  ]
                                : null,
                          ),
                          child: ChoiceChip(
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(
                                flag.isEmpty
                                    ? _labelForCountryFilter(country)
                                    : '$flag  ${_labelForCountryFilter(country)}',
                              ),
                            ),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => selectedCountry = country);
                              _scrollToCountryFilterSelection();
                            },
                          ),
                        ),
                      );
                    }),
                    Padding(
                      key: selectedCountry == _newsFilterLabel
                          ? _selectedCountryFilterKey
                          : const ValueKey<String>('filter-news'),
                      padding: const EdgeInsets.only(bottom: 6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: (_remoteSection == 0 &&
                                  _remoteFilterIndex == countries.length)
                              ? Border.all(
                                  color: const Color(0xFF8DC2FF),
                                  width: 1.4,
                                )
                              : null,
                          boxShadow: (_remoteSection == 0 &&
                                  _remoteFilterIndex == countries.length)
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF8DC2FF).withValues(
                                      alpha: 0.30,
                                    ),
                                    blurRadius: 14,
                                    spreadRadius: 0.4,
                                  ),
                                ]
                              : null,
                        ),
                        child: ChoiceChip(
                          label: const SizedBox(
                            width: double.infinity,
                            child: Text(_newsFilterLabel),
                          ),
                          selected: selectedCountry == _newsFilterLabel,
                          onSelected: (_) {
                            setState(() => selectedCountry = _newsFilterLabel);
                            _scrollToCountryFilterSelection();
                          },
                        ),
                      ),
                    ),
                    Padding(
                      key: selectedCountry == _mbcFilterLabel
                          ? _selectedCountryFilterKey
                          : const ValueKey<String>('filter-mbc'),
                      padding: const EdgeInsets.only(bottom: 6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: (_remoteSection == 0 &&
                                  _remoteFilterIndex == countries.length + 1)
                              ? Border.all(
                                  color: const Color(0xFF8DC2FF),
                                  width: 1.4,
                                )
                              : null,
                          boxShadow: (_remoteSection == 0 &&
                                  _remoteFilterIndex == countries.length + 1)
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF8DC2FF).withValues(
                                      alpha: 0.30,
                                    ),
                                    blurRadius: 14,
                                    spreadRadius: 0.4,
                                  ),
                                ]
                              : null,
                        ),
                        child: ChoiceChip(
                          label: const SizedBox(
                            width: double.infinity,
                            child: Text(_mbcFilterLabel),
                          ),
                          selected: selectedCountry == _mbcFilterLabel,
                          onSelected: (_) {
                            setState(() => selectedCountry = _mbcFilterLabel);
                            _scrollToCountryFilterSelection();
                          },
                        ),
                      ),
                    ),
                    Padding(
                      key: selectedCountry == _beinSportFilterLabel
                          ? _selectedCountryFilterKey
                          : const ValueKey<String>('filter-bein'),
                      padding: const EdgeInsets.only(bottom: 6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: (_remoteSection == 0 &&
                                  _remoteFilterIndex == countries.length + 2)
                              ? Border.all(
                                  color: const Color(0xFF8DC2FF),
                                  width: 1.4,
                                )
                              : null,
                          boxShadow: (_remoteSection == 0 &&
                                  _remoteFilterIndex == countries.length + 2)
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF8DC2FF).withValues(
                                      alpha: 0.30,
                                    ),
                                    blurRadius: 14,
                                    spreadRadius: 0.4,
                                  ),
                                ]
                              : null,
                        ),
                        child: ChoiceChip(
                          label: const SizedBox(
                            width: double.infinity,
                            child: Text(_beinSportFilterLabel),
                          ),
                          selected: selectedCountry == _beinSportFilterLabel,
                          onSelected: (_) {
                            setState(
                              () => selectedCountry = _beinSportFilterLabel,
                            );
                            _scrollToCountryFilterSelection();
                          },
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
  }

  Future<void> _autoImportM3uIfConfigured() async {
    try {
      List<LiveChannel> parsed = <LiveChannel>[];
      if (_bundledM3uAssetPath.trim().isNotEmpty) {
        try {
          final raw = await rootBundle.loadString(_bundledM3uAssetPath.trim());
          if (raw.trim().isNotEmpty) {
            parsed = _parseM3u(raw);
          }
        } catch (_) {
          // Ignore if bundled asset is missing.
        }
      }
      if (parsed.isEmpty && _bundledM3uAssetPath.trim().isEmpty) {
        parsed = await _loadChannelsFromIptvMasterAssets();
      }
      if (parsed.isEmpty && _autoM3uUrl.trim().isNotEmpty) {
        final res = await http.get(Uri.parse(_autoM3uUrl.trim()));
        if (res.statusCode == 200) {
          parsed = _parseM3u(res.body);
        }
      } else if (parsed.isEmpty && _autoM3uFilePath.trim().isNotEmpty) {
        final file = File(_autoM3uFilePath.trim());
        if (await file.exists()) {
          final content = await file.readAsString();
          parsed = _parseM3u(content);
        }
      }

      if (parsed.isEmpty || !mounted) {
        return;
      }

      setState(() {
        _replaceImportedChannels(parsed);
      });
    } catch (_) {
      // Silent fail: auto import is optional.
    }
  }

  Future<List<LiveChannel>> _loadChannelsFromIptvMasterAssets() async {
    try {
      final manifestRaw = await rootBundle.loadString('AssetManifest.json');
      final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
      final allPlaylistAssets =
          manifest.keys
              .where(
                (k) =>
                    k.startsWith(_iptvMasterPlaylistsPrefix) &&
                    (k.endsWith('.m3u') || k.endsWith('.m3u8')),
              )
              .toList()
            ..sort();

      if (allPlaylistAssets.isEmpty) {
        return <LiveChannel>[];
      }

      // Do not load all IPTV-master playlists, because this can freeze startup.
      final playlistAssets = allPlaylistAssets.where((asset) {
        final normalized = asset.toLowerCase();
        return _iptvPreferredTokens.any(normalized.contains);
      }).toList();
      final selectedAssets = playlistAssets.isEmpty
          ? allPlaylistAssets
          : playlistAssets;

      final merged = <LiveChannel>[];
      for (final asset in selectedAssets) {
        try {
          final raw = await rootBundle.loadString(asset);
          if (raw.trim().isEmpty) {
            continue;
          }
          merged.addAll(_parseM3u(raw));
        } catch (_) {
          // Skip broken asset and continue.
        }
      }
      return _uniqueChannelsByStream(merged);
    } catch (_) {
      return <LiveChannel>[];
    }
  }

  void _replaceImportedChannels(List<LiveChannel> channels) {
    _importedChannels
      ..clear()
      ..addAll(_uniqueChannelsByStream(channels));
  }

  List<LiveChannel> _uniqueChannelsByStream(List<LiveChannel> channels) {
    final map = <String, LiveChannel>{};
    for (final channel in channels) {
      final key = channel.streamUrl.trim().isEmpty
          ? channel.id
          : channel.streamUrl.trim();
      map.putIfAbsent(key, () => channel);
    }
    return map.values.toList();
  }

  List<LiveChannel> _parseM3u(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final parsed = <LiveChannel>[];
    String? pendingName;
    var index = 0;

    for (final line in lines) {
      if (line.startsWith('#EXTINF')) {
        final comma = line.indexOf(',');
        pendingName = comma == -1
            ? 'قناة ${index + 1}'
            : line.substring(comma + 1).trim();
        continue;
      }
      if (line.startsWith('#')) {
        continue;
      }
      if (!(line.startsWith('http://') || line.startsWith('https://'))) {
        continue;
      }

      index += 1;
      final name = (pendingName == null || pendingName.isEmpty)
          ? 'قناة $index'
          : pendingName;
      final category = _guessCategoryFromName(name);
      final avatar = Uri.https('ui-avatars.com', '/api/', <String, String>{
        'name': name,
        'size': '256',
        'bold': 'true',
        'background': '1F2A44',
        'color': 'ffffff',
      }).toString();

      parsed.add(
        LiveChannel(
          id: 'm3u-$index-${name.hashCode}',
          name: name,
          category: category,
          country: _allCountriesFilterValue,
          countryCode: '',
          thumbnailUrl: avatar,
          streamUrl: line,
        ),
      );
      pendingName = null;
    }
    return parsed;
  }

  String _guessCategoryFromName(String name) {
    final value = name.toLowerCase();
    if (value.contains('sport') || value.contains('رياض')) {
      return 'رياضي';
    }
    if (value.contains('news') || value.contains('خبر')) {
      return 'إخباري';
    }
    if (value.contains('kids') ||
        value.contains('طف') ||
        value.contains('spacetoon')) {
      return 'أطفال';
    }
    if (value.contains('quran') ||
        value.contains('ديني') ||
        value.contains('iqraa')) {
      return 'ديني';
    }
    if (value.contains('movie') ||
        value.contains('سينما') ||
        value.contains('aflam')) {
      return 'أفلام';
    }
    return 'عام';
  }

  Future<void> _showCategoryFilterDialog(List<String> categories) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121A30),
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'فلتر التصنيفات',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((category) {
                        final selected = category == selectedCategory;
                        return ChoiceChip(
                          label: Text(category),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => selectedCategory = category);
                            setSheetState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedCategory = 'الكل';
                        });
                        setSheetState(() {});
                      },
                      icon: const Icon(Icons.clear_rounded),
                      label: const Text('إعادة ضبط الفلتر'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInlinePlayer(AppLocalizations l10n, {required bool isActive}) {
    final controller = _playerController;
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF06090F),
          border: _isPlayerFullscreen
              ? null
              : Border.all(
                  color: isActive
                      ? const Color(0xFF8DC2FF).withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.14),
                ),
          borderRadius: BorderRadius.circular(_isPlayerFullscreen ? 0 : 14),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_isPlayerFullscreen ? 0 : 14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_playerError != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.playbackFailed(_playerError!),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _playNextChannel,
                          icon: const Icon(Icons.skip_next_rounded),
                          label: const Text('تشغيل قناة أخرى'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (controller == null)
                _buildElegantLoading(
                  title: 'جاري تجهيز المشغل',
                  subtitle: 'يرجى الانتظار...',
                )
              else
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _isPlayerFullscreen = !_isPlayerFullscreen;
                    });
                  },
                  child: FutureBuilder<void>(
                    future: _playerInitFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done ||
                          !controller.value.isInitialized) {
                        return _buildElegantLoading(
                          title: 'جاري تحميل البث',
                          subtitle: 'يتم الاتصال بالقناة الآن',
                        );
                      }
                      return FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller.value.size.width,
                          height: controller.value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      );
                    },
                  ),
                ),
              if (!_isPlayerFullscreen)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _currentChannel?.name ?? 'قناة مباشرة',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 2),
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
    );
  }

  Widget _buildElegantLoading({
    required String title,
    String? subtitle,
    bool compact = false,
  }) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          minWidth: compact ? 140 : 220,
          maxWidth: compact ? 200 : 320,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 10 : 14,
        ),
        decoration: BoxDecoration(
          color: const Color(0xD918233A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6EA2FF).withValues(alpha: 0.12),
              blurRadius: 18,
              spreadRadius: 0.2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: compact ? 18 : 22,
              height: compact ? 18 : 22,
              child: const CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 10.5 : 11.5,
                        color: Colors.white.withValues(alpha: 0.76),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelsListPanel(
    AppLocalizations l10n,
    List<LiveChannel> visible,
    Map<String, String> countryCodeByName, {
    required bool isActive,
  }) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xDD121A30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? const Color(0xFF8DC2FF).withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'قائمة القنوات',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _onRefresh,
                    tooltip: 'تحديث',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: _buildBodyContent(l10n, visible, countryCodeByName),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(
    AppLocalizations l10n,
    List<LiveChannel> visible,
    Map<String, String> countryCodeByName,
  ) {
    if (_error != null && _channels.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: Text(l10n.channelsLoadError)),
        ],
      );
    }

    if (_loadingInitial && _channels.isEmpty) {
      return _buildElegantLoading(
        title: 'جاري تحميل القنوات',
        subtitle: 'يرجى الانتظار...',
      );
    }

    if (visible.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              _channels.isEmpty ? l10n.channelsLoadError : l10n.noSearchResults,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: visible.length + 1,
      itemBuilder: (context, index) {
        if (index == visible.length) {
          if (_loadingMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _buildElegantLoading(
                title: 'تحميل المزيد',
                subtitle: 'تحديث القائمة',
                compact: true,
              ),
            );
          }
          if (!_hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text(l10n.noMoreItems)),
            );
          }
          return const SizedBox(height: 8);
        }

        final channel = visible[index];
        final selected = _currentChannel?.streamUrl == channel.streamUrl;
        final remoteFocused = _isSideUiVisible && index == _remoteSelectedIndex;
        final countryCode = channel.countryCode.isNotEmpty
            ? channel.countryCode
            : (countryCodeByName[channel.country] ?? '');
        final flag = _flagFromCountryCode(countryCode);
        return Padding(
          key: index == _remoteSelectedIndex
              ? _selectedChannelItemKey
              : ValueKey(channel.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() => _remoteSelectedIndex = index);
              _playChannel(channel);
              _scrollToRemoteSelection();
              if (!_isPlayerFullscreen) {
                setState(() {
                  _isSideUiVisible = false;
                  _remoteSection = 2;
                });
              }
            },
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: remoteFocused ? 1 : 0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) {
                // subtle “pulse” when focus arrives
                final scale = 1.0 + (t * 0.02);
                return AnimatedScale(
                  scale: remoteFocused ? scale : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: child,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF223A63)
                      : remoteFocused
                          ? const Color(0xFF294D80)
                          : const Color(0xFF18243E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected || remoteFocused
                        ? (remoteFocused
                                ? const Color(0xFF8DC2FF)
                                : Theme.of(context).colorScheme.primary)
                            .withValues(alpha: 0.95)
                        : Colors.transparent,
                    width: remoteFocused ? 1.6 : 1.2,
                  ),
                  boxShadow: selected || remoteFocused
                      ? [
                          BoxShadow(
                            color: (remoteFocused
                                    ? const Color(0xFF7FB9FF)
                                    : Theme.of(context).colorScheme.primary)
                                .withValues(alpha: remoteFocused ? 0.28 : 0.22),
                            blurRadius: remoteFocused ? 18 : 14,
                            spreadRadius: remoteFocused ? 0.8 : 0.4,
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 44,
                          height: 28,
                          child: RemoteImage(url: channel.thumbnailUrl),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontSize: remoteFocused ? 13.7 : 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: remoteFocused ? 0.2 : 0,
                              ),
                              child: Text(
                                channel.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              flag.isEmpty
                                  ? '${channel.category} • ${channel.country}'
                                  : '${channel.category} • $flag ${channel.country}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedScale(
                        scale: selected || remoteFocused ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: remoteFocused
                                ? const Color(0xFF8DC2FF)
                                : Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            remoteFocused
                                ? Icons.play_arrow_rounded
                                : Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
