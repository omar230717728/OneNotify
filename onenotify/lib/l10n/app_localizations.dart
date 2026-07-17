import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @exitTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit OneNotify'**
  String get exitTitle;

  /// No description provided for @exitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit the app?'**
  String get exitConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @tracked.
  ///
  /// In en, this message translates to:
  /// **'Tracked'**
  String get tracked;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @secondsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}s ago'**
  String secondsAgo(int count);

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min ago} other{{count} mins ago}}'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String daysAgo(int count);

  /// No description provided for @clearTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Timeline?'**
  String get clearTimelineTitle;

  /// No description provided for @clearTimelineConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all saved notifications? This action cannot be undone.'**
  String get clearTimelineConfirm;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @timelineCleared.
  ///
  /// In en, this message translates to:
  /// **'Timeline cleared successfully.'**
  String get timelineCleared;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get active;

  /// No description provided for @clearTimelineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear Timeline'**
  String get clearTimelineTooltip;

  /// No description provided for @unifiedNotificationCenter.
  ///
  /// In en, this message translates to:
  /// **'Unified Notification Center'**
  String get unifiedNotificationCenter;

  /// No description provided for @batteryWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Battery Exemption Required for Background Tracking.'**
  String get batteryWarningTitle;

  /// No description provided for @batteryWarningTitleSettings.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Open Android Battery Settings to Whitelist OneNotify'**
  String get batteryWarningTitleSettings;

  /// No description provided for @batteryWarningDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap here to allow OneNotify to run continuously in the background.'**
  String get batteryWarningDesc;

  /// No description provided for @batteryWarningDescSettings.
  ///
  /// In en, this message translates to:
  /// **'OEM override blocked the quick dialog. Tap here to open Settings -> OneNotify -> Unrestricted.'**
  String get batteryWarningDescSettings;

  /// No description provided for @silentHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Silent Hub'**
  String get silentHubTitle;

  /// No description provided for @silentHubDesc.
  ///
  /// In en, this message translates to:
  /// **'No important notifications captured yet.\nIncoming updates will appear here dynamically.'**
  String get silentHubDesc;

  /// No description provided for @notificationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 notification} other{{count} notifications}}'**
  String notificationsCount(int count);

  /// No description provided for @couldNotOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Could not open application \'{packageName}\'.'**
  String couldNotOpenApp(String packageName);

  /// No description provided for @appNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Application \'{packageName}\' is not currently installed.'**
  String appNotInstalled(String packageName);

  /// No description provided for @couldNotOpenAppDirectly.
  ///
  /// In en, this message translates to:
  /// **'Could not open this application directly.'**
  String get couldNotOpenAppDirectly;

  /// No description provided for @invalidAppPackage.
  ///
  /// In en, this message translates to:
  /// **'Invalid app package identifier.'**
  String get invalidAppPackage;

  /// No description provided for @purgeAll.
  ///
  /// In en, this message translates to:
  /// **'Purge All'**
  String get purgeAll;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @trackedApplicationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tracked Applications'**
  String get trackedApplicationsTitle;

  /// No description provided for @trackedApplicationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Select which installed apps OneNotify is allowed to intercept and store in real-time.'**
  String get trackedApplicationsDesc;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search installed apps...'**
  String get searchHint;

  /// No description provided for @noUserAppsFound.
  ///
  /// In en, this message translates to:
  /// **'No user apps found.'**
  String get noUserAppsFound;

  /// No description provided for @noAppsMatching.
  ///
  /// In en, this message translates to:
  /// **'No apps matching \"{query}\"'**
  String noAppsMatching(String query);

  /// No description provided for @autoDismissTooltipOn.
  ///
  /// In en, this message translates to:
  /// **'Auto-Dismiss ON (Wiped from Android status bar)'**
  String get autoDismissTooltipOn;

  /// No description provided for @autoDismissTooltipOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-Dismiss OFF (Normal status bar alerts)'**
  String get autoDismissTooltipOff;

  /// No description provided for @ignoreBatteryRestrictions.
  ///
  /// In en, this message translates to:
  /// **'Ignore Battery Restrictions'**
  String get ignoreBatteryRestrictions;

  /// No description provided for @enableRealTimeCapture.
  ///
  /// In en, this message translates to:
  /// **'Enable Real-Time Capture'**
  String get enableRealTimeCapture;

  /// No description provided for @batteryExemptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'To prevent Android OS from killing background capture when your phone screen is turned off, please exempt OneNotify from battery optimization.'**
  String get batteryExemptionSubtitle;

  /// No description provided for @notificationAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'To capture and unify messages from WhatsApp, Gmail, Telegram, and Outlook into your timeline, OneNotify needs Special Notification Access.'**
  String get notificationAccessSubtitle;

  /// No description provided for @allowBatteryExemption.
  ///
  /// In en, this message translates to:
  /// **'Allow Battery Exemption'**
  String get allowBatteryExemption;

  /// No description provided for @grantNotificationAccess.
  ///
  /// In en, this message translates to:
  /// **'Grant Notification Access'**
  String get grantNotificationAccess;

  /// No description provided for @batteryStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Allow Battery Exemption\"'**
  String get batteryStep1Title;

  /// No description provided for @batteryStep1Desc.
  ///
  /// In en, this message translates to:
  /// **'We will prompt Android\'s quick whitelist dialog directly.'**
  String get batteryStep1Desc;

  /// No description provided for @batteryStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Allow\" on the Dialog'**
  String get batteryStep2Title;

  /// No description provided for @batteryStep2Desc.
  ///
  /// In en, this message translates to:
  /// **'Confirm the prompt so OneNotify stays active 24/7 in the background.'**
  String get batteryStep2Desc;

  /// No description provided for @batteryStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Continuous Capture Ready'**
  String get batteryStep3Title;

  /// No description provided for @batteryStep3Desc.
  ///
  /// In en, this message translates to:
  /// **'Your timeline will now capture alerts even overnight while sleeping.'**
  String get batteryStep3Desc;

  /// No description provided for @notificationStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Grant Notification Access\"'**
  String get notificationStep1Title;

  /// No description provided for @notificationStep1Desc.
  ///
  /// In en, this message translates to:
  /// **'We will take you directly to Android\'s Special Access screen.'**
  String get notificationStep1Desc;

  /// No description provided for @notificationStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Find OneNotify & Turn Switch ON'**
  String get notificationStep2Title;

  /// No description provided for @notificationStep2Desc.
  ///
  /// In en, this message translates to:
  /// **'Locate OneNotify in the list and toggle the switch to active.'**
  String get notificationStep2Desc;

  /// No description provided for @notificationStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Press Back to Return'**
  String get notificationStep3Title;

  /// No description provided for @notificationStep3Desc.
  ///
  /// In en, this message translates to:
  /// **'Once enabled, return right here. We will connect automatically!'**
  String get notificationStep3Desc;

  /// No description provided for @checkStatusAgain.
  ///
  /// In en, this message translates to:
  /// **'I already enabled it — Check status again'**
  String get checkStatusAgain;

  /// No description provided for @defaultAppLabel.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get defaultAppLabel;
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
      <String>['ar', 'en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
