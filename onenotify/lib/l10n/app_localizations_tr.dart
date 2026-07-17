// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get exitTitle => 'OneNotify\'dan Çık';

  @override
  String get exitConfirm => 'Uygulamadan çıkmak istediğinizden emin misiniz?';

  @override
  String get cancel => 'İptal';

  @override
  String get exit => 'Çıkış';

  @override
  String get notifications => 'Bildirimler';

  @override
  String get tracked => 'Takip Edilenler';

  @override
  String get justNow => 'Şimdi';

  @override
  String secondsAgo(int count) {
    return '${count}sn önce';
  }

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dk önce',
      one: '1 dk önce',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saat önce',
      one: '1 saat önce',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün önce',
      one: '1 gün önce',
    );
    return '$_temp0';
  }

  @override
  String get clearTimelineTitle => 'Zaman Akışını Temizle?';

  @override
  String get clearTimelineConfirm =>
      'Kayıtlı tüm bildirimleri silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.';

  @override
  String get clearAll => 'Tümünü Temizle';

  @override
  String get timelineCleared => 'Zaman akışı başarıyla temizlendi.';

  @override
  String get active => 'AKTİF';

  @override
  String get clearTimelineTooltip => 'Zaman Akışını Temizle';

  @override
  String get unifiedNotificationCenter => 'Birleşik Bildirim Merkezi';

  @override
  String get batteryWarningTitle =>
      '⚠️ Arka Plan Takibi İçin Pil Muafiyeti Gerekli.';

  @override
  String get batteryWarningTitleSettings =>
      '⚠️ OneNotify\'ı Beyaz Listeye Almak İçin Android Pil Ayarlarını Açın';

  @override
  String get batteryWarningDesc =>
      'OneNotify\'ın arka planda sürekli çalışmasına izin vermek için buraya dokunun.';

  @override
  String get batteryWarningDescSettings =>
      'OEM geçersiz kılması hızlı iletişim kutusunu engelledi. Ayarlar -> OneNotify -> Kısıtlanmamış öğesini açmak için buraya dokunun.';

  @override
  String get silentHubTitle => 'Sessiz Merkez';

  @override
  String get silentHubDesc =>
      'Henüz önemli bir bildirim yakalanmadı.\nGelen güncellemeler burada dinamik olarak görünecektir.';

  @override
  String notificationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bildirim',
      one: '1 bildirim',
    );
    return '$_temp0';
  }

  @override
  String couldNotOpenApp(String packageName) {
    return '\'$packageName\' uygulaması açılamadı.';
  }

  @override
  String appNotInstalled(String packageName) {
    return '\'$packageName\' uygulaması yüklü değil.';
  }

  @override
  String get couldNotOpenAppDirectly => 'Bu uygulama doğrudan açılamadı.';

  @override
  String get invalidAppPackage => 'Geçersiz uygulama paketi kimliği.';

  @override
  String get purgeAll => 'Tümünü Temizle';

  @override
  String get dismiss => 'Yoksay';

  @override
  String get trackedApplicationsTitle => 'Takip Edilen Uygulamalar';

  @override
  String get trackedApplicationsDesc =>
      'OneNotify\'ın gerçek zamanlı olarak kesmesine ve saklamasına izin verilen yüklü uygulamaları seçin.';

  @override
  String get searchHint => 'Yüklü uygulamaları ara...';

  @override
  String get noUserAppsFound => 'Kullanıcı uygulaması bulunamadı.';

  @override
  String noAppsMatching(String query) {
    return '\"$query\" ile eşleşen uygulama bulunamadı';
  }

  @override
  String get autoDismissTooltipOn =>
      'Otomatik Kapatma AÇIK (Android durum çubuğundan silindi)';

  @override
  String get autoDismissTooltipOff =>
      'Otomatik Kapatma KAPALI (Normal durum çubuğu uyarıları)';

  @override
  String get ignoreBatteryRestrictions => 'Pil Kısıtlamalarını Yoksay';

  @override
  String get enableRealTimeCapture => 'Gerçek Zamanlı Yakalamayı Etkinleştir';

  @override
  String get batteryExemptionSubtitle =>
      'Telefon ekranınız kapatıldığında Android işletim sisteminin arka planda yakalama işlemini sonlandırmasını önlemek için lütfen OneNotify\'ı pil optimizasyonundan muaf tutun.';

  @override
  String get notificationAccessSubtitle =>
      'WhatsApp, Gmail, Telegram ve Outlook\'taki iletileri yakalamak ve zaman akışınızda birleştirmek için OneNotify\'ın Özel Bildirim Erişimine ihtiyacı vardır.';

  @override
  String get allowBatteryExemption => 'Pil Muafiyetine İzin Ver';

  @override
  String get grantNotificationAccess => 'Bildirim Erişimine İzin Ver';

  @override
  String get batteryStep1Title =>
      '\"Pil Muafiyetine İzin Ver\" seçeneğine dokunun';

  @override
  String get batteryStep1Desc =>
      'Doğrudan Android\'in hızlı beyaz liste iletişim kutusunu isteyeceğiz.';

  @override
  String get batteryStep2Title =>
      'İletişim Kutusunda \"İzin Ver\" seçeneğine dokunun';

  @override
  String get batteryStep2Desc =>
      'OneNotify\'ın arka planda 7/24 aktif kalması için istemi onaylayın.';

  @override
  String get batteryStep3Title => 'Sürekli Yakalama Hazır';

  @override
  String get batteryStep3Desc =>
      'Zaman akışınız artık uyurken bile gece boyunca uyarıları yakalayacaktır.';

  @override
  String get notificationStep1Title =>
      '\"Bildirim Erişimine İzin Ver\" seçeneğine dokunun';

  @override
  String get notificationStep1Desc =>
      'Sizi doğrudan Android\'in Özel Erişim ekranına götüreceğiz.';

  @override
  String get notificationStep2Title => 'OneNotify\'ı Bulun ve Anahtarı AÇIN';

  @override
  String get notificationStep2Desc =>
      'Listede OneNotify\'ı bulun ve anahtarı aktif konuma getirin.';

  @override
  String get notificationStep3Title => 'Geri Dönmek İçin Geri Tuşuna Basın';

  @override
  String get notificationStep3Desc =>
      'Etkinleştirildiğinde, doğrudan buraya dönün. Otomatik olarak bağlanacağız!';

  @override
  String get checkStatusAgain =>
      'Zaten etkinleştirdim — Durumu tekrar kontrol et';

  @override
  String get defaultAppLabel => 'Uygulama';
}
