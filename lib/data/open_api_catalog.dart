import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tv_filme/models/media_models.dart';

class PaginatedResult<T> {
  const PaginatedResult({required this.items, required this.hasMore});

  final List<T> items;
  final bool hasMore;
}

class OpenApiCatalog {
  OpenApiCatalog._();

  static final Uri _channelsUri =
      Uri.parse('https://iptv-org.github.io/api/channels.json');
  static final Uri _streamsUri =
      Uri.parse('https://iptv-org.github.io/api/streams.json');
  static final Uri _countriesUri =
      Uri.parse('https://iptv-org.github.io/api/countries.json');
  static const String _archiveAdvancedSearchBase =
      'https://archive.org/advancedsearch.php';
  static const String _rapidApiKey = String.fromEnvironment('RAPIDAPI_KEY');
  static const String _rapidApiHost = String.fromEnvironment(
    'RAPIDAPI_HOST',
    defaultValue: 'streaming-availability.p.rapidapi.com',
  );
  static const String _rapidApiMoviesPath = String.fromEnvironment(
    'RAPIDAPI_MOVIES_PATH',
    defaultValue: '/shows/{type}/{id}',
  );
  static const String _rapidApiShowType = String.fromEnvironment(
    'RAPIDAPI_SHOW_TYPE',
    defaultValue: 'movie',
  );
  static const String _rapidApiShowId = String.fromEnvironment(
    'RAPIDAPI_SHOW_ID',
    defaultValue: '11810166',
  );
  static const String _rapidApiSeason = String.fromEnvironment(
    'RAPIDAPI_SEASON',
    defaultValue: '1',
  );
  static const String _rapidApiEpisode = String.fromEnvironment(
    'RAPIDAPI_EPISODE',
    defaultValue: '1',
  );
  static const String _rapidApiQuery = String.fromEnvironment(
    'RAPIDAPI_QUERY',
    defaultValue: 'arabic movie',
  );
  static const String _vidSrcEmbedHost = String.fromEnvironment(
    'VIDSRC_EMBED_HOST',
    defaultValue: 'vidsrc.to',
  );
  static const String _rapidApiIds = String.fromEnvironment(
    'RAPIDAPI_IDS',
    defaultValue: '',
  );
  static const bool _rapidApiStrictMode = bool.fromEnvironment(
    'RAPIDAPI_STRICT_MODE',
    defaultValue: true,
  );

  static const int _maxChannelsCache = 500;
  static const int _moviesPageSize = 12;
  static const _arabicCountryCodes = <String>{
    'AE', 'BH', 'DZ', 'DJ', 'EG', 'ER', 'IQ', 'JO', 'KM', 'KW', 'LB',
    'LY', 'MA', 'MR', 'OM', 'PS', 'QA', 'SA', 'SD', 'SO', 'SS', 'SY',
    'TD', 'TN', 'YE',
  };
  static const _countryCodeToArabicName = <String, String>{
    'AE': 'الإمارات',
    'BH': 'البحرين',
    'DZ': 'الجزائر',
    'DJ': 'جيبوتي',
    'EG': 'مصر',
    'ER': 'إريتريا',
    'IQ': 'العراق',
    'JO': 'الأردن',
    'KM': 'جزر القمر',
    'KW': 'الكويت',
    'LB': 'لبنان',
    'LY': 'ليبيا',
    'MA': 'المغرب',
    'MR': 'موريتانيا',
    'OM': 'عُمان',
    'PS': 'فلسطين',
    'QA': 'قطر',
    'SA': 'السعودية',
    'SD': 'السودان',
    'SO': 'الصومال',
    'SS': 'جنوب السودان',
    'SY': 'سوريا',
    'TD': 'تشاد',
    'TN': 'تونس',
    'YE': 'اليمن',
  };
  static const _categoryToArabic = <String, String>{
    'general': 'عام',
    'sport': 'رياضي',
    'news': 'إخباري',
    'sports': 'رياضي',
    'movies': 'أفلام',
    'entertainment': 'ترفيهي',
    'music': 'موسيقى',
    'kids': 'أطفال',
    'religious': 'ديني',
    'culture': 'ثقافي',
    'documentary': 'وثائقي',
    'series': 'مسلسلات',
    'business': 'اقتصادي',
    'education': 'تعليمي',
    'lifestyle': 'منوع',
    'legislative': 'برلماني',
    'cooking': 'طبخ',
    'auto': 'سيارات',
    'shop': 'تسوق',
    'weather': 'طقس',
    'travel': 'سفر',
  };

