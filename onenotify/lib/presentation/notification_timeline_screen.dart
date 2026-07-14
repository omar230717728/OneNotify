import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:onenotify/database/database.dart';

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

    // Initial data load
    print("LOG 6: Calling initial _triggerDriftRefresh()");
    _triggerDriftRefresh();
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

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Divider(color: Colors.grey[900], height: 1),
            ),

            // Reactive Notification Stream
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

                  final list = snapshot.data ?? [];

                  if (list.isEmpty) {
                    // Modern styled empty state wrapped in RefreshIndicator and SingleChildScrollView
                    // to allow pull-to-refresh even when the database is empty.
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

                  return RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: Colors.white,
                    backgroundColor: surfaceColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20.0),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final item = list[index];
                        final meta = _getAppMeta(item.packageName);
                        final appColor = meta['color'] as Color;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[900]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Left brand accent bar
                                  Container(
                                    width: 6,
                                    color: appColor,
                                  ),
                                  // Main Content
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Package & Time Row
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    meta['icon'] as IconData,
                                                    size: 14,
                                                    color: appColor,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    item.appName ?? meta['name'] as String,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: appColor,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                _formatTime(item.timestamp),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: accentTextColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          // Title
                                          if (item.title != null && item.title!.isNotEmpty)
                                            Text(
                                              item.title!,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          // Message
                                          if (item.message != null && item.message!.isNotEmpty)
                                            Text(
                                              item.message!,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[300],
                                                height: 1.3,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
}
