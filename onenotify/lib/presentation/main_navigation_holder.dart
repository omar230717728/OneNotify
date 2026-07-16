import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onenotify/database/database.dart';
import 'package:onenotify/presentation/notification_timeline_screen.dart';
import 'package:onenotify/presentation/tracked_apps_screen.dart';
import 'package:onenotify/presentation/onboarding_permission_screen.dart';

class MainNavigationHolder extends StatefulWidget {
  final AppDatabase database;

  const MainNavigationHolder({super.key, required this.database});

  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _hasNotificationAccess = true;
  bool _checkedInitialOnboarding = false;
  static const _syncChannel = MethodChannel('com.example.onenotify/sync');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNotificationAccess();
    _checkInitialOnboarding();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationAccess();
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
        await _syncChannel.invokeMethod('requestRebindService');
      }
    } catch (e) {
      // Safe fallback
    }
  }

  Future<void> _checkInitialOnboarding() async {
    try {
      final count = await widget.database.getMonitoredAppsCount();
      if (mounted && count == 0 && !_checkedInitialOnboarding) {
        setState(() {
          _currentIndex = 1; // Default to Tracked Apps if no apps monitored yet
          _checkedInitialOnboarding = true;
        });
      } else {
        _checkedInitialOnboarding = true;
      }
    } catch (e) {
      _checkedInitialOnboarding = true;
    }
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context) {
    const surfaceColor = Color(0xFF161E2E);
    const primaryColor = Color(0xFF3B82F6);

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: surfaceColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey[850]!, width: 1),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.power_settings_new_rounded,
                  color: Colors.redAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Exit OneNotify',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to exit the app?',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[400],
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text(
                'Exit',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasNotificationAccess) {
      return OnboardingPermissionScreen(
        isBatteryExemption: false,
        onGrantPressed: () async {
          await _syncChannel.invokeMethod('requestListenerPermission');
        },
        onCheckAgain: () async {
          await _checkNotificationAccess();
        },
      );
    }

    const surfaceColor = Color(0xFF161E2E);
    const primaryColor = Color(0xFF3B82F6);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmationDialog(context);
        if (shouldExit == true) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            NotificationTimelineScreen(database: widget.database),
            TrackedAppsScreen(
              database: widget.database,
              onAppToggled: () {
                // Clean transition handling on toggle
              },
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(top: BorderSide(color: Colors.grey[850]!, width: 1)),
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: primaryColor.withValues(alpha: 0.2),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12);
                }
                return TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500, fontSize: 12);
              }),
            ),
            child: NavigationBar(
              backgroundColor: surfaceColor,
              elevation: 0,
              height: 65,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.notifications_outlined, color: Colors.grey),
                  selectedIcon: Icon(Icons.notifications_rounded, color: primaryColor),
                  label: 'Notifications',
                ),
                NavigationDestination(
                  icon: Icon(Icons.track_changes_outlined, color: Colors.grey),
                  selectedIcon: Icon(Icons.track_changes_rounded, color: primaryColor),
                  label: 'Tracked',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
