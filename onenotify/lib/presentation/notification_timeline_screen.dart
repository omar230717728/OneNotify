import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:onenotify/database/database.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:onenotify/presentation/onboarding_permission_screen.dart';

class NotificationTimelineScreen extends StatefulWidget {
  final AppDatabase database;

  const NotificationTimelineScreen({super.key, required this.database});

  @override
  State<NotificationTimelineScreen> createState() => _NotificationTimelineScreenState();
}

class _NotificationTimelineScreenState extends State<NotificationTimelineScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Stream<List<DbNotification>> _notificationStream;

  static const _syncChannel = MethodChannel('com.example.onenotify/sync');
  bool _hasNotificationAccess = true;
  bool _isIgnoringBattery = true;
  bool _hasAttemptedSystemDialog = false;
  final Set<String> _expandedPackages = {};
  final Map<String, Uint8List?> _appIconsCache = {};
  final Set<String> _loadingIcons = {};

  void _ensureAppIconsLoaded(List<String> packages) {
    for (final pkg in packages) {
      if (!_appIconsCache.containsKey(pkg) && !_loadingIcons.contains(pkg)) {
        _loadingIcons.add(pkg);
        FlutterDeviceApps.getApp(pkg, includeIcon: true).then((appInfo) {
          if (mounted) {
            setState(() {
              _appIconsCache[pkg] = appInfo?.iconBytes;
              _loadingIcons.remove(pkg);
            });
          }
        }).catchError((e) {
          if (mounted) {
            _loadingIcons.remove(pkg);
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Cache the stream ONCE in initState to prevent StreamBuilder teardown on rebuilds
    _notificationStream = widget.database.watchAllNotifications();
    print("LOG 6: initState — _notificationStream cached from watchAllNotifications()");

    // Blinking dot animation for the "Ingestion Engine: ACTIVE" status indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Register MethodChannel listener for real-time background service notifications
    print("LOG 6: Registering MethodChannel handler on 'com.example.onenotify/sync'");
    _syncChannel.setMethodCallHandler((call) async {
      print("LOG 6: MethodChannel RECEIVED method call: '${call.method}'");
      if (call.method == 'refresh') {
        print("LOG 7: 'refresh' confirmed — calling _triggerDriftRefresh()");
        _triggerDriftRefresh();
      }
    });

    // Initial data load and permission check
    print("LOG 6: Calling initial _triggerDriftRefresh()");
    _triggerDriftRefresh();
    _checkNotificationAccess();
    _checkBatteryStatus();
  }

  @override
  void dispose() {
    print("LOG 6: dispose — clearing MethodChannel handler and observer");
    WidgetsBinding.instance.removeObserver(this);
    _syncChannel.setMethodCallHandler(null);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("LOG 6: Lifecycle state changed: $state");
    if (state == AppLifecycleState.resumed) {
      print("LOG 6: App RESUMED — calling _triggerDriftRefresh()");
      _triggerDriftRefresh();
      _checkNotificationAccess();
      _checkBatteryStatus();
      Future.delayed(const Duration(milliseconds: 500), _checkBatteryStatus);
    }
  }

  Future<void> _checkNotificationAccess() async {
    try {
      final isGranted = await _syncChannel.invokeMethod<bool>('isListenerPermissionGranted') ?? false;
      if (mounted && _hasNotificationAccess != isGranted) {
        setState(() {
          _hasNotificationAccess = isGranted;
        });
      }
      if (isGranted) {
        // Also request rebind so Android activates our background listener immediately on new phones
        await _syncChannel.invokeMethod('requestRebindService');
      }
    } catch (e) {
      // Safe fallback if channel is unavailable
    }
  }

  Future<void> _checkBatteryStatus() async {
    try {
      final isIgnoring = await _syncChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
      if (mounted) {
        setState(() {
          _isIgnoringBattery = isIgnoring;
        });
      }
    } catch (e) {
      // Safe fallback
    }
  }

  /// Notify Drift that the underlying database was mutated externally,
  /// causing the cached _notificationStream to re-emit fresh data.
  void _triggerDriftRefresh() {
    print("LOG 7: _triggerDriftRefresh — calling notifyUpdates on Drift");
    widget.database.notifyUpdates({
      TableUpdate.onTable(widget.database.notifications, kind: UpdateKind.insert),
    });
    print("LOG 7: notifyUpdates dispatched — Drift stream should re-emit");
    
    // Also fire a direct one-shot query to verify data exists
    _debugManualQuery();
  }

  /// Debug-only: direct future-based query to verify rows exist in the database.
  Future<void> _debugManualQuery() async {
    try {
      final records = await (widget.database.select(widget.database.notifications)
            ..orderBy([
              (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
            ]))
          .get();
      print("LOG 8: _debugManualQuery — found ${records.length} records in database");
      for (var r in records.take(3)) {
        print("LOG 8:   -> package=${r.packageName}, title=${r.title}");
      }
    } catch (e) {
      print("LOG 8 ERROR: _debugManualQuery failed: $e");
    }
  }

  Future<void> _handleRefresh() async {
    _triggerDriftRefresh();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  // Map package name to app name, icon, and specific theme color
  Map<String, dynamic> _getAppMeta(String packageName) {
    if (packageName.contains('whatsapp')) {
      return {
        'name': 'WhatsApp',
        'color': const Color(0xFF25D366),
        'icon': Icons.message_outlined,
      };
    } else if (packageName.contains('telegram')) {
      return {
        'name': 'Telegram',
        'color': const Color(0xFF0088CC),
        'icon': Icons.send_outlined,
      };
    } else if (packageName.contains('android.gm')) {
      return {
        'name': 'Gmail',
        'color': const Color(0xFFD44638),
        'icon': Icons.mail_outline,
      };
    } else if (packageName.contains('outlook')) {
      return {
        'name': 'Outlook',
        'color': const Color(0xFF0078D4),
        'icon': Icons.work_outline,
      };
    } else if (packageName.contains('youtube')) {
      return {
        'name': 'YouTube',
        'color': const Color(0xFFFF0000),
        'icon': Icons.play_circle_fill_rounded,
      };
    } else if (packageName.contains('googlequicksearchbox') || (packageName.contains('android.google') && !packageName.contains('gm'))) {
      return {
        'name': 'Google',
        'color': const Color(0xFF4285F4),
        'icon': Icons.search_rounded,
      };
    } else {
      return {
        'name': 'App',
        'color': Colors.blueGrey,
        'icon': Icons.notifications_none_outlined,
      };
    }
  }

  // Format timestamp (BigInt milliseconds) to human-friendly relative string
  String _formatTime(BigInt timestampMs) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestampMs.toInt());
    final difference = DateTime.now().difference(dateTime);

    if (difference.isNegative || difference.inSeconds < 10) {
      return 'Just now';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'min' : 'mins'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasNotificationAccess) {
      return OnboardingPermissionScreen(
        onGrantPressed: () async {
          await _syncChannel.invokeMethod('requestListenerPermission');
        },
        onCheckAgain: () async {
          await _checkNotificationAccess();
        },
      );
    }

    // Curated Midnight UI Color Palette
    const backgroundColor = Color(0xFF0B0F19);
    const surfaceColor = Color(0xFF161E2E);
    const cardBgColor = Color(0xFF1F293D);
    const accentTextColor = Color(0xFF9CA3AF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // High-fidelity modern header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OneNotify',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unified Notification Center',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  // Blinking status pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FadeTransition(
                          opacity: _pulseController,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'ENGINE ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Dynamic Battery Optimization Exemption Banner with Settings Fallback
            if (!_isIgnoringBattery)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Material(
                  color: const Color(0xFF3B1818),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      if (!_hasAttemptedSystemDialog) {
                        setState(() {
                          _hasAttemptedSystemDialog = true;
                        });
                        await _syncChannel.invokeMethod('requestIgnoreBatteryOptimizations');
                      } else {
                        await _syncChannel.invokeMethod('openBatteryOptimizationSettings');
                      }
                      await Future.delayed(const Duration(milliseconds: 600));
                      await _checkBatteryStatus();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6), width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _hasAttemptedSystemDialog
                                      ? '⚠️ Open Android Battery Settings to Whitelist OneNotify'
                                      : '⚠️ Battery Exemption Required for Background Tracking.',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _hasAttemptedSystemDialog
                                      ? 'OEM override blocked the quick dialog. Tap here to open Settings -> OneNotify -> Unrestricted.'
                                      : 'Tap here to allow OneNotify to run continuously in the background.',
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFF87171), size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Divider(color: Colors.grey[900], height: 1),
            ),

            // Reactive Notification Stream with In-Memory Grouping
            Expanded(
              child: StreamBuilder<List<DbNotification>>(
                stream: _notificationStream,
                builder: (context, snapshot) {
                  print("LOG 9: StreamBuilder REBUILD — connectionState: ${snapshot.connectionState}, dataLength: ${snapshot.data?.length ?? 'null'}");

                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    );
                  }

                  final notifications = snapshot.data ?? [];

                  if (notifications.isEmpty) {
                    // Modern styled empty state wrapped in RefreshIndicator and SingleChildScrollView
                    return RefreshIndicator(
                      onRefresh: _handleRefresh,
                      color: Colors.white,
                      backgroundColor: surfaceColor,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: MediaQuery.of(context).size.height - 200,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey[900]!),
                                ),
                                child: const Icon(
                                  Icons.notifications_off_outlined,
                                  size: 48,
                                  color: accentTextColor,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Silent Hub',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'No important notifications captured yet.\nIncoming updates will appear here dynamically.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: accentTextColor,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // 1. In-Memory Grouping (Dart) by packageName
                  final Map<String, List<DbNotification>> groupedNotifications = {};
                  for (var notification in notifications) {
                    groupedNotifications.putIfAbsent(notification.packageName, () => []).add(notification);
                  }
                  final packageNames = groupedNotifications.keys.toList();
                  _ensureAppIconsLoaded(packageNames);

                  // 2. Hierarchical Accordion UI with Swipe-To-Dismiss
                  return RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: Colors.white,
                    backgroundColor: surfaceColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20.0),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      itemCount: packageNames.length,
                      itemBuilder: (context, index) {
                        final packageName = packageNames[index];
                        final packageList = groupedNotifications[packageName]!;
                        final firstItem = packageList.first;
                        final meta = _getAppMeta(packageName);
                        final appColor = meta['color'] as Color;
                        final appDisplayName = firstItem.appName ?? meta['name'] as String;
                        final isExpanded = _expandedPackages.contains(packageName);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Parent Card (The App Header) wrapped in Dismissible
                            Dismissible(
                              key: ValueKey('parent_$packageName'),
                              direction: DismissDirection.horizontal,
                              onDismissed: (direction) async {
                                print("PURGE_PIPELINE: Swiped Parent Card. Deleting all notifications for package=$packageName");
                                await (widget.database.delete(widget.database.notifications)
                                      ..where((t) => t.packageName.equals(packageName)))
                                    .go();
                              },
                              background: _buildSwipeBackground(appColor, isParent: true, alignRight: false),
                              secondaryBackground: _buildSwipeBackground(appColor, isParent: true, alignRight: true),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isExpanded ? appColor.withValues(alpha: 0.6) : Colors.grey[900]!,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (isExpanded) {
                                            _expandedPackages.remove(packageName);
                                          } else {
                                            _expandedPackages.add(packageName);
                                          }
                                        });
                                      },
                                      child: IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            // Left brand accent bar
                                            Container(width: 6, color: appColor),
                                            // Main Header Row
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          width: 36,
                                                          height: 36,
                                                          decoration: BoxDecoration(
                                                            color: _appIconsCache[packageName] != null
                                                                ? surfaceColor
                                                                : appColor.withValues(alpha: 0.15),
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                          child: ClipRRect(
                                                            borderRadius: BorderRadius.circular(8),
                                                            child: _appIconsCache[packageName] != null
                                                                ? Image.memory(
                                                                    _appIconsCache[packageName]!,
                                                                    width: 36,
                                                                    height: 36,
                                                                    fit: BoxFit.cover,
                                                                    errorBuilder: (_, __, ___) => Icon(
                                                                      meta['icon'] as IconData,
                                                                      size: 20,
                                                                      color: appColor,
                                                                    ),
                                                                  )
                                                                : Icon(
                                                                    meta['icon'] as IconData,
                                                                    size: 20,
                                                                    color: appColor,
                                                                  ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Text(
                                                          appDisplayName,
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
                                                        // Dynamic count badge
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: surfaceColor,
                                                            borderRadius: BorderRadius.circular(12),
                                                            border: Border.all(color: appColor.withValues(alpha: 0.4)),
                                                          ),
                                                          child: Text(
                                                            '${packageList.length} ${packageList.length == 1 ? 'notification' : 'notifications'}',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                              color: appColor,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Icon(
                                                          isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                                          color: accentTextColor,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
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
                            ),

                            // Child Cards (The Messages) — rendered only when parent is expanded
                            if (isExpanded)
                              Column(
                                children: packageList.map((item) {
                                  return Dismissible(
                                    key: ValueKey('child_${item.id}'),
                                    direction: DismissDirection.horizontal,
                                    onDismissed: (direction) async {
                                      print("PURGE_PIPELINE: Swiped Child Card id=${item.id}. Purging row from Drift database.");
                                      await widget.database.deleteNotificationById(item.id);
                                    },
                                    background: _buildSwipeBackground(Colors.red[700]!, isParent: false, alignRight: false),
                                    secondaryBackground: _buildSwipeBackground(Colors.red[700]!, isParent: false, alignRight: true),
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 16, right: 0, bottom: 8),
                                      decoration: BoxDecoration(
                                        color: surfaceColor,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.grey[850]!),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () async {
                                              final pkg = item.packageName;
                                              if (pkg.isNotEmpty) {
                                                try {
                                                  final app = await FlutterDeviceApps.getApp(pkg);
                                                  if (app != null) {
                                                    final opened = await FlutterDeviceApps.openApp(pkg);
                                                    if (opened) {
                                                      print("PURGE_PIPELINE: Tapped Child Card id=${item.id}. Purging row from Drift database.");
                                                      await widget.database.deleteNotificationById(item.id);
                                                    } else {
                                                      if (!context.mounted) return;
                                                      _showErrorSnackBar(context, "Could not open application '$pkg'.");
                                                    }
                                                  } else {
                                                    if (!context.mounted) return;
                                                    _showErrorSnackBar(context, "Application '$pkg' is not currently installed.");
                                                  }
                                                } catch (e) {
                                                  if (!context.mounted) return;
                                                  _showErrorSnackBar(context, "Could not open this application directly.");
                                                }
                                              } else {
                                                _showErrorSnackBar(context, "Invalid app package identifier.");
                                              }
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(14.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Header: Title & Relative Timestamp
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          item.title != null && item.title!.isNotEmpty
                                                              ? item.title!
                                                              : appDisplayName,
                                                          style: const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        _formatTime(item.timestamp),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: accentTextColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (item.message != null && item.message!.isNotEmpty) ...[
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      item.message!,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey[300],
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 6),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(Color color, {required bool isParent, required bool alignRight}) {
    return Container(
      margin: EdgeInsets.only(
        left: isParent ? 0 : 16,
        bottom: 8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(isParent ? 16 : 14),
      ),
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!alignRight) ...[
            const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              isParent ? 'Purge All' : 'Dismiss',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ] else ...[
            Text(
              isParent ? 'Purge All' : 'Dismiss',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 24),
          ],
        ],
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.red[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
