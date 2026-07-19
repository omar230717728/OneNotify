// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get exitTitle => 'الخروج من OneNotify';

  @override
  String get exitConfirm => 'هل أنت متأكد أنك تريد الخروج من التطبيق؟';

  @override
  String get cancel => 'إلغاء';

  @override
  String get exit => 'خروج';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get tracked => 'المتتبعة';

  @override
  String get justNow => 'الآن';

  @override
  String secondsAgo(int count) {
    return 'قبل $count ثانية';
  }

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count دقيقة',
      few: 'قبل $count دقائق',
      two: 'قبل دقيقتين',
      one: 'قبل دقيقة',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count ساعة',
      few: 'قبل $count ساعات',
      two: 'قبل ساعتين',
      one: 'قبل ساعة',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count يوم',
      few: 'قبل $count أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
    );
    return '$_temp0';
  }

  @override
  String get clearTimelineTitle => 'مسح السجل الزمني؟';

  @override
  String get clearTimelineConfirm =>
      'هل أنت متأكد أنك تريد حذف جميع الإشعارات المحفوظة؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get clearAll => 'مسح الكل';

  @override
  String get timelineCleared => 'تم مسح السجل الزمني بنجاح.';

  @override
  String get active => 'نشط';

  @override
  String get clearTimelineTooltip => 'مسح السجل الزمني';

  @override
  String get unifiedNotificationCenter => 'مركز الإشعارات الموحد';

  @override
  String get batteryWarningTitle =>
      '⚠️ مطلوب استثناء البطارية للتتبع في الخلفية.';

  @override
  String get batteryWarningTitleSettings =>
      '⚠️ افتح إعدادات بطارية أندرويد لإدراج OneNotify في القائمة البيضاء';

  @override
  String get batteryWarningDesc =>
      'انقر هنا للسماح لـ OneNotify بالعمل باستمرار في الخلفية.';

  @override
  String get batteryWarningDescSettings =>
      'تجاوز OEM حظر الحوار السريع. انقر هنا لفتح الإعدادات -> OneNotify -> غير مقيد.';

  @override
  String get silentHubTitle => 'مركز هادئ';

  @override
  String get silentHubDesc =>
      'لم يتم التقاط أي إشعارات مهمة بعد.\nستظهر التحديثات الواردة هنا ديناميكيًا.';

  @override
  String notificationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إشعار',
      few: '$count إشعارات',
      two: 'إشعاران',
      one: 'إشعار واحد',
    );
    return '$_temp0';
  }

  @override
  String couldNotOpenApp(String packageName) {
    return 'تعذر فتح التطبيق \'$packageName\'.';
  }

  @override
  String appNotInstalled(String packageName) {
    return 'التطبيق \'$packageName\' غير مثبت حاليًا.';
  }

  @override
  String get couldNotOpenAppDirectly => 'تعذر فتح هذا التطبيق مباشرة.';

  @override
  String get invalidAppPackage => 'معرف حزمة التطبيق غير صالح.';

  @override
  String get purgeAll => 'حذف الكل';

  @override
  String get dismiss => 'تجاهل';

  @override
  String get trackedApplicationsTitle => 'التطبيقات المتتبعة';

  @override
  String get trackedApplicationsDesc =>
      'حدد التطبيقات المثبتة التي يسمح لـ OneNotify باعتراضها وتخزينها في الوقت الفعلي.';

  @override
  String get searchHint => 'البحث في التطبيقات المثبتة...';

  @override
  String get noUserAppsFound => 'لم يتم العثور على تطبيقات مستخدم.';

  @override
  String noAppsMatching(String query) {
    return 'لا توجد تطبيقات تطابق \"$query\"';
  }

  @override
  String get autoDismissTooltipOn =>
      'التجاهل التلقائي مفعل (تم مسحه من شريط حالة أندرويد)';

  @override
  String get autoDismissTooltipOff =>
      'التجاهل التلقائي معطل (تنبيهات شريط الحالة العادية)';

  @override
  String get ignoreBatteryRestrictions => 'تجاهل قيود البطارية';

  @override
  String get enableRealTimeCapture => 'تمكين الالتقاط في الوقت الفعلي';

  @override
  String get batteryExemptionSubtitle =>
      'لمنع نظام التشغيل أندرويد من إيقاف عملية الالتقاط في الخلفية عند إيقاف تشغيل شاشة الهاتف، يرجى استثناء OneNotify من تحسين البطارية.';

  @override
  String get notificationAccessSubtitle =>
      'لالتقاط الرسائل وتوحيدها من واتساب وجيميل وتيليجرام وأوتلوك في سجلك الزمني، يحتاج OneNotify إلى إذن وصول خاص للإشعارات.';

  @override
  String get allowBatteryExemption => 'السماح باستثناء البطارية';

  @override
  String get grantNotificationAccess => 'منح إذن الوصول للإشعارات';

  @override
  String get batteryStep1Title => 'انقر فوق \"السماح باستثناء البطارية\"';

  @override
  String get batteryStep1Desc =>
      'سنعرض حوار القائمة البيضاء السريع لنظام أندرويد مباشرة.';

  @override
  String get batteryStep2Title => 'انقر فوق \"السماح\" في مربع الحوار';

  @override
  String get batteryStep2Desc =>
      'أكد المطالبة حتى يظل OneNotify نشطًا طوال اليوم في الخلفية.';

  @override
  String get batteryStep3Title => 'الالتقاط المستمر جاهز';

  @override
  String get batteryStep3Desc =>
      'سيلتقط سجلك الزمني الآن التنبيهات حتى أثناء الليل أثناء النوم.';

  @override
  String get notificationStep1Title => 'انقر فوق \"منح إذن الوصول للإشعارات\"';

  @override
  String get notificationStep1Desc =>
      'سنأخذك مباشرة إلى شاشة الوصول الخاصة بنظام أندرويد.';

  @override
  String get notificationStep2Title => 'ابحث عن OneNotify وقم بتشغيل المفتاح';

  @override
  String get notificationStep2Desc =>
      'حدد موقع OneNotify في القائمة وقم بتبديل المفتاح إلى نشط.';

  @override
  String get notificationStep3Title => 'اضغط على زر العودة للرجوع';

  @override
  String get notificationStep3Desc =>
      'بمجرد التمكين، ارجع إلى هنا مباشرة. سنتصل تلقائيًا!';

  @override
  String get checkStatusAgain =>
      'لقد قمت بتمكينه بالفعل — تحقق من الحالة مرة أخرى';

  @override
  String get defaultAppLabel => 'تطبيق';
}
