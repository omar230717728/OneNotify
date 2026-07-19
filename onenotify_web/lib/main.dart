import 'dart:async';
import 'dart:math';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const firebaseConfig = FirebaseOptions(
  apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: "AIzaSyAzTXacT1DtFyZadS8cPHGSe6aNRtWJUUc"),
  authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: "onenotify-7593c.firebaseapp.com"),
  projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: "onenotify-7593c"),
  storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: "onenotify-7593c.firebasestorage.app"),
  messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: "368907494234"),
  appId: String.fromEnvironment('FIREBASE_APP_ID', defaultValue: "1:368907494234:web:0506931c39106d853f4963"),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseConfig);
  runApp(const OneNotifyWebApp());
}

class OneNotifyWebApp extends StatelessWidget {
  const OneNotifyWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneNotify Web Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        primaryColor: const Color(0xFF3B82F6),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF161E2E),
          error: Color(0xFFEF4444),
        ),
        useMaterial3: true,
      ),
      home: const AppRootScreen(),
    );
  }
}

class AppRootScreen extends StatefulWidget {
  const AppRootScreen({super.key});

  @override
  State<AppRootScreen> createState() => _AppRootScreenState();
}

class _AppRootScreenState extends State<AppRootScreen> {
  String? _pairedMobileUid;

  @override
  void initState() {
    super.initState();
    _checkPairedStatus();
  }

  void _checkPairedStatus() {
    setState(() {
      _pairedMobileUid = html.window.localStorage['paired_mobile_uid'];
    });
  }

  void _onPairingCompleted(String mobileUid) {
    html.window.localStorage['paired_mobile_uid'] = mobileUid;
    setState(() {
      _pairedMobileUid = mobileUid;
    });
  }

  void _onUnpair() {
    html.window.localStorage.remove('paired_mobile_uid');
    setState(() {
      _pairedMobileUid = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pairedMobileUid == null) {
      return PairingScreen(onPairingCompleted: _onPairingCompleted);
    }
    return TimelineDashboardScreen(
      mobileUid: _pairedMobileUid!,
      onUnpair: _onUnpair,
    );
  }
}

class PairingScreen extends StatefulWidget {
  final Function(String) onPairingCompleted;

  const PairingScreen({super.key, required this.onPairingCompleted});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  String? _pairingCode;
  String? _webUid;
  bool _isInitializing = true;
  StreamSubscription<DocumentSnapshot>? _pairingSubscription;

  @override
  void initState() {
    super.initState();
    _startPairingSequence();
  }