  static List<LiveChannel>? _channelsCache;
  static Future<void>? _channelsLoadFuture;
  static List<LiveChannel>? _arabicChannelsCache;
  static Future<void>? _arabicChannelsLoadFuture;
  static Map<String, String>? _countriesNameCache;

  static void invalidateChannelsCache() {
    _channelsCache = null;
    _channelsLoadFuture = null;
    _arabicChannelsCache = null;
    _arabicChannelsLoadFuture = null;
    _countriesNameCache = null;
  }

  static Future<PaginatedResult<LiveChannel>> fetchChannelsPage({
    required int pageIndex,
    required int pageSize,
  }) async {
    await _ensureChannelsCache();
    final cache = _channelsCache ?? [];
    final start = pageIndex * pageSize;
    final items = cache.skip(start).take(pageSize).toList();
    final hasMore = start + items.length < cache.length;
    return PaginatedResult(items: items, hasMore: hasMore);
  }

  static Future<PaginatedResult<LiveChannel>> fetchArabicChannelsPage({
    required int pageIndex,
    required int pageSize,
  }) async {
    await _ensureArabicChannelsCache();
    final cache = _arabicChannelsCache ?? [];
    final start = pageIndex * pageSize;
    final items = cache.skip(start).take(pageSize).toList();
    final hasMore = start + items.length < cache.length;
    return PaginatedResult(items: items, hasMore: hasMore);
  }

  static Future<void> _ensureChannelsCache() async {
    if (_channelsCache != null) {
      return;
    }
    _channelsLoadFuture ??= _loadChannelsCache();
    await _channelsLoadFuture!;
  }

  static Future<void> _loadChannelsCache() async {
    final list = await _fetchChannelsMerged(maxItems: _maxChannelsCache);
    _channelsCache = list;
  }

  static Future<void> _ensureArabicChannelsCache() async {
    if (_arabicChannelsCache != null) {
      return;
    }
    _arabicChannelsLoadFuture ??= _loadArabicChannelsCache();
    await _arabicChannelsLoadFuture!;
  }

  static Future<void> _loadArabicChannelsCache() async {
    final list = await _fetchChannelsMerged(
      maxItems: null,
      arabicOnly: true,
    );
    _arabicChannelsCache = list;
  }

  static Future<List<LiveChannel>> _fetchChannelsMerged({
    required int? maxItems,
    bool arabicOnly = false,
  }) async {
    final countriesMap = await _loadCountriesMap();
    final channelsResponse = await http.get(_channelsUri);
    final streamsResponse = await http.get(_streamsUri);
    if (channelsResponse.statusCode != 200 ||
        streamsResponse.statusCode != 200) {
      throw Exception('Failed to load open channels API');
    }

    final channelsJson = jsonDecode(channelsResponse.body) as List<dynamic>;
    final streamsJson = jsonDecode(streamsResponse.body) as List<dynamic>;

    final channelById = <String, Map<String, dynamic>>{};
    for (final item in channelsJson) {
      final map = item as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        channelById[id] = map;
      }
    }

    final result = <LiveChannel>[];
    for (final item in streamsJson) {
      final map = item as Map<String, dynamic>;
      final channelId = map['channel']?.toString() ?? '';
      final streamUrl = map['url']?.toString() ?? '';
      if (channelId.isEmpty || streamUrl.isEmpty) {
        continue;
      }

      final channel = channelById[channelId];
      if (channel == null) {
        continue;
      }
      if (arabicOnly && !_isArabicChannel(channel)) {
        continue;
      }

      result.add(
        LiveChannel(
          id: channelId,
          name: channel['name']?.toString() ?? 'قناة',
          category: _extractCategory(channel),
          country: _extractCountry(channel, countriesMap),
          countryCode: _extractCountryCode(channel),
          thumbnailUrl: _resolveChannelArtwork(
            name: channel['name']?.toString() ?? 'قناة',
            category: _extractCategory(channel),
            logoUrl: channel['logo']?.toString(),
          ),
          streamUrl: streamUrl,
        ),
      );

      if (maxItems != null && result.length >= maxItems) {
        break;
      }
    }

