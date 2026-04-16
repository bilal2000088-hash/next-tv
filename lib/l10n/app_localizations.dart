import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar')];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'تي في فيلم'**
  String get appTitle;

  /// No description provided for @liveChannelsTooltip.
  ///
  /// In ar, this message translates to:
  /// **'القنوات المباشرة'**
  String get liveChannelsTooltip;

  /// No description provided for @popularMovies.
  ///
  /// In ar, this message translates to:
  /// **'أفلام شائعة'**
  String get popularMovies;

  /// No description provided for @featuredChannels.
  ///
  /// In ar, this message translates to:
  /// **'قنوات مباشرة مميزة'**
  String get featuredChannels;

  /// No description provided for @browseLiveChannels.
  ///
  /// In ar, this message translates to:
  /// **'تصفح القنوات المباشرة'**
  String get browseLiveChannels;

  /// No description provided for @heroTitle.
  ///
  /// In ar, this message translates to:
  /// **'تلفزيون وأفلام بأسلوب عصري'**
  String get heroTitle;

  /// No description provided for @heroSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'استكشف محتوى بث مجاني من مصادر مفتوحة مع تجربة مشاهدة سلسة.'**
  String get heroSubtitle;

  /// No description provided for @moviesUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الأفلام غير متاحة حالياً.'**
  String get moviesUnavailable;

  /// No description provided for @channelsUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'القنوات غير متاحة حالياً.'**
  String get channelsUnavailable;

  /// No description provided for @searchChannelsHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن قناة، تصنيف، أو دولة'**
  String get searchChannelsHint;

  /// No description provided for @channelsLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل القنوات من الخادم.'**
  String get channelsLoadError;

  /// No description provided for @liveChannelsTitle.
  ///
  /// In ar, this message translates to:
  /// **'القنوات المباشرة'**
  String get liveChannelsTitle;

  /// No description provided for @playNow.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل الآن'**
  String get playNow;

  /// No description provided for @pause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get pause;

  /// No description provided for @play.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل'**
  String get play;

  /// No description provided for @restart.
  ///
  /// In ar, this message translates to:
  /// **'إعادة من البداية'**
  String get restart;

  /// No description provided for @playbackFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل التشغيل: {error}'**
  String playbackFailed(String error);

  /// No description provided for @loadingMore.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحميل المزيد…'**
  String get loadingMore;

  /// No description provided for @noMoreItems.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد المزيد'**
  String get noMoreItems;

  /// No description provided for @movieGenreFallback.
  ///
  /// In ar, this message translates to:
  /// **'فيلم'**
  String get movieGenreFallback;

  /// No description provided for @channelCategoryFallback.
  ///
  /// In ar, this message translates to:
  /// **'عام'**
  String get channelCategoryFallback;

  /// No description provided for @yearUnknown.
  ///
  /// In ar, this message translates to:
  /// **'غير محدد'**
  String get yearUnknown;

  /// No description provided for @sourceArchive.
  ///
  /// In ar, this message translates to:
  /// **'أرشيف الإنترنت (محتوى مجاني)'**
  String get sourceArchive;

  /// No description provided for @noSearchResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتيجة مطابقة للبحث.'**
  String get noSearchResults;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
