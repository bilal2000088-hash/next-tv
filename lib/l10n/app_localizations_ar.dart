// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'تي في فيلم';

  @override
  String get liveChannelsTooltip => 'القنوات المباشرة';

  @override
  String get popularMovies => 'أفلام شائعة';

  @override
  String get featuredChannels => 'قنوات مباشرة مميزة';

  @override
  String get browseLiveChannels => 'تصفح القنوات المباشرة';

  @override
  String get heroTitle => 'تلفزيون وأفلام بأسلوب عصري';

  @override
  String get heroSubtitle =>
      'استكشف محتوى بث مجاني من مصادر مفتوحة مع تجربة مشاهدة سلسة.';

  @override
  String get moviesUnavailable => 'الأفلام غير متاحة حالياً.';

  @override
  String get channelsUnavailable => 'القنوات غير متاحة حالياً.';

  @override
  String get searchChannelsHint => 'ابحث عن قناة، تصنيف، أو دولة';

  @override
  String get channelsLoadError => 'تعذّر تحميل القنوات من الخادم.';

  @override
  String get liveChannelsTitle => 'القنوات المباشرة';

  @override
  String get playNow => 'تشغيل الآن';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get play => 'تشغيل';

  @override
  String get restart => 'إعادة من البداية';

  @override
  String playbackFailed(String error) {
    return 'فشل التشغيل: $error';
  }

  @override
  String get loadingMore => 'جاري تحميل المزيد…';

  @override
  String get noMoreItems => 'لا يوجد المزيد';

  @override
  String get movieGenreFallback => 'فيلم';

  @override
  String get channelCategoryFallback => 'عام';

  @override
  String get yearUnknown => 'غير محدد';

  @override
  String get sourceArchive => 'أرشيف الإنترنت (محتوى مجاني)';

  @override
  String get noSearchResults => 'لا توجد نتيجة مطابقة للبحث.';
}