    return result;
  }

  static String _extractCategory(Map<String, dynamic> channel) {
    if (_isBeinSportsChannel(channel)) {
      return 'رياضي';
    }
    final categories = channel['categories'];
    if (categories is List && categories.isNotEmpty) {
      final raw = categories.first.toString().trim();
      if (raw.isEmpty) {
        return 'عام';
      }
      final normalized = raw.toLowerCase();
      return _categoryToArabic[normalized] ?? raw;
    }
    return 'عام';
  }

  static String _extractCountry(
    Map<String, dynamic> channel,
    Map<String, String> countriesMap,
  ) {
    final countryCode = channel['country']?.toString().toUpperCase().trim() ?? '';
    if (countryCode.isEmpty) {
      return 'غير محدد';
    }
    return _countryCodeToArabicName[countryCode] ??
        countriesMap[countryCode] ??
        countryCode;
  }

  static String _extractCountryCode(Map<String, dynamic> channel) {
    final countryCode = channel['country']?.toString().toUpperCase().trim() ?? '';
    return countryCode;
  }

  static Future<Map<String, String>> _loadCountriesMap() async {
    final cached = _countriesNameCache;
    if (cached != null) {
      return cached;
    }
    try {
      final response = await http.get(_countriesUri);
      if (response.statusCode != 200) {
        _countriesNameCache = <String, String>{};
        return _countriesNameCache!;
      }
      final data = jsonDecode(response.body) as List<dynamic>;
      final map = <String, String>{};
      for (final item in data) {
        final country = item as Map<String, dynamic>;
        final code = country['code']?.toString().toUpperCase().trim() ?? '';
        final name = country['name']?.toString().trim() ?? '';
        if (code.isNotEmpty && name.isNotEmpty) {
          map[code] = name;
        }
      }
      _countriesNameCache = map;
      return map;
    } catch (_) {
      _countriesNameCache = <String, String>{};
      return _countriesNameCache!;
    }
  }

  static String _resolveChannelArtwork({
    required String name,
    required String category,
    String? logoUrl,
  }) {
    final trimmedLogo = logoUrl?.trim() ?? '';
    if (trimmedLogo.isNotEmpty) {
      return trimmedLogo;
    }
    return _buildAvatarUrl(name: name, category: category);
  }

  static String _buildAvatarUrl({
    required String name,
    required String category,
  }) {
    final seed = '$name|$category';
    final palette = <String>[
      '1F6FEB',
      '6F42C1',
      'DB2777',
      'EA580C',
      '059669',
      '0EA5E9',
      '7C3AED',
      'DC2626',
      '16A34A',
      'CA8A04',
    ];
    final color = palette[_stableHash(seed) % palette.length];
    return Uri.https('ui-avatars.com', '/api/', <String, String>{
      'name': name,
      'size': '512',
      'bold': 'true',
      'format': 'png',
      'background': color,
      'color': 'ffffff',
      'rounded': 'false',
    }).toString();
  }

  static int _stableHash(String input) {
    var hash = 0;
    for (final codeUnit in input.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  static bool _isArabicChannel(Map<String, dynamic> channel) {
    if (_isBeinSportsChannel(channel)) {
      return true;
    }

    final countryCode = channel['country']?.toString().toUpperCase() ?? '';
    if (_arabicCountryCodes.contains(countryCode)) {
      return true;
    }

    final languages = channel['languages'];
    if (languages is List) {
      for (final language in languages) {
        if (language is Map<String, dynamic>) {
          final code = language['code']?.toString().toLowerCase() ?? '';
          if (code == 'ara' || code == 'ar') {
            return true;
          }
        } else {
          final value = language.toString().toLowerCase();
          if (value.contains('ara') || value == 'ar') {
            return true;
          }
        }
      }
    }
    return false;
  }

  static bool _isBeinSportsChannel(Map<String, dynamic> channel) {
    final rawName = channel['name']?.toString().toLowerCase() ?? '';
    if (rawName.isEmpty) {
      return false;
    }

    final compact = rawName.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return (compact.contains('beinsports') || compact.contains('beinsport')) &&
        (compact.contains('sport') || compact.contains('sports'));
  }

  static Future<PaginatedResult<MovieItem>> fetchMoviesPage({
    required int pageIndex,
  }) async {
    if (_rapidApiStrictMode) {
      return _fetchMoviesFromRapidApiOrThrow(pageIndex: pageIndex);
    }
    final rapidResult = await _fetchMoviesFromRapidApi(pageIndex: pageIndex);
    if (rapidResult != null) return rapidResult;
    try {
      return await _fetchArchiveMoviesPage(
        pageIndex: pageIndex,
        sort: 'downloads desc',
        arabicPreferred: true,
      );
    } catch (_) {
      return _fetchArchiveMoviesPage(
        pageIndex: pageIndex,
        sort: 'downloads desc',
        arabicPreferred: false,
      );
    }
  }

  static Future<PaginatedResult<MovieItem>> fetchLatestMoviesPage({
    required int pageIndex,
  }) async {
    if (_rapidApiStrictMode) {
      return _fetchMoviesFromRapidApiOrThrow(pageIndex: pageIndex);
    }
    final rapidResult = await _fetchMoviesFromRapidApi(pageIndex: pageIndex);
    if (rapidResult != null) return rapidResult;
    try {
      return await _fetchArchiveMoviesPage(
        pageIndex: pageIndex,
        sort: 'publicdate desc',
        arabicPreferred: true,
      );
    } catch (_) {
      return _fetchArchiveMoviesPage(
        pageIndex: pageIndex,
        sort: 'publicdate desc',
        arabicPreferred: false,
      );
    }
  }

  static Future<PaginatedResult<MovieItem>> _fetchArchiveMoviesPage({
    required int pageIndex,
    required String sort,
    required bool arabicPreferred,
  }) async {
    final query = arabicPreferred
        ? 'mediatype:(movies) AND (language:(ara) OR subject:(arabic))'
        : 'mediatype:(movies)';
    final encodedQuery = Uri.encodeQueryComponent(query);
    final encodedSort = Uri.encodeQueryComponent(sort);
    final uri = Uri.parse(
      '$_archiveAdvancedSearchBase'
      '?q=$encodedQuery'
      '&fl[]=identifier&fl[]=title&fl[]=description&fl[]=year'
      '&sort[]=$encodedSort'
      '&rows=$_moviesPageSize&page=${pageIndex + 1}'
      '&output=json',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load movies API');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final resp = body['response'] as Map<String, dynamic>?;
    final docs = resp?['docs'] as List<dynamic>? ?? [];
    final numFound = (resp?['numFound'] as num?)?.toInt() ?? 0;
    final start = (resp?['start'] as num?)?.toInt() ?? 0;
    final hasMore = start + docs.length < numFound;

    final futures = docs.map((d) {
      return _movieFromArchiveDoc(d as Map<String, dynamic>);
    });
    final resolved = await Future.wait(futures);
    final items = resolved.whereType<MovieItem>().toList();
    return PaginatedResult(items: items, hasMore: hasMore);
  }

  static Future<PaginatedResult<MovieItem>?> _fetchMoviesFromRapidApi({
    required int pageIndex,
  }) async {
    if (_rapidApiKey.isEmpty || _rapidApiHost.isEmpty) {
      return null;
    }

    try {
      final uri = _buildRapidApiMoviesUri(pageIndex: pageIndex);

      final response = await http.get(
        uri,
        headers: <String, String>{
          'x-rapidapi-key': _rapidApiKey,
          'x-rapidapi-host': _rapidApiHost,
        },
      );
      if (response.statusCode != 200) {
        return null;
      }

      final body = jsonDecode(response.body);
      final rawItems = _extractItemList(body);
      if (rawItems.isEmpty) {
        return null;
      }

      final items = <MovieItem>[];
      for (final raw in rawItems) {
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        final title = _pickString(raw, <String>['title', 'name', 'l', 't']);
        final directVideoUrl = _pickString(
          raw,
          <String>['videoUrl', 'streamUrl', 'url', 'playUrl', 'embedUrl'],
        );
        final fallbackEmbedUrl = _buildVidSrcUrlFromRaw(raw);
        final videoUrl = directVideoUrl.isNotEmpty
            ? directVideoUrl
            : fallbackEmbedUrl;
        if (title.isEmpty || videoUrl.isEmpty) {
          continue;
        }
        final posterUrl = _pickPosterUrl(raw);
        final year = _pickString(raw, <String>['year', 'releaseYear', 'y']);
        final description = _pickString(
          raw,
          <String>['description', 'plot', 'overview'],
        );
        final id = _pickString(raw, <String>['id', 'imdbId', 'tconst']);

        items.add(
          MovieItem(
            id: id.isEmpty ? title : id,
            title: title,
            genre: 'فيلم',
            year: year.isEmpty ? 'غير محدد' : year,
            posterUrl: posterUrl.isEmpty
                ? 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=1000'
                : posterUrl,
            videoUrl: videoUrl,
            description: description.isEmpty
                ? 'فيلم من مزود RapidAPI.'
                : description,
          ),
        );
      }
      if (items.isEmpty) {
        return null;
      }

      return PaginatedResult(
        items: items,
        hasMore: rawItems.length >= _moviesPageSize,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<PaginatedResult<MovieItem>> _fetchMoviesFromRapidApiOrThrow({
    required int pageIndex,
  }) async {
    if (_rapidApiKey.isEmpty || _rapidApiHost.isEmpty) {
      throw Exception(
        'RapidAPI settings are missing. Run with --dart-define=RAPIDAPI_KEY and --dart-define=RAPIDAPI_HOST.',
      );
    }
    final result = await _fetchMoviesFromRapidApi(pageIndex: pageIndex);
    if (result == null || result.items.isEmpty) {
      throw Exception(
        'RapidAPI returned no playable movies. Verify RAPIDAPI_MOVIES_PATH and endpoint response fields.',
      );
    }
    return result;
  }

  static List<dynamic> _extractItemList(dynamic body) {
    if (body is List<dynamic>) {
      return body;
    }
    if (body is! Map<String, dynamic>) {
      return const [];
    }
    if (body.containsKey('title') || body.containsKey('imdbId')) {
      return <dynamic>[body];
    }
    final keys = <String>[
      'results',
      'items',
      'data',
      'd',
      'movies',
      'list',
    ];
    for (final key in keys) {
      final value = body[key];
      if (value is List<dynamic>) {
        return value;
      }
      if (value is Map<String, dynamic>) {
        final asList = value.values.toList();
        if (asList.isNotEmpty) {
          return asList;
        }
      }
    }
    return const [];
  }

  static Uri _buildRapidApiMoviesUri({required int pageIndex}) {
    final ids = _rapidApiIds
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (_rapidApiMoviesPath.contains('{type}') &&
        _rapidApiMoviesPath.contains('{id}') &&
        _rapidApiShowId.isNotEmpty) {
      final resolvedPath = _rapidApiMoviesPath
          .replaceAll('{type}', _rapidApiShowType)
          .replaceAll('{id}', _rapidApiShowId);
      return Uri.https(_rapidApiHost, resolvedPath);
    }

    if (_rapidApiMoviesPath.contains('%7Btype%7D') &&
        _rapidApiMoviesPath.contains('%7Bid%7D') &&
        _rapidApiShowId.isNotEmpty) {
      final resolvedPath = _rapidApiMoviesPath
          .replaceAll('%7Btype%7D', _rapidApiShowType)
          .replaceAll('%7Bid%7D', _rapidApiShowId);
      return Uri.https(_rapidApiHost, resolvedPath);
    }

    if (_rapidApiMoviesPath.contains('/title/type') && ids.isNotEmpty) {
      return Uri.https(_rapidApiHost, _rapidApiMoviesPath, <String, String>{
        'ids': ids.join(','),
      });
    }

    return Uri.https(_rapidApiHost, _rapidApiMoviesPath, <String, String>{
      'query': _rapidApiQuery,
      'limit': '$_moviesPageSize',
      'page': '${pageIndex + 1}',
    });
  }

  static String _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) {
        continue;
      }
      final str = value.toString().trim();
      if (str.isNotEmpty && str != 'null') {
        return str;
      }
    }
    return '';
  }

  static String _pickPosterUrl(Map<String, dynamic> map) {
    final direct = _pickString(
      map,
      <String>['posterUrl', 'imageUrl', 'image', 'poster', 'thumbnail'],
    );
    if (direct.isNotEmpty) {
      return direct;
    }
    final i = map['i'];
    if (i is Map<String, dynamic>) {
      return _pickString(i, <String>['imageUrl', 'url']);
    }
    return '';
  }

  static String _buildVidSrcUrlFromRaw(Map<String, dynamic> map) {
    final showType = _pickString(map, <String>['type', 'showType']).toLowerCase();
    final isSeries = showType.contains('series') ||
        showType.contains('show') ||
        _rapidApiShowType.toLowerCase() == 'series' ||
        _rapidApiShowType.toLowerCase() == 'tv';
    final season = _pickString(map, <String>['season', 's']);
    final episode = _pickString(map, <String>['episode', 'e']);

    final imdbId = _normalizeImdbId(
      _pickString(map, <String>['imdbId', 'imdb_id', 'tconst']),
    );
    if (imdbId.isNotEmpty) {
      if (isSeries) {
        return Uri.https(
          _vidSrcEmbedHost,
          '/embed/tv/imdb-$imdbId/${season.isEmpty ? _rapidApiSeason : season}/${episode.isEmpty ? _rapidApiEpisode : episode}',
        ).toString();
      }
      return Uri.https(_vidSrcEmbedHost, '/embed/movie/imdb-$imdbId').toString();
    }

    final tmdbId = _pickString(
      map,
      <String>['tmdbId', 'tmdb_id', 'id'],
    );
    if (tmdbId.isNotEmpty) {
      if (isSeries) {
        return Uri.https(
          _vidSrcEmbedHost,
          '/embed/tv/tmdb-$tmdbId/${season.isEmpty ? _rapidApiSeason : season}/${episode.isEmpty ? _rapidApiEpisode : episode}',
        ).toString();
      }
      return Uri.https(_vidSrcEmbedHost, '/embed/movie/tmdb-$tmdbId').toString();
    }
    return '';
  }

  static String _normalizeImdbId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return '';
    }
    if (value.startsWith('tt')) {
      return value;
    }
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return '';
    }
    return 'tt$digits';
  }

  static Future<MovieItem?> _movieFromArchiveDoc(
    Map<String, dynamic> doc,
  ) async {
    final id = doc['identifier']?.toString() ?? '';
    if (id.isEmpty) {
      return null;
    }

    final title = doc['title']?.toString() ?? 'بدون عنوان';
    final year = _formatYear(doc['year']);
    var description = doc['description']?.toString() ?? '';
    if (description.isEmpty) {
      description = 'فيلم من أرشيف الإنترنت المفتوح.';
    }

    final metaUri = Uri.parse('https://archive.org/metadata/$id');
    final metaRes = await http.get(metaUri);
    if (metaRes.statusCode != 200) {
      return null;
    }

    final meta = jsonDecode(metaRes.body) as Map<String, dynamic>;
    final files = meta['files'] as List<dynamic>?;
    final videoUrl = _pickBestMp4(id, files);
    if (videoUrl == null) {
      return null;
    }

    final posterUrl = 'https://archive.org/services/img/$id';

    return MovieItem(
      id: id,
      title: title,
      genre: 'فيلم',
      year: year,
      posterUrl: posterUrl,
      videoUrl: videoUrl,
      description: description,
    );
  }

  static String _formatYear(dynamic year) {
    if (year == null) {
      return 'غير محدد';
    }
    if (year is List && year.isNotEmpty) {
      return year.first.toString();
    }
    return year.toString();
  }

  static String? _pickBestMp4(String identifier, List<dynamic>? files) {
    if (files == null) {
      return null;
    }

    final candidates = <({String name, int size})>[];
    for (final item in files) {
      final m = item as Map<String, dynamic>;
      final name = m['name']?.toString() ?? '';
      if (!name.toLowerCase().endsWith('.mp4')) {
        continue;
      }
      final lower = name.toLowerCase();
      if (lower.contains('hls') || lower.contains('segment')) {
        continue;
      }
      final size = int.tryParse(m['size']?.toString() ?? '') ?? 0;
      candidates.add((name: name, size: size));
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) => a.size.compareTo(b.size));
    final name = candidates.first.name;
    return Uri(
      scheme: 'https',
      host: 'archive.org',
      pathSegments: ['download', identifier, name],
    ).toString();
  }
}
