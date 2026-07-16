import 'package:flutter/material.dart';

class OnboardingPermissionScreen extends StatefulWidget {
  final VoidCallback onGrantPressed;
  final VoidCallback onCheckAgain;
  final bool isBatteryExemption;

  const OnboardingPermissionScreen({
    super.key,
    required this.onGrantPressed,
    required this.onCheckAgain,
    this.isBatteryExemption = false,
  });

  @override
  State<OnboardingPermissionScreen> createState() => _OnboardingPermissionScreenState();
}

class _OnboardingPermissionScreenState extends State<OnboardingPermissionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF0B0F19);
    const surfaceColor = Color(0xFF161E2E);
    const cardColor = Color(0xFF1F293D);
    const primaryColor = Color(0xFF3B82F6);
    const accentColor = Color(0xFF60A5FA);

    final titleText = widget.isBatteryExemption ? 'Ignore Battery Restrictions' : 'Enable Real-Time Capture';
    final subtitleText = widget.isBatteryExemption
        ? 'To prevent Android OS from killing background capture when your phone screen is turned off, please exempt OneNotify from battery optimization.'
        : 'To capture and unify messages from WhatsApp, Gmail, Telegram, and Outlook into your timeline, OneNotify needs Special Notification Access.';
    final buttonLabel = widget.isBatteryExemption ? 'Allow Battery Exemption' : 'Grant Notification Access';

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Top glowing badge & icon illustration
              Center(
                child: AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: surfaceColor,
                        border: Border.all(
                          color: primaryColor.withValues(alpha: _glowAnimation.value * 0.6),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: _glowAnimation.value * 0.25),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        widget.isBatteryExemption ? Icons.battery_charging_full_rounded : Icons.shield_rounded,
                        size: 56,
                        color: const Color(0xFF1D4ED8),
                      ),
                      if (!widget.isBatteryExemption)
                        const Icon(
                          Icons.notifications_active_rounded,
                          size: 30,
                          color: Colors.white,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Title & Subtitle
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitleText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              // Step-by-Step Instruction Cards
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: widget.isBatteryExemption
                      ? [
                          _buildStepCard(
                            stepNumber: '1',
                            icon: Icons.touch_app_rounded,
                            title: 'Tap "Allow Battery Exemption"',
                            description: 'We will prompt Android\'s quick whitelist dialog directly.',
                            cardColor: cardColor,
                            accentColor: accentColor,
                          ),
                          const SizedBox(height: 14),
                          _buildStepCard(
                            stepNumber: '2',
                            icon: Icons.check_circle_outline_rounded,
                            title: 'Tap "Allow" on the Dialog',
                            description: 'Confirm the prompt so OneNotify stays active 24/7 in the background.',
                            cardColor: cardColor,
                            accentColor: accentColor,
                          ),
                          const SizedBox(height: 14),
                          _buildStepCard(
                            stepNumber: '3',
                            icon: Icons.rocket_launch_rounded,
                            title: 'Continuous Capture Ready',
                            description: 'Your timeline will now capture alerts even overnight while sleeping.',
                            cardColor: cardColor,
                            accentColor: accentColor,
                          ),
                        ]
                      : [
                          _buildStepCard(
                            stepNumber: '1',
                            icon: Icons.touch_app_rounded,
                            title: 'Tap "Grant Notification Access"',
                            description: 'We will take you directly to Android\'s Special Access screen.',
                            cardColor: cardColor,
                            accentColor: accentColor,
                          ),
                          const SizedBox(height: 14),
                          _buildStepCard(
                            stepNumber: '2',
                            icon: Icons.toggle_on_rounded,
                            title: 'Find OneNotify & Turn Switch ON',
                            description: 'Locate OneNotify in the list and toggle the switch to active.',
                            cardColor: cardColor,
                            accentColor: accentColor,
                          ),
                          const SizedBox(height: 14),
                          _buildStepCard(
                            stepNumber: '3',
                            icon: Icons.arrow_back_rounded,
                            title: 'Press Back to Return',
                            description: 'Once enabled, return right here. We will connect automatically!',
                            cardColor: cardColor,
                            accentColor: accentColor,
                          ),
                        ],
                ),
              ),
              const SizedBox(height: 20),
              // Main Action Button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: primaryColor.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: widget.onGrantPressed,
                  icon: Icon(
                    widget.isBatteryExemption ? Icons.battery_alert_rounded : Icons.settings_suggest_rounded,
                    size: 22,
                  ),
                  label: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Secondary Check Again Button
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[400],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: widget.onCheckAgain,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'I already enabled it — Check status again',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required IconData icon,
    required String title,
    required String description,
    required Color cardColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: accentColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