  @override
  void dispose() {
    _pairingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startPairingSequence() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      _webUid = userCredential.user?.uid;
      if (_webUid != null) {
        await _generateAndRegisterPairingCode();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _generateAndRegisterPairingCode() async {
    final random = Random();
    final code = (100000 + random.nextInt(900000)).toString();

    await FirebaseFirestore.instance.collection('pairing_codes').doc(code).set({
      'web_uid': _webUid,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      setState(() {
        _pairingCode = code;
      });
    }

    _pairingSubscription?.cancel();
    _pairingSubscription = FirebaseFirestore.instance
        .collection('pairing_codes')
        .doc(code)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data['status'] == 'linked') {
          final mobileUid = data['mobile_uid'] as String?;
          if (mobileUid != null) {
            _pairingSubscription?.cancel();
            widget.onPairingCompleted(mobileUid);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF0B0F19)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(40),
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161E2E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[850]!, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Title Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sync_alt_rounded,
                      color: Color(0xFF3B82F6),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Pair Web Companion',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Link your web portal with your mobile application to stream notifications in real-time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 36),

                  if (_isInitializing)
                    const Column(
                      children: [
                        CircularProgressIndicator(color: Color(0xFF3B82F6)),
                        SizedBox(height: 16),
                        Text('Connecting securely...', style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  else if (_pairingCode != null) ...[
                    // Custom pairing code digits display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[900]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _pairingCode!
                            .split('')
                            .map((digit) => Text(
                                  digit,
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF3B82F6),
                                    letterSpacing: 4,
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Waiting for mobile connection...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 36),
                  Divider(color: Colors.grey[850]!),
                  const SizedBox(height: 20),
                  // Detailed Step-by-Step Instructions
                  _buildInstructionStep(
                    '1',
                    'Open the OneNotify mobile app on your Android device.',
                  ),
                  _buildInstructionStep(
                    '2',
                    'Grant the required background and notification permissions.',
                  ),
                  _buildInstructionStep(
                    '3',
                    'Go to the settings or tracked application page, tap "Pair Web Portal", and enter the 6-digit code shown above.',
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isInitializing = true;
                      });
                      _startPairingSequence();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Generate New Code'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[400],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String stepNumber, String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            alignment: Alignment.center,
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF1F293D),
              shape: BoxShape.circle,
            ),
            child: Text(
              stepNumber,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TimelineDashboardScreen extends StatefulWidget {
  final String mobileUid;
  final VoidCallback onUnpair;

  const TimelineDashboardScreen({
    super.key,
    required this.mobileUid,
    required this.onUnpair,
  });

  @override
  State<TimelineDashboardScreen> createState() => _TimelineDashboardScreenState();
}

class _TimelineDashboardScreenState extends State<TimelineDashboardScreen> {
  final Set<String> _expandedPackages = {};

  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161E2E),
        title: const Text('Clear All Notifications'),
        content: const Text(
          'Are you sure you want to permanently delete all notifications from both the cloud and the web timeline?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.mobileUid)
            .collection('notifications')
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (var doc in query.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All cloud notifications cleared successfully.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _deleteOneNotification(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.mobileUid)
          .collection('notifications')
          .doc(docId)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete notification: ${e.toString()}')),
        );
      }
    }
  }

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
        'color': const Color(0xFF50A2E3),
        'icon': Icons.send_rounded,
      };
    } else if (packageName.contains('gmail') || packageName.contains('email')) {
      return {
        'name': 'Gmail',
        'color': const Color(0xFFEA4335),
        'icon': Icons.email_outlined,
      };
    } else if (packageName.contains('outlook')) {
      return {
        'name': 'Outlook',
        'color': const Color(0xFF0078D4),
        'icon': Icons.mark_as_unread_outlined,
      };
    } else if (packageName.contains('youtube')) {
      return {
        'name': 'YouTube',
        'color': const Color(0xFFFF0000),
        'icon': Icons.play_circle_fill_rounded,
      };
    } else if (packageName.contains('google')) {
      return {
        'name': 'Google',
        'color': const Color(0xFF4285F4),
        'icon': Icons.search_rounded,
      };
    } else {
      return {
        'name': packageName.split('.').last.toUpperCase(),
        'color': const Color(0xFF3B82F6),
        'icon': Icons.notifications_none_rounded,
      };
    }
  }

  String _formatTime(dynamic timestampField, dynamic localTimestampField) {
    DateTime? dt;
    if (timestampField is Timestamp) {
      dt = timestampField.toDate();
    } else if (localTimestampField is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(localTimestampField);
    }
    if (dt == null) return '--:--';
    final hr = dt.hour.toString().padLeft(2, '0');
    final mn = dt.minute.toString().padLeft(2, '0');
    return '$hr:$mn';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Panel for Desktop
          Container(
            width: 320,
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.leak_add_rounded,
                        color: Color(0xFF3B82F6),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'OneNotify',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                const Text(
                  'SYSTEM STATUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161E2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[850]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_tethering_rounded, color: Color(0xFF10B981), size: 18),
                      SizedBox(width: 12),
                      Text(
                        'Live Cloud Stream Active',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                const Text(
                  'DEVICE CONNECTION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Paired Mobile UID:',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  widget.mobileUid,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B82F6),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: widget.onUnpair,
                  icon: const Icon(Icons.link_off_rounded, size: 18),
                  label: const Text('Unpair Device'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
          ),

          // Main timeline stream layout
          Expanded(
            child: Container(
              color: const Color(0xFF0B0F19),
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Upper Navigation Deck
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications Feed',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Incoming alerts from your whitelisted mobile applications.',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _clearAllNotifications,
                        icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                        label: const Text('Clear All Broadcasts'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFFF87171),
                          side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Divider(color: Colors.grey[900]!),
                  const SizedBox(height: 24),

                  // StreamBuilder Firestore Timeline
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.mobileUid)
                          .collection('notifications')
                          .orderBy('localTimestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161E2E),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey[900]!),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 48,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'All caught up!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Your desktop feed is listening to background notifications.',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }

                        // Group notifications by packageName in memory
                        final Map<String, List<QueryDocumentSnapshot>> grouped = {};
                        for (final doc in docs) {
                          final data = doc.data() as Map<String, dynamic>?;
                          if (data != null) {
                            final pkg = data['packageName'] as String? ?? 'unknown';
                            grouped.putIfAbsent(pkg, () => []).add(doc);
                          }
                        }

                        final packageNames = grouped.keys.toList();

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: packageNames.length,
                          itemBuilder: (context, index) {
                            final packageName = packageNames[index];
                            final packageList = grouped[packageName]!;
                            final meta = _getAppMeta(packageName);
                            final appColor = meta['color'] as Color;
                            final appDisplayName = packageList.first.get('appName') as String? ?? meta['name'] as String;
                            final isExpanded = _expandedPackages.contains(packageName);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161E2E),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isExpanded ? appColor.withValues(alpha: 0.5) : Colors.grey[900]!,
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Accordion Header
                                  InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedPackages.remove(packageName);
                                        } else {
                                          _expandedPackages.add(packageName);
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: appColor.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  meta['icon'] as IconData,
                                                  color: appColor,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Text(
                                                appDisplayName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0B0F19),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: appColor.withValues(alpha: 0.3)),
                                                ),
                                                child: Text(
                                                  '${packageList.length}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: appColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Icon(
                                            isExpanded
                                                ? Icons.expand_less_rounded
                                                : Icons.expand_more_rounded,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Accordion Body
                                  if (isExpanded) ...[
                                    Divider(color: Colors.grey[900]!, height: 1),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: packageList.length,
                                      itemBuilder: (context, idx) {
                                        final doc = packageList[idx];
                                        final docId = doc.id;
                                        final title = doc.get('title') as String? ?? '';
                                        final message = doc.get('message') as String? ?? '';
                                        final ts = doc.data() is Map && (doc.data() as Map).containsKey('timestamp')
                                            ? doc.get('timestamp')
                                            : null;
                                        final localTs = doc.data() is Map && (doc.data() as Map).containsKey('localTimestamp')
                                            ? doc.get('localTimestamp')
                                            : null;

                                        return Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            border: idx != packageList.length - 1
                                                ? Border(bottom: BorderSide(color: Colors.grey[900]!))
                                                : null,
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          title.isNotEmpty ? title : appDisplayName,
                                                          style: const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Text(
                                                          _formatTime(ts, localTs),
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (message.isNotEmpty) ...[
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        message,
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
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                                color: Colors.grey[500],
                                                hoverColor: Colors.red.withValues(alpha: 0.1),
                                                onPressed: () => _deleteOneNotification(docId),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
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
          ),
        ],
      ),
    );
  }
}
