import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:http/http.dart' as http;
import 'package:frontend/config/api_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/services/booking_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/screens/pdf_viewer_screen.dart';
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:frontend/screens/image_viewer_screen.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/theme/theme_notifier.dart';
import 'package:frontend/screens/patient/lab_booking_screen.dart';
import 'package:frontend/theme/glassmorphism.dart';
import 'package:frontend/widgets/shared_glass_components.dart';
import 'package:frontend/theme/app_theme.dart';
class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final user = authProvider.user;
    final bool isDarkMode = themeNotifier.isDarkMode;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> tabs = [
      PatientHomeTab(onNavigate: _navigateToTab, isDarkMode: isDarkMode),
      PatientServicesTab(isDarkMode: isDarkMode),
      PatientProfileTab(user: user, isDarkMode: isDarkMode),
    ];

    final scaffoldBg = isDarkMode ? const Color(0xFF0F0F1A) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.getBackgroundGradient(isDarkMode),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E2E) : Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black87),
        title: Text(
          'MedVerse',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: isDarkMode ? Colors.white : AppTheme.secondaryColor),
            onPressed: () => showGlassSettingsModal(
              context,
              isDarkMode,
              () => themeNotifier.toggleDarkMode(),
              () => authProvider.signOut(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: KeyedSubtree(
            key: ValueKey(_currentIndex),
            child: tabs[_currentIndex],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/chatbot'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        tooltip: 'AI Chatbot',
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.smart_toy_outlined),
      ),
      bottomNavigationBar: GlassBottomNav(
        currentIndex: _currentIndex,
        onTap: _navigateToTab,
        isDarkMode: isDarkMode,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.medical_services_outlined), activeIcon: Icon(Icons.medical_services), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    ),
    );
  }
}

// ----------------------------------------------------
// TAB 1: HOME TAB
// ----------------------------------------------------
class PatientHomeTab extends StatefulWidget {
  final Function(int) onNavigate;
  final bool isDarkMode;
  const PatientHomeTab({super.key, required this.onNavigate, required this.isDarkMode});

  @override
  State<PatientHomeTab> createState() => _PatientHomeTabState();
}

class _PatientHomeTabState extends State<PatientHomeTab> {
  final BookingService _bookingService = BookingService();
  final PageController _tipsController = PageController();
  Timer? _carouselTimer;
  int _activeTipIndex = 0;

  Map<String, dynamic>? _nextAppointment;
  bool _isLoading = true;

