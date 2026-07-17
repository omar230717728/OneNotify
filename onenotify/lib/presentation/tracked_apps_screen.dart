import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:onenotify/l10n/app_localizations.dart';
import 'package:onenotify/database/database.dart';

class TrackedAppsScreen extends StatefulWidget {
  final AppDatabase database;
  final VoidCallback? onAppToggled;

  const TrackedAppsScreen({
    super.key,
    required this.database,
    this.onAppToggled,
  });

  @override
  State<TrackedAppsScreen> createState() => _TrackedAppsScreenState();
}

class _TrackedAppsScreenState extends State<TrackedAppsScreen> with WidgetsBindingObserver {
  static const _syncChannel = MethodChannel('com.example.onenotify/sync');
  List<AppInfo> _installedApps = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isIgnoringBattery = true;
  bool _hasAttemptedSystemDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInstalledApps();
    _checkBatteryStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBatteryStatus();
      Future.delayed(const Duration(milliseconds: 500), _checkBatteryStatus);
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

  Future<void> _loadInstalledApps() async {
    try {
      // Fetch user-installed apps with icons, excluding system background noise
      final apps = await FlutterDeviceApps.listApps(
        includeSystem: true,
        onlyLaunchable: true,
        includeIcons: true,
      );

      // Filter valid packages and sort alphabetically by appName
      final validApps = apps.where((a) => (a.packageName ?? '').isNotEmpty).toList()
        ..sort((a, b) => (a.appName ?? 'Unknown').toLowerCase().compareTo((b.appName ?? 'Unknown').toLowerCase()));

      if (mounted) {
        setState(() {
          _installedApps = validApps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF0B0F19);
    const surfaceColor = Color(0xFF161E2E);
    const cardColor = Color(0xFF1F293D);
    const primaryColor = Color(0xFF3B82F6);

    final filteredApps = _installedApps.where((app) {
      final query = _searchQuery.toLowerCase();
      final name = (app.appName ?? 'Unknown').toLowerCase();
      final pkg = (app.packageName ?? '').toLowerCase();
      return name.contains(query) || pkg.contains(query);
    }).toList();

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.trackedApplicationsTitle,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.trackedApplicationsDesc,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey[400],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Dynamic Battery Optimization Exemption Banner with Settings Fallback
            if (!_isIgnoringBattery)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
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
                                      ? l10n.batteryWarningTitleSettings
                                      : l10n.batteryWarningTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _hasAttemptedSystemDialog
                                      ? l10n.batteryWarningDescSettings
                                      : l10n.batteryWarningDesc,
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

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[850]!),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: Colors.grey[400], size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // Monitored Apps Stream & List synchronized with Drift SQLite table
            Expanded(
              child: StreamBuilder<Map<String, DbMonitoredApp>>(
                stream: widget.database.watchMonitoredAppsMap(),
                builder: (context, snapshot) {
                  final monitoredMap = snapshot.data ?? {};

                  if (_isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  }

                  if (filteredApps.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty ? l10n.noUserAppsFound : l10n.noAppsMatching(_searchQuery),
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = filteredApps[index];
                      final pkg = app.packageName ?? '';
                      final name = app.appName ?? 'Unknown';
                      final monitoredApp = monitoredMap[pkg];
                      final isMonitored = monitoredApp != null;
                      final isMuted = monitoredApp?.isMuted ?? false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isMonitored ? primaryColor.withValues(alpha: 0.5) : Colors.grey[900]!,
                            width: 1.2,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: app.iconBytes != null
                                  ? Image.memory(
                                      app.iconBytes!,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.android, color: Colors.grey),
                                    )
                                  : const Icon(Icons.android, color: Colors.grey),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            pkg,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isMonitored)
                                IconButton(
                                  tooltip: isMuted ? l10n.autoDismissTooltipOn : l10n.autoDismissTooltipOff,
                                  icon: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: isMuted ? Colors.amber[700]!.withValues(alpha: 0.2) : surfaceColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isMuted ? Colors.amber[600]! : Colors.grey[800]!,
                                      ),
                                    ),
                                    child: Icon(
                                      isMuted ? Icons.notifications_off_rounded : Icons.notifications_active_rounded,
                                      color: isMuted ? Colors.amber[400] : Colors.grey[400],
                                      size: 18,
                                    ),
                                  ),
                                  onPressed: () async {
                                    await widget.database.setPackageMuted(pkg, !isMuted);
                                  },
                                ),
                              Switch.adaptive(
                                value: isMonitored,
                                activeTrackColor: primaryColor,
                                onChanged: (value) async {
                                  if (value) {
                                    await widget.database.addMonitoredPackage(pkg);
                                  } else {
                                    await widget.database.removeMonitoredPackage(pkg);
                                  }
                                  widget.onAppToggled?.call();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
