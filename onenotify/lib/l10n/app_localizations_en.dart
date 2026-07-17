// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get exitTitle => 'Exit OneNotify';

  @override
  String get exitConfirm => 'Are you sure you want to exit the app?';

  @override
  String get cancel => 'Cancel';

  @override
  String get exit => 'Exit';

  @override
  String get notifications => 'Notifications';

  @override
  String get tracked => 'Tracked';

  @override
  String get justNow => 'Just now';

  @override
  String secondsAgo(int count) {
    return '${count}s ago';
  }

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mins ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get clearTimelineTitle => 'Clear Timeline?';

  @override
  String get clearTimelineConfirm =>
      'Are you sure you want to delete all saved notifications? This action cannot be undone.';

  @override
  String get clearAll => 'Clear All';

  @override
  String get timelineCleared => 'Timeline cleared successfully.';

  @override
  String get active => 'ACTIVE';

  @override
  String get clearTimelineTooltip => 'Clear Timeline';

  @override
  String get unifiedNotificationCenter => 'Unified Notification Center';

  @override
  String get batteryWarningTitle =>
      '⚠️ Battery Exemption Required for Background Tracking.';

  @override
  String get batteryWarningTitleSettings =>
      '⚠️ Open Android Battery Settings to Whitelist OneNotify';

  @override
  String get batteryWarningDesc =>
      'Tap here to allow OneNotify to run continuously in the background.';

  @override
  String get batteryWarningDescSettings =>
      'OEM override blocked the quick dialog. Tap here to open Settings -> OneNotify -> Unrestricted.';

  @override
  String get silentHubTitle => 'Silent Hub';

  @override
  String get silentHubDesc =>
      'No important notifications captured yet.\nIncoming updates will appear here dynamically.';

  @override
  String notificationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications',
      one: '1 notification',
    );
    return '$_temp0';
  }

  @override
  String couldNotOpenApp(String packageName) {
    return 'Could not open application \'$packageName\'.';
  }

  @override
  String appNotInstalled(String packageName) {
    return 'Application \'$packageName\' is not currently installed.';
  }

  @override
  String get couldNotOpenAppDirectly =>
      'Could not open this application directly.';

  @override
  String get invalidAppPackage => 'Invalid app package identifier.';

  @override
  String get purgeAll => 'Purge All';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get trackedApplicationsTitle => 'Tracked Applications';

  @override
  String get trackedApplicationsDesc =>
      'Select which installed apps OneNotify is allowed to intercept and store in real-time.';

  @override
  String get searchHint => 'Search installed apps...';

  @override
  String get noUserAppsFound => 'No user apps found.';

  @override
  String noAppsMatching(String query) {
    return 'No apps matching \"$query\"';
  }

  @override
  String get autoDismissTooltipOn =>
      'Auto-Dismiss ON (Wiped from Android status bar)';

  @override
  String get autoDismissTooltipOff =>
      'Auto-Dismiss OFF (Normal status bar alerts)';

  @override
  String get ignoreBatteryRestrictions => 'Ignore Battery Restrictions';

  @override
  String get enableRealTimeCapture => 'Enable Real-Time Capture';

  @override
  String get batteryExemptionSubtitle =>
      'To prevent Android OS from killing background capture when your phone screen is turned off, please exempt OneNotify from battery optimization.';

  @override
  String get notificationAccessSubtitle =>
      'To capture and unify messages from WhatsApp, Gmail, Telegram, and Outlook into your timeline, OneNotify needs Special Notification Access.';

  @override
  String get allowBatteryExemption => 'Allow Battery Exemption';

  @override
  String get grantNotificationAccess => 'Grant Notification Access';

  @override
  String get batteryStep1Title => 'Tap \"Allow Battery Exemption\"';

  @override
  String get batteryStep1Desc =>
      'We will prompt Android\'s quick whitelist dialog directly.';

  @override
  String get batteryStep2Title => 'Tap \"Allow\" on the Dialog';

  @override
  String get batteryStep2Desc =>
      'Confirm the prompt so OneNotify stays active 24/7 in the background.';

  @override
  String get batteryStep3Title => 'Continuous Capture Ready';

  @override
  String get batteryStep3Desc =>
      'Your timeline will now capture alerts even overnight while sleeping.';

  @override
  String get notificationStep1Title => 'Tap \"Grant Notification Access\"';

  @override
  String get notificationStep1Desc =>
      'We will take you directly to Android\'s Special Access screen.';

  @override
  String get notificationStep2Title => 'Find OneNotify & Turn Switch ON';

  @override
  String get notificationStep2Desc =>
      'Locate OneNotify in the list and toggle the switch to active.';

  @override
  String get notificationStep3Title => 'Press Back to Return';

  @override
  String get notificationStep3Desc =>
      'Once enabled, return right here. We will connect automatically!';

  @override
  String get checkStatusAgain => 'I already enabled it — Check status again';

  @override
  String get defaultAppLabel => 'App';
}