  final List<Map<String, String>> _healthTips = [
    {
      'title': '💧 Drink Water',
      'desc': 'Stay hydrated! Drink at least 8-10 glasses (2.5L) of water daily for energy.'
    },
    {
      'title': '🚶 Walk 30 mins',
      'desc': 'Keep moving! A daily 30-minute brisk walk boosts heart health & mood.'
    },
    {
      'title': '😴 Sleep Cycle',
      'desc': 'Rest well! Aim for 7-8 hours of sound sleep daily to recharge your body.'
    },
    {
      'title': '🥗 Healthy Diet',
      'desc': 'Fuel clean! Incorporate fresh green vegetables, fibers & proteins.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _startTipsCarousel();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _tipsController.dispose();
    super.dispose();
  }

  void _startTipsCarousel() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_tipsController.hasClients) {
        _activeTipIndex = (_activeTipIndex + 1) % _healthTips.length;
        _tipsController.animateToPage(
          _activeTipIndex,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchDashboardData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    try {
      // 1. Fetch appointments to find closest upcoming
      final appts = await _bookingService.getUserAppointments(user.uid);
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      Map<String, dynamic>? nextAppt;

      final upcoming = appts.where((appt) {
        final dateStr = appt['date'] ?? '';
        final status = appt['status']?.toString().toLowerCase() ?? '';
        if (status == 'rejected' || status == 'cancelled' || status == 'completed') {
          return false;
        }
        try {
          final apptDate = DateFormat('yyyy-MM-dd').parse(dateStr);
          final todayDate = DateFormat('yyyy-MM-dd').parse(todayStr);
          return apptDate.isAfter(todayDate) || dateStr == todayStr;
        } catch (_) {
          return false;
        }
      }).toList();

      if (upcoming.isNotEmpty) {
        upcoming.sort((a, b) {
          final cmp = (a['date'] ?? '').compareTo(b['date'] ?? '');
          if (cmp != 0) return cmp;
          return (a['time_slot'] ?? '').compareTo(b['time_slot'] ?? '');
        });
        nextAppt = upcoming.first;
      }

      if (mounted) {
        setState(() {
          _nextAppointment = nextAppt;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appt) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = widget.isDarkMode;
        final textColor = isDark ? Colors.white : Colors.black87;
        final subtitleColor = isDark ? Colors.white60 : Colors.grey[500];
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Appointment Details',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor),
          ),
          content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Doctor: ${appt['doctor_name']}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            Text('Date: ${appt['date']}', style: GoogleFonts.outfit(fontSize: 14, color: textColor)),
            Text('Time Slot: ${appt['time_slot']}', style: GoogleFonts.outfit(fontSize: 14, color: textColor)),
            Text('Status: ${appt['status']?.toString().toUpperCase()}', style: GoogleFonts.outfit(fontSize: 14, color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Symptoms/Notes:', style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(appt['symptoms'] ?? 'No notes provided', style: GoogleFonts.outfit(fontSize: 14, fontStyle: FontStyle.italic, color: textColor)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[700];

    return _isLoading
        ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
        : RefreshIndicator(
            onRefresh: _fetchDashboardData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Hero Card (matching Doctor Dashboard style)
                  _buildHeroCard(theme, user, isDark),
                  const SizedBox(height: 24),

                  // AI Quick Actions (2x3 Grid)
                  Text(
                    'AI Services & Quick Actions',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.25,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    children: [
                      _buildQuickActionCard(
                        context,
                        'MediDoc Analyze',
                        'Prescription OCR Scanner',
                        AppTheme.pastelBlue,
                        Icons.document_scanner_outlined,
                        () => Navigator.pushNamed(context, '/ocr-reader'),
                        isDark,
                      ),

                      _buildQuickActionCard(
                        context,
                        'Medical Records',
                        'Firebase storage documents',
                        AppTheme.secondaryColor,
                        Icons.folder_shared_outlined,
                        () => widget.onNavigate(2),
                        isDark,
                      ),
                      _buildQuickActionCard(
                        context,
                        'Reminder',
                        'Manage daily dosage times',
                        Colors.orangeAccent,
                        Icons.alarm,
                        () => Navigator.pushNamed(context, '/medicine-reminders'),
                        isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Health Tips Carousel (Auto-sliding)
                  Text(
                    'Health & Wellness Tips',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: PageView.builder(
                      controller: _tipsController,
                      itemCount: _healthTips.length,
                      onPageChanged: (idx) {
                        setState(() {
                          _activeTipIndex = idx;
                        });
                      },
                      itemBuilder: (context, idx) {
                        final tip = _healthTips[idx];
                        return Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(color: isDark ? Colors.black38 : Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  tip['title']!,
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: theme.primaryColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tip['desc']!,
                                  style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
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

  Widget _buildHeroCard(ThemeData theme, dynamic user, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final borderClr = isDark ? Colors.white.withOpacity(0.08) : theme.primaryColor.withOpacity(0.15);
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderClr, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : theme.primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Gradient accent
            Positioned(
              top: -20, right: -20,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.primaryColor.withOpacity(isDark ? 0.08 : 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                        child: Icon(Icons.person, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Welcome, ${user?.name ?? "Patient"}',
                          style: GoogleFonts.outfit(fontSize: 18, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'NEXT APPOINTMENT',
                      style: GoogleFonts.outfit(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _nextAppointment == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No upcoming appointments',
                              style: GoogleFonts.outfit(fontSize: 15, color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: () => widget.onNavigate(1),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('Book Appointment', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nextAppointment!['doctor_name'] ?? 'Doctor',
                              style: GoogleFonts.outfit(fontSize: 17, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.calendar_month, size: 14, color: isDark ? Colors.white60 : theme.primaryColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${_nextAppointment!['date']} • ${_nextAppointment!['time_slot']}',
                                    style: GoogleFonts.outfit(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: () => _showAppointmentDetails(_nextAppointment!),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('View Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, String title, String subtitle, Color color, IconData icon, VoidCallback onTap, bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[100]!),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black38 : Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.outfit(fontSize: 9, color: isDark ? Colors.white54 : Colors.grey[500]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// TAB 2: SERVICES TAB
// ----------------------------------------------------
class PatientServicesTab extends StatefulWidget {
  final bool isDarkMode;
  const PatientServicesTab({super.key, required this.isDarkMode});

  @override
  State<PatientServicesTab> createState() => _PatientServicesTabState();
}

class _PatientServicesTabState extends State<PatientServicesTab> {
  final BookingService _bookingService = BookingService();
  String? _selectedService; // null (select), 'doctor', 'lab'

  // Doctor search & chips
  List<dynamic> _allDoctors = [];
  List<dynamic> _filteredDoctors = [];
  bool _isDoctorsLoading = false;
  String _doctorSearch = '';
  String _doctorFilterChip = 'All';

  final List<String> _specialistChips = [
    'All',
    'General Physician',
    'Dentist',
    'Ophthalmologist',
    'Cardiologist',
    'Orthopedic',
    'Neurologist',
    'Dermatologist',
    'Pediatrician',
  ];

  // Lab Booking — maps patient-facing names to LabService predefined test names
  final Map<String, String> _labTestNameMapping = {
    'Blood Test': 'CBC (Complete Blood Count)',
    'CBC': 'CBC (Complete Blood Count)',
    'Sugar': 'Blood Glucose / HbA1c',
    'Liver': 'Liver Function Test (LFT)',
    'Kidney': 'Kidney Function Test (KFT)',
    'Thyroid': 'Thyroid Profile (T3, T4, TSH)',
    'Vitamin': 'Vitamin D3 & B12',
    'Urine': 'Urine Analysis',
  };

  final List<Map<String, String>> _labTests = [
    {'name': 'Blood Test', 'desc': 'Complete health checkup'},
    {'name': 'CBC', 'desc': 'Complete Blood Count parameters'},
    {'name': 'Sugar', 'desc': 'Diabetic HbA1c glucose levels'},
    {'name': 'Liver', 'desc': 'LFT metabolic profiles'},
    {'name': 'Kidney', 'desc': 'KFT urine/serum creatinine'},
    {'name': 'Thyroid', 'desc': 'TSH hormonal panel check'},
    {'name': 'Vitamin', 'desc': 'D3 & B12 nutrient values'},
    {'name': 'Urine', 'desc': 'Urinalysis infection profiles'},
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchDoctors() async {
    setState(() => _isDoctorsLoading = true);
    try {
      final list = await _bookingService.getVerifiedDoctors();
      setState(() {
        _allDoctors = list;
        _isDoctorsLoading = false;
        _filterDoctors();
      });
    } catch (_) {
      setState(() => _isDoctorsLoading = false);
    }
  }

  void _filterDoctors() {
    setState(() {
      _filteredDoctors = _allDoctors.where((doc) {
        final name = (doc['name'] ?? '').toString().toLowerCase();
        final qual = (doc['qualification'] ?? '').toString().toLowerCase();
        final dept = (doc['department'] ?? doc['category'] ?? '').toString().toLowerCase();
        final spec = (doc['specialization'] ?? '').toString().toLowerCase();

        final matchesSearch = name.contains(_doctorSearch.toLowerCase()) ||
            qual.contains(_doctorSearch.toLowerCase()) ||
            dept.contains(_doctorSearch.toLowerCase()) ||
            spec.contains(_doctorSearch.toLowerCase());

        bool matchesChip = true;
        if (_doctorFilterChip != 'All') {
          // Normalize chip and database strings to match correctly
          final filter = _doctorFilterChip.toLowerCase();
          matchesChip = dept.contains(filter) || spec.contains(filter) ||
              (filter.contains('eye') && dept.contains('ophthalmologist')) ||
              (filter.contains('skin') && dept.contains('dermatologist')) ||
              (filter.contains('child') && dept.contains('pediatrician'));
        }

        return matchesSearch && matchesChip;
      }).toList();
    });
  }

  void _navigateToLabBooking(String testName) {
    final predefinedTestName = _labTestNameMapping[testName] ?? testName;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LabBookingScreen(selectedTest: predefinedTestName),
      ),
    );
  }

  IconData _getLabTestIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('blood') || lower.contains('cbc')) return Icons.bloodtype_outlined;
    if (lower.contains('sugar')) return Icons.water_drop_outlined;
    if (lower.contains('liver')) return Icons.monitor_heart_outlined;
    if (lower.contains('kidney')) return Icons.clean_hands_outlined;
    if (lower.contains('thyroid')) return Icons.health_and_safety_outlined;
    if (lower.contains('vitamin')) return Icons.medication_outlined;
    if (lower.contains('urine')) return Icons.science_outlined;
    return Icons.science_outlined;
  }

  Color _getLabTestColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('blood') || lower.contains('cbc')) return Colors.redAccent;
    if (lower.contains('sugar')) return Colors.lightBlue;
    if (lower.contains('vitamin')) return Colors.orangeAccent;
    if (lower.contains('urine')) return Colors.amber;
    return Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[600];

    if (_selectedService == null) {
      // Services Index Grid
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'MediNexa Services',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 6),
              Text(
                'Book consultations, diagnostic labs, or use our AI features.',
                style: GoogleFonts.outfit(fontSize: 14, color: subtitleColor),
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                children: [
                  _buildServiceChoiceCard(
                    'Book\nAppointment',
                    'Consult verified specialists',
                    Colors.purple,
                    Icons.person_add_alt_1_outlined,
                    () {
                      setState(() { _selectedService = 'doctor'; });
                      _fetchDoctors();
                    },
                    isDark,
                  ),
                  _buildServiceChoiceCard(
                    'Lab Test\nBooking',
                    'Book diagnostic panels',
                    Colors.teal,
                    Icons.science_outlined,
                    () => setState(() { _selectedService = 'lab'; }),
                    isDark,
                  ),
                  _buildServiceChoiceCard(
                    'Appointment\nHistory',
                    'View consultation timeline',
                    Colors.orange,
                    Icons.history,
                    () => Navigator.pushNamed(context, '/medical-history'),
                    isDark,
                  ),
                  _buildServiceChoiceCard(
                    'Lab\nReports',
                    'AI explanation summaries',
                    AppTheme.accentColor,
                    Icons.assignment_outlined,
                    () => Navigator.pushNamed(context, '/lab-reports'),
                    isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedService == 'doctor') {
      final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
      final cardBorder = isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!;
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => setState(() => _selectedService = null),
          ),
          title: Text('Find Specialist', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        ),
        body: _isDoctorsLoading
            ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextFormField(
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search doctors...',
                        hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[500]),
                        prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : null),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      onChanged: (val) { _doctorSearch = val; _filterDoctors(); },
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _specialistChips.map((chip) {
                        final isSel = _doctorFilterChip == chip;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(chip, style: GoogleFonts.outfit(fontSize: 12,
                              color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87))),
                            selected: isSel,
                            selectedColor: theme.colorScheme.primary,
                            backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey[100],
                            side: BorderSide(color: isSel ? theme.colorScheme.primary : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!)),
                            onSelected: (selected) {
                              if (selected) setState(() { _doctorFilterChip = chip; _filterDoctors(); });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _filteredDoctors.isEmpty
                      ? Center(child: Text('No verified doctors found.', style: GoogleFonts.outfit(color: subtitleColor)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredDoctors.length,
                          itemBuilder: (context, idx) {
                            final doc = _filteredDoctors[idx];
                            final String qual = doc['qualification'] ?? 'Physician';
                            final String dept = doc['department'] ?? doc['category'] ?? 'N/A';
                            final String fee = doc['consultationFee']?.toString() ?? '500';
                            final String exp = doc['experience'] ?? '3';
                            final String clinicName = doc['clinicName'] ?? '';
                            final String clinicAddress = doc['clinicAddress'] ?? '';
                            final String mapsUrl = doc['googleMapsUrl'] ?? '';

                            return AnimatedContainer(
                              duration: Duration(milliseconds: 200 + idx * 50),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cardBorder),
                                boxShadow: [
                                  BoxShadow(color: isDark ? Colors.black38 : Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: theme.colorScheme.primary.withOpacity(isDark ? 0.25 : 0.1),
                                          child: Text(
                                            doc['name'].toString().isNotEmpty ? doc['name'].toString()[0].toUpperCase() : 'D',
                                            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                doc['name'].toString(),
                                                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                '$qual • $dept',
                                                style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.star, color: Colors.amber, size: 14),
                                                  const SizedBox(width: 3),
                                                  Text('4.8', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                                                  const SizedBox(width: 10),
                                                  Icon(Icons.work_history_outlined, size: 13, color: subtitleColor),
                                                  const SizedBox(width: 3),
                                                  Text('$exp yr exp', style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                     if (clinicName.isNotEmpty || clinicAddress.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.location_on, size: 14, color: theme.colorScheme.primary),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (clinicName.isNotEmpty)
                                                  Text(clinicName, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                                                if (clinicAddress.isNotEmpty)
                                                  Text(clinicAddress, style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor)),
                                                if (mapsUrl.isNotEmpty)
                                                  InkWell(
                                                    onTap: () async {
                                                      final url = Uri.parse(mapsUrl);
                                                      if (await canLaunchUrl(url)) {
                                                        await launchUrl(url);
                                                      }
                                                    },
                                                    child: Padding(
                                                      padding: const EdgeInsets.only(top: 4.0),
                                                      child: Text('View on Google Maps', style: GoogleFonts.outfit(fontSize: 11, color: Colors.blue, decoration: TextDecoration.underline)),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '₹$fee / consult',
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.primary),
                                        ),
                                        FilledButton(
                                          onPressed: () => Navigator.pushNamed(context, '/book-appointment', arguments: doc['uid']),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: theme.colorScheme.primary,
                                            foregroundColor: isDark ? Colors.black : Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                          child: Text('Book', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
      );
    }

    // Otherwise: Lab test selection
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final cardBorder = isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => setState(() => _selectedService = null),
        ),
        title: Text('Lab Diagnostics', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select Lab Test',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.1,
              ),
              itemCount: _labTests.length,
              itemBuilder: (context, idx) {
                final test = _labTests[idx];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + idx * 60),
                  curve: Curves.easeOut,
                  builder: (context, val, child) => Opacity(opacity: val, child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child)),
                  child: InkWell(
                    onTap: () => _navigateToLabBooking(test['name']!),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black38 : Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _getLabTestColor(test['name']!).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_getLabTestIcon(test['name']!), color: _getLabTestColor(test['name']!), size: 18),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            test['name']!,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            test['desc']!,
                            style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceChoiceCard(String title, String desc, Color color, IconData icon, VoidCallback onTap, bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : color.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black38 : color.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : Colors.grey[500],
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// TAB 3: PROFILE TAB
// ----------------------------------------------------
class PatientProfileTab extends StatefulWidget {
  final UserModel user;
  final bool isDarkMode;
  const PatientProfileTab({super.key, required this.user, required this.isDarkMode});

  @override
  State<PatientProfileTab> createState() => _PatientProfileTabState();
}

class _PatientProfileTabState extends State<PatientProfileTab> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingDoc = false;

  void _openEditProfileDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: widget.user.name);
    final phoneController = TextEditingController(text: widget.user.phoneNumber ?? '');
    final ageController = TextEditingController(text: widget.user.age ?? '');
    final addressController = TextEditingController(text: widget.user.address ?? '');
    final contactController = TextEditingController(text: widget.user.emergencyContact ?? '');
    final allergiesController = TextEditingController(text: widget.user.allergies ?? '');
    final chronicController = TextEditingController(text: widget.user.chronicDiseases ?? '');
    final medicinesController = TextEditingController(text: widget.user.currentMedicines ?? '');
    
    String gender = 'Male';
    final rawGender = widget.user.gender?.trim().toLowerCase();
    if (rawGender == 'female') {
      gender = 'Female';
    } else if (rawGender == 'other') {
      gender = 'Other';
    }

    String bloodGroup = 'O+';
    final rawBg = widget.user.bloodGroup?.trim().toUpperCase();
    final allowedBgs = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    if (allowedBgs.contains(rawBg)) {
      bloodGroup = rawBg!;
    }

    showDialog(
      context: context,
      builder: (context) {
        final isDark = widget.isDarkMode;
        final textColor = isDark ? Colors.white : Colors.black87;
        return AnimatedPadding(
          padding: MediaQuery.of(context).viewInsets,
          duration: const Duration(milliseconds: 100),
          curve: Curves.decelerate,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(20),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Edit Profile', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                    ),
                    TextFormField(
                      controller: ageController,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: gender,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                      items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g, style: TextStyle(color: textColor)))).toList(),
                      onChanged: (val) {
                        if (val != null) gender = val;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: bloodGroup,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(labelText: 'Blood Group', border: OutlineInputBorder()),
                      items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((bg) => DropdownMenuItem(value: bg, child: Text(bg, style: TextStyle(color: textColor)))).toList(),
                      onChanged: (val) {
                        if (val != null) bloodGroup = val;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressController,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contactController,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(labelText: 'Emergency Contact', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Text('Medical Information', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: allergiesController,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(labelText: 'Allergies', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: chronicController,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(labelText: 'Chronic Diseases', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: medicinesController,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(labelText: 'Current Medicines', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final updateData = {
                'name': nameController.text.trim(),
                'phoneNumber': phoneController.text.trim(),
                'age': ageController.text.trim(),
                'gender': gender,
                'bloodGroup': bloodGroup,
                'address': addressController.text.trim(),
                'emergencyContact': contactController.text.trim(),
                'allergies': allergiesController.text.trim(),
                'chronicDiseases': chronicController.text.trim(),
                'currentMedicines': medicinesController.text.trim(),
              };

              try {
                await _db.collection('users').doc(widget.user.uid).update(updateData);
                
                // Trigger reload of user model state
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await authProvider.refreshUser();

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile details updated successfully!')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile update failed.')),
                  );
                }
              }
            },
            child: Text('Save', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
      },
    );
  }

  Future<Map<String, String>?> _showDocDetailsDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Upload Document', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Document Name *',
                  hintText: 'e.g. Previous Prescription, MRI Scan',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'e.g. Taken on June 2026',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Document name is required')),
                  );
                  return;
                }
                Navigator.pop(ctx, {
                  'name': nameController.text.trim(),
                  'desc': descController.text.trim(),
                });
              },
              child: const Text('Next'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadDocument(String fileId, String filename) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final url = '${ApiConfig.baseUrl}/storage/file/$fileId';
      
      final response = await http.get(
        Uri.parse(url),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );
      
      if (response.statusCode != 200) {
        throw Exception("Failed to download file (HTTP ${response.statusCode})");
      }
      
      final bytes = response.bodyBytes;
      String path = "";
      String finalFilename = filename;
      bool wroteSuccessfully = false;
      String filePath = "";

      if (Platform.isAndroid) {
        try {
          final dir = Directory('/storage/emulated/0/Download');
          if (await dir.exists()) {
            filePath = "${dir.path}/$finalFilename";
            var file = File(filePath);
            if (await file.exists()) {
              final extIdx = finalFilename.lastIndexOf('.');
              final nameWithoutExt = extIdx != -1 ? finalFilename.substring(0, extIdx) : finalFilename;
              final ext = extIdx != -1 ? finalFilename.substring(extIdx) : '';
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              filePath = "${dir.path}/${nameWithoutExt}_$timestamp$ext";
            }
            file = File(filePath);
            await file.writeAsBytes(bytes);
            wroteSuccessfully = true;
          }
        } catch (e) {
          debugPrint("Failed to write to public Download folder: $e");
        }
      }

      if (!wroteSuccessfully) {
        final appDir = await getApplicationDocumentsDirectory();
        path = appDir.path;
        filePath = "$path/$finalFilename";
        var file = File(filePath);
        if (await file.exists()) {
          final extIdx = finalFilename.lastIndexOf('.');
          final nameWithoutExt = extIdx != -1 ? finalFilename.substring(0, extIdx) : finalFilename;
          final ext = extIdx != -1 ? finalFilename.substring(extIdx) : '';
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          filePath = "$path/${nameWithoutExt}_$timestamp$ext";
        }
        file = File(filePath);
        await file.writeAsBytes(bytes);
        wroteSuccessfully = true;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report downloaded successfully'),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                try {
                  await OpenFilex.open(filePath);
                } catch (e) {
                  debugPrint("OpenFilex error: $e");
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save file: $e')),
        );
      }
    }
  }



  List<dynamic> _patientDocuments = [];
  bool _isLoadingDocs = false;

  Future<void> _fetchDocuments(Function(void Function()) setSheetState) async {
    setSheetState(() {
      _isLoadingDocs = true;
    });
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final url = '${ApiConfig.baseUrl}/storage/patient';
      final response = await http.get(
        Uri.parse(url),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );
      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        setSheetState(() {
          _patientDocuments = decoded;
        });
      }
    } catch (e) {
      debugPrint("Error fetching documents: $e");
    } finally {
      setSheetState(() {
        _isLoadingDocs = false;
      });
    }
  }

  void _showDocumentsListSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Fetch documents when the sheet is shown
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_patientDocuments.isEmpty && !_isLoadingDocs) {
                _fetchDocuments(setSheetState);
              }
            });

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Medical Documents', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                          _isUploadingDoc
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                              : IconButton(
                                  icon: const Icon(Icons.upload_file_outlined, color: Colors.blue),
                                  onPressed: () async {
                                    final details = await _showDocDetailsDialog();
                                    if (details == null) return;
                                    
                                    setSheetState(() => _isUploadingDoc = true);
                                    try {
                                      final FilePickerResult? result = await FilePicker.pickFiles(
                                        type: FileType.custom,
                                        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                                      );
                                      if (result != null && result.files.single.path != null) {
                                        final File localFile = File(result.files.single.path!);
                                        final String originalFilename = result.files.single.name;
                                        final int size = await localFile.length();
                                        
                                        if (size > 10 * 1024 * 1024) {
                                          throw Exception('File size exceeds the 10MB limit (10MB maximum)');
                                        }
                                        
                                        final ext = originalFilename.split('.').last.toLowerCase();
                                        if (ext != 'pdf' && ext != 'jpg' && ext != 'jpeg' && ext != 'png') {
                                          throw Exception('Unsupported file type. Only PDF, JPG, JPEG, and PNG are allowed.');
                                        }
                                        
                                        String contentType = 'application/pdf';
                                        if (ext == 'png') {
                                          contentType = 'image/png';
                                        } else if (ext == 'jpg' || ext == 'jpeg') {
                                          contentType = 'image/jpeg';
                                        }
                                        
                                        final uri = Uri.parse('${ApiConfig.baseUrl}/storage/upload');
                                        final request = http.MultipartRequest('POST', uri);
                                        final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
                                        if (idToken != null) {
                                          request.headers['Authorization'] = 'Bearer $idToken';
                                        }
                                        
                                        request.fields['patientId'] = widget.user.uid;
                                        request.fields['reportType'] = 'patient_document';
                                        request.fields['documentName'] = details['name']!;
                                        
                                        final stream = http.ByteStream(localFile.openRead());
                                        final multipartFile = http.MultipartFile(
                                          'file',
                                          stream,
                                          size,
                                          filename: originalFilename,
                                          contentType: MediaType.parse(contentType),
                                        );
                                        request.files.add(multipartFile);
                                        
                                        final response = await request.send();
                                        final responseBody = await response.stream.bytesToString();
                                        
                                        if (response.statusCode == 201) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Document uploaded successfully!')),
                                          );
                                          // Fetch fresh list from MongoDB GridFS via Flask API
                                          await _fetchDocuments(setSheetState);
                                        } else {
                                          final errDecoded = jsonDecode(responseBody);
                                          throw Exception(errDecoded['error'] ?? 'Upload failed');
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint('Document upload error: $e');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Upload failed: ${e.toString().replaceAll('Exception: ', '')}')),
                                      );
                                    } finally {
                                      setSheetState(() => _isUploadingDoc = false);
                                    }
                                  },
                                ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _isLoadingDocs
                            ? const Center(child: CircularProgressIndicator())
                            : _patientDocuments.isEmpty
                                ? Center(
                                    child: Text('No uploaded documents found.', style: GoogleFonts.outfit(color: Colors.grey[500])),
                                  )
                                : RefreshIndicator(
                                    onRefresh: () => _fetchDocuments(setSheetState),
                                    child: ListView.builder(
                                      controller: scrollController,
                                      itemCount: _patientDocuments.length,
                                      itemBuilder: (context, idx) {
                                        final doc = _patientDocuments[idx];
                                        final name = doc['documentName'] ?? doc['originalFilename'] ?? 'Document';
                                        final size = doc['fileSize'] ?? '0 KB';
                                        final fileId = doc['fileId'] ?? '';
                                        final rawType = doc['contentType'] ?? 'application/pdf';
                                        final type = rawType.toString().contains('pdf') ? 'PDF' : 'IMAGE';

                                        final isPdf = type == 'PDF';

                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(color: Colors.grey[200]!),
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: isPdf ? Colors.red.withOpacity(0.12) : Colors.blue.withOpacity(0.12),
                                              child: Icon(
                                                isPdf ? Icons.picture_as_pdf : Icons.image,
                                                color: isPdf ? Colors.red : Colors.blue,
                                              ),
                                            ),
                                            title: Text(
                                              name,
                                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                Text(
                                                  isPdf ? 'PDF  •  $size' : 'Image  •  $size',
                                                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500]),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Uploaded by: You',
                                                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.blue[600], fontWeight: FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.blue, size: 20),
                                                  onPressed: () async {
                                                    if (isPdf) {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => PdfViewerScreen(
                                                            fileId: fileId,
                                                            filename: name,
                                                          ),
                                                        ),
                                                      );
                                                    } else {
                                                      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
                                                      if (context.mounted) {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) => FullScreenImageViewer(
                                                              imageUrl: '${ApiConfig.baseUrl}/storage/file/$fileId',
                                                              title: name,
                                                              headers: {'Authorization': 'Bearer $idToken'},
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  tooltip: 'View Document',
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.download, color: Colors.green, size: 20),
                                                  onPressed: () => _downloadDocument(fileId, "$name.${type.toLowerCase()}"),
                                                  tooltip: 'Download Document',
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                  onPressed: () async {
                                                    final confirm = await showDialog<bool>(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: const Text('Delete Document?'),
                                                        content: const Text('Are you sure you want to delete this document permanently?'),
                                                        actions: [
                                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirm != true) return;

                                                    try {
                                                      // Delete from Backend Storage
                                                      if (fileId.toString().isNotEmpty) {
                                                        final uri = Uri.parse('${ApiConfig.baseUrl}/storage/file/$fileId');
                                                        final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
                                                        await http.delete(
                                                          uri,
                                                          headers: idToken != null ? {'Authorization': 'Bearer $idToken'} : {},
                                                        );
                                                      }

                                                      // Re-fetch documents from Flask backend
                                                      await _fetchDocuments(setSheetState);
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Document deleted successfully.')),
                                                      );
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Delete failed: $e')),
                                                      );
                                                    }
                                                  },
                                                  tooltip: 'Delete Document',
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _previewDocument(String name, String fileId) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          fileId: fileId,
          filename: name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = widget.user.profileImageUrl ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Demographics Header Card
          GlassContainer(
            isDarkMode: widget.isDarkMode,
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: theme.primaryColor.withOpacity(0.08),
                    backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? Text(
                            widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'P',
                            style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: theme.primaryColor),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.user.name, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87)),
                        const SizedBox(height: 4),
                        Text(
                          'Age: ${widget.user.age ?? "N/A"}  •  Gender: ${widget.user.gender ?? "N/A"}',
                          style: GoogleFonts.outfit(fontSize: 12, color: widget.isDarkMode ? Colors.white60 : Colors.grey[600]),
                        ),
                        Text(
                          'Blood Group: ${widget.user.bloodGroup ?? "N/A"}',
                          style: GoogleFonts.outfit(fontSize: 12, color: widget.isDarkMode ? Colors.white60 : Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Personal Details Card
          GlassContainer(
            isDarkMode: widget.isDarkMode,
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Personal Information', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87)),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                        onPressed: _openEditProfileDialog,
                      ),
                    ],
                  ),
                  Divider(color: widget.isDarkMode ? Colors.white24 : null),
                  _buildProfileRow('Email', widget.user.email),
                  _buildProfileRow('Phone', widget.user.phoneNumber ?? 'Not specified'),
                  _buildProfileRow('Address', widget.user.address ?? 'Not specified'),
                  _buildProfileRow('Emergency Contact', widget.user.emergencyContact ?? 'Not specified'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Medical Information Card
          GlassContainer(
            isDarkMode: widget.isDarkMode,
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Medical History Records', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87)),
                  Divider(color: widget.isDarkMode ? Colors.white24 : null),
                  _buildProfileRow('Allergies', widget.user.allergies ?? 'None declared'),
                  _buildProfileRow('Chronic Illnesses', widget.user.chronicDiseases ?? 'None declared'),
                  _buildProfileRow('Ongoing Medications', widget.user.currentMedicines ?? 'None declared'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Documents Roster Button Card
          GlassContainer(
            isDarkMode: widget.isDarkMode,
            borderRadius: 20,
            child: ListTile(
              leading: const Icon(Icons.folder_shared_outlined, color: Colors.blue),
              title: Text('My Health Documents', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: widget.isDarkMode ? Colors.white : Colors.black87)),
              subtitle: Text('Manage prescriptions, blood panels, MRI, insurances', style: GoogleFonts.outfit(fontSize: 11, color: widget.isDarkMode ? Colors.white60 : Colors.grey[500])),
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: widget.isDarkMode ? Colors.white60 : Colors.black54),
              onTap: _showDocumentsListSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: GoogleFonts.outfit(fontSize: 12, color: widget.isDarkMode ? Colors.white60 : Colors.grey[500], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(val, style: GoogleFonts.outfit(fontSize: 13, color: widget.isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}


