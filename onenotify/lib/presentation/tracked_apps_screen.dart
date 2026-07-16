import 'package:flutter/material.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
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

class _TrackedAppsScreenState extends State<TrackedAppsScreen> {
  List<AppInfo> _installedApps = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInstalledApps() async {
    try {
      // Fetch user-installed apps with icons, excluding system background noise
      final apps = await FlutterDeviceApps.listApps(
        includeSystem: false,
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

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tracked Applications',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select which installed apps OneNotify is allowed to intercept and store in real-time.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey[400],
                      height: 1.3,
                    ),
                  ),
                ],
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
                    hintText: 'Search installed apps...',
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
              child: StreamBuilder<Set<String>>(
                stream: widget.database.watchAllMonitoredPackages(),
                builder: (context, snapshot) {
                  final monitoredSet = snapshot.data ?? {};

                  if (_isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  }

                  if (filteredApps.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty ? 'No user apps found.' : 'No apps matching "$_searchQuery"',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = filteredApps[index];
                      final pkg = app.packageName ?? '';
                      final name = app.appName ?? 'Unknown';
                      final isMonitored = monitoredSet.contains(pkg);

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
                          trailing: Switch.adaptive(
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
