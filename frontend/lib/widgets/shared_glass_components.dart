import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/glassmorphism.dart';
import '../theme/app_theme.dart';

class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isDarkMode;
  final List<BottomNavigationBarItem> items;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isDarkMode,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewPadding.bottom + 12,
      ),
      child: GlassContainer(
          isDarkMode: isDarkMode,
          borderRadius: 32,
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (index) {
              final isSelected = currentIndex == index;
              final item = items[index];
              final icon = isSelected ? (item.activeIcon ?? item.icon) : item.icon;
              final color = isSelected
                  ? AppTheme.primaryColor
                  : (isDarkMode ? Colors.white54 : Colors.black45);

              return GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      IconTheme(
                        data: IconThemeData(color: color, size: 24),
                        child: icon,
                      ),
                      if (isSelected && item.label != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          item.label!,
                          style: GoogleFonts.outfit(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      );
  }
}

class GlassLogoutDialog extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const GlassLogoutDialog({
    super.key,
    required this.isDarkMode,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassContainer(
        isDarkMode: isDarkMode,
        borderRadius: 28,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.logout_rounded,
              size: 48,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Logout',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to logout from MedVerse?',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Logout',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showGlassSettingsModal(BuildContext context, bool isDarkMode, Function toggleTheme, Function onLogout) {
  bool currentIsDark = isDarkMode;
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setStateSheet) {
          final textThemeColor = currentIsDark ? Colors.white : Colors.black87;
          final bottomPadding = MediaQuery.of(ctx).padding.bottom;
          return Container(
            margin: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + bottomPadding,
            ),
            child: GlassContainer(
              isDarkMode: currentIsDark,
              borderRadius: 32,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: currentIsDark ? Colors.white30 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Settings',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textThemeColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      currentIsDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      currentIsDark ? 'Light Mode' : 'Dark Mode',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: textThemeColor,
                      ),
                    ),
                    trailing: Switch(
                      value: currentIsDark,
                      onChanged: (val) {
                        toggleTheme();
                        setStateSheet(() {
                          currentIsDark = val;
                        });
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                  ),
                  Divider(color: currentIsDark ? Colors.white10 : Colors.black12, height: 16),
                  ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.notifications_outlined,
                  color: AppTheme.pastelBlue,
                ),
                title: Text(
                  'Notifications',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: currentIsDark ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/notifications');
                },
              ),
              Divider(color: currentIsDark ? Colors.white10 : Colors.black12, height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.accentColor,
                ),
                title: Text(
                  'About Us',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: currentIsDark ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      child: GlassContainer(
                        isDarkMode: currentIsDark,
                        padding: const EdgeInsets.all(24),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Column(
                                  children: [
                                    const Icon(Icons.local_hospital_outlined, size: 56, color: AppTheme.primaryColor),
                                    const SizedBox(height: 12),
                                    Text(
                                      'MedVerse',
                                      style: GoogleFonts.outfit(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: currentIsDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      'Your Intelligent Healthcare Companion',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                        color: currentIsDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'MedVerse is an AI-powered healthcare platform that connects Patients, Doctors, Laboratories, and Administrators through one secure and intelligent ecosystem.',
                                style: GoogleFonts.outfit(fontSize: 13, color: currentIsDark ? Colors.white70 : Colors.black87, height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.lock_outline, size: 18, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Privacy & Security',
                                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: currentIsDark ? Colors.white : Colors.black87),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your medical information is protected using secure authentication and encrypted communication. Only authorized users can access healthcare records based on their role.',
                                style: GoogleFonts.outfit(fontSize: 13, color: currentIsDark ? Colors.white70 : Colors.black54, height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Version Info',
                                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: currentIsDark ? Colors.white : Colors.black87),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Version: 1.0.0\nRelease: June 2026',
                                style: GoogleFonts.outfit(fontSize: 13, color: currentIsDark ? Colors.white70 : Colors.black54, height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.badge_outlined, size: 18, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Credits',
                                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: currentIsDark ? Colors.white : Colors.black87),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Designed & Developed by Alok Singh\n© 2026 MedVerse. All Rights Reserved.',
                                style: GoogleFonts.outfit(fontSize: 13, color: currentIsDark ? Colors.white70 : Colors.black54, height: 1.4),
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Divider(color: currentIsDark ? Colors.white10 : Colors.black12, height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.support_agent_rounded,
                  color: AppTheme.pastelBlue,
                ),
                title: Text(
                  'Contact Support',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: currentIsDark ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      child: GlassContainer(
                        isDarkMode: currentIsDark,
                        padding: const EdgeInsets.all(24),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Column(
                                  children: [
                                    const Icon(Icons.contact_support_outlined, size: 56, color: AppTheme.primaryColor),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Contact Support',
                                      style: GoogleFonts.outfit(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: currentIsDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  const Icon(Icons.email_outlined, size: 18, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Email',
                                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: currentIsDark ? Colors.white : Colors.black87),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'admin.medverse@gmail.com',
                                style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.bug_report_outlined, size: 18, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Report a Bug',
                                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: currentIsDark ? Colors.white : Colors.black87),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Found an issue? Send us a detailed description along with screenshots to help us improve MedVerse.',
                                style: GoogleFonts.outfit(fontSize: 13, color: currentIsDark ? Colors.white70 : Colors.black54, height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Feature Requests',
                                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: currentIsDark ? Colors.white : Colors.black87),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Have an idea for a new feature? We'd love to hear your suggestions for future updates.",
                                style: GoogleFonts.outfit(fontSize: 13, color: currentIsDark ? Colors.white70 : Colors.black54, height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 18, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Support Hours',
                                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: currentIsDark ? Colors.white : Colors.black87),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Monday – Friday\n9:00 AM – 6:00 PM (IST)',
                                style: GoogleFonts.outfit(fontSize: 13, color: currentIsDark ? Colors.white70 : Colors.black54, height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.code_rounded, size: 18, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Developer',
                                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: currentIsDark ? Colors.white : Colors.black87),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Alok Singh',
                                style: GoogleFonts.outfit(fontSize: 13, color: currentIsDark ? Colors.white70 : Colors.black54, height: 1.4),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Thank you for using MedVerse. Your feedback helps us build a smarter and more reliable healthcare platform.',
                                style: GoogleFonts.outfit(fontSize: 12, fontStyle: FontStyle.italic, color: currentIsDark ? Colors.white60 : Colors.black54, height: 1.4),
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Divider(color: currentIsDark ? Colors.white10 : Colors.black12, height: 16),
              InkWell(
                onTap: () {
                  Navigator.pop(context); // Close the settings sheet
                  showDialog(
                    context: context,
                    builder: (dCtx) => GlassLogoutDialog(
                      isDarkMode: currentIsDark,
                      onCancel: () => Navigator.pop(dCtx),
                      onConfirm: () async {
                        Navigator.pop(dCtx);
                        final result = onLogout();
                        if (result is Future) {
                          await result;
                        }
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                        }
                      },
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
                      const SizedBox(width: 16),
                      Text(
                        'Logout',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
        },
      );
    },
  );
}
