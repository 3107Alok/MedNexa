// ignore_for_file: deprecated_member_use, avoid_print
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/services/admin_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> tabs = [
      AdminHomeTab(
        isDarkMode: _isDarkMode,
        onCardTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
      AdminManagementTab(isDarkMode: _isDarkMode),
      AdminProfileTab(user: user, isDarkMode: _isDarkMode),
    ];

    final scaffoldBg = _isDarkMode ? const Color(0xFF0F0F1A) : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E2E) : Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _isDarkMode ? Colors.white : Colors.black87),
        title: Text(
          'MediNexa Admin',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _isDarkMode ? Colors.amber : Colors.blueGrey,
            ),
            onPressed: () {
              setState(() {
                _isDarkMode = !_isDarkMode;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.notifications_none_outlined, color: _isDarkMode ? Colors.white : Colors.black87),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon!')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: _isDarkMode ? Colors.white : Colors.black87),
            onPressed: () => authProvider.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: tabs[_currentIndex],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/chatbot'),
        backgroundColor: _isDarkMode ? const Color(0xFFBB86FC) : Colors.purple,
        foregroundColor: Colors.white,
        tooltip: 'AI Chatbot',
        child: const Icon(Icons.smart_toy_outlined),
      ),
      bottomNavigationBar: _buildGlassmorphicBottomNav(context),
    );
  }

  Widget _buildGlassmorphicBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    final navBg = _isDarkMode ? const Color(0xFF1E1E2E).withOpacity(0.85) : Colors.white.withOpacity(0.85);
    final borderColor = _isDarkMode ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.4);
    final shadowColor = _isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.06);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: navBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: _buildNavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', 0, theme),
                ),
              ),
              Expanded(
                child: Center(
                  child: _buildNavItem(Icons.grid_view_outlined, Icons.grid_view, 'Management', 1, theme),
                ),
              ),
              Expanded(
                child: Center(
                  child: _buildNavItem(Icons.person_outline, Icons.person, 'Profile', 2, theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData unselectedIcon, IconData selectedIcon, String label, int index, ThemeData theme) {
    final isSelected = _currentIndex == index;
    final activeColor = _isDarkMode ? Colors.cyanAccent : theme.primaryColor;
    final inactiveColor = _isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final itemBg = isSelected
        ? activeColor.withOpacity(0.12)
        : Colors.transparent;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: itemBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIcon : unselectedIcon,
                color: isSelected ? activeColor : inactiveColor,
                size: 24,
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: activeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// TAB 1: HOME TAB
// ----------------------------------------------------
class AdminHomeTab extends StatefulWidget {
  final Function(int) onCardTap;
  final bool isDarkMode;
  const AdminHomeTab({super.key, required this.onCardTap, required this.isDarkMode});

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  final AdminService _adminService = AdminService();
  Map<String, int> _stats = {'patients': 0, 'doctors': 0, 'appointments': 0, 'pendingVerifications': 0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final data = await _adminService.getDashboardStats();
      print("Received Stats:");
      print("{patients:${data['patients']}, doctors:${data['doctors']}, appointments:${data['appointments']}, pendingVerifications:${data['pendingVerifications']}}");
      if (mounted) {
        setState(() {
          _stats = data;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      print("Error in _fetchStats: $e");
      print(stack);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchStats,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1.0 - value)),
                    child: child,
                  ),
                );
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Modern Premium Welcome Banner
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.isDarkMode
                              ? [
                                  const Color(0xFF1F1F35),
                                  const Color(0xFF121220),
                                ]
                              : [
                                  theme.primaryColor,
                                  theme.primaryColor.withRed(10).withBlue(180),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: widget.isDarkMode
                            ? Border.all(color: Colors.white.withOpacity(0.08), width: 1.5)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: widget.isDarkMode
                                ? Colors.black.withOpacity(0.4)
                                : theme.primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          // Abstract Background Circles for high-end look
                          Positioned(
                            right: -50,
                            top: -50,
                            child: CircleAvatar(
                              radius: 120,
                              backgroundColor: Colors.white.withOpacity(widget.isDarkMode ? 0.03 : 0.08),
                            ),
                          ),
                          Positioned(
                            left: -30,
                            bottom: -50,
                            child: CircleAvatar(
                              radius: 80,
                              backgroundColor: Colors.white.withOpacity(widget.isDarkMode ? 0.02 : 0.05),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(26),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.admin_panel_settings_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Welcome Back,',
                                            style: GoogleFonts.outfit(
                                              fontSize: 14,
                                              color: Colors.white.withOpacity(0.8),
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          Text(
                                            'System Admin',
                                            style: GoogleFonts.outfit(
                                              fontSize: 24,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_month, color: Colors.white, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        todayStr,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'All servers and Firebase pipelines are active. Below is a unified view of MediNexa directories and statistics.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    color: Colors.white.withOpacity(0.9),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // AI Services Quick Links
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AI Diagnosis Tools',
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: widget.isDarkMode ? Colors.white : Colors.black87,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded, color: widget.isDarkMode ? Colors.grey[400] : Colors.grey, size: 18),
                      ],
                    ),
                    const SizedBox(height: 14),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              context,
                              '🩺 Medoc Analyze',
                              'OCR & AI Report Reader',
                              Colors.teal,
                              const [Color(0xFF009688), Color(0xFF00BFA5)],
                              Icons.document_scanner_rounded,
                              () => Navigator.pushNamed(context, '/ocr-reader'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildActionCard(
                              context,
                              '🤖 AI Assistant',
                              'Symptom chatbot',
                              Colors.blue,
                              const [Color(0xFF2196F3), Color(0xFF00BCD4)],
                              Icons.smart_toy_rounded,
                              () => Navigator.pushNamed(context, '/chatbot'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Clickable Stats Section
                    Text(
                      'Live Metrics Cockpit',
                      style: GoogleFonts.outfit(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : Colors.black87,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Column(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _buildStatGridItem(
                                  context,
                                  'Total Doctors',
                                  _stats['doctors'] ?? 0,
                                  const [Color(0xFF9C27B0), Color(0xFFE040FB)],
                                  Icons.medical_services_rounded,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => DoctorManagementScreen(isDarkMode: widget.isDarkMode))).then((_) => _fetchStats()),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildStatGridItem(
                                  context,
                                  'Total Patients',
                                  _stats['patients'] ?? 0,
                                  const [Color(0xFF1E88E5), Color(0xFF42A5F5)],
                                  Icons.people_alt_rounded,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => PatientManagementScreen(isDarkMode: widget.isDarkMode))).then((_) => _fetchStats()),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _buildStatGridItem(
                                  context,
                                  'Appointments',
                                  _stats['appointments'] ?? 0,
                                  const [Color(0xFF00897B), Color(0xFF26A69A)],
                                  Icons.calendar_month_rounded,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsManagementScreen(isDarkMode: widget.isDarkMode))),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildStatGridItem(
                                  context,
                                  'Pending Verif.',
                                  _stats['pendingVerifications'] ?? 0,
                                  const [Color(0xFFFB8C00), Color(0xFFFFB74D)],
                                  Icons.verified_user_rounded,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => PendingVerificationsScreen(isDarkMode: widget.isDarkMode))).then((_) => _fetchStats()),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _buildStatGridItem(
                                  context,
                                  'Total Labs',
                                  _stats['totalLabs'] ?? 0,
                                  const [Color(0xFFE91E63), Color(0xFFFF4081)],
                                  Icons.science_rounded,
                                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => LabsManagementScreen(isDarkMode: widget.isDarkMode))).then((_) => _fetchStats()),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildStatGridItem(
                                  context,
                                  'Completed Lab Tests',
                                  _stats['completedLabTests'] ?? 0,
                                  const [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                                  Icons.assignment_turned_in_rounded,
                                  () {}, // Read-only summary count
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String desc,
    Color baseColor,
    List<Color> gradientColors,
    IconData icon,
    VoidCallback onTap,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return AdminPressableCard(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 20,
          vertical: isSmallScreen ? 14 : 22,
        ),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF252538).withOpacity(0.7) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey[100]!,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: isSmallScreen ? 18 : 22),
            ),
            SizedBox(height: isSmallScreen ? 10 : 16),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 13 : 16,
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: isSmallScreen ? 4 : 6),
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: isSmallScreen ? 10 : 11.5,
                color: widget.isDarkMode ? Colors.white60 : Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatGridItem(
    BuildContext context,
    String title,
    int value,
    List<Color> gradientColors,
    IconData icon,
    VoidCallback onTap,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return AdminPressableCard(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                icon,
                size: isSmallScreen ? 56 : 72,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: Colors.white, size: isSmallScreen ? 14 : 16),
                      ),
                      Icon(Icons.arrow_outward_rounded, color: Colors.white, size: isSmallScreen ? 12 : 14),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedCounter(
                        value: value,
                        style: GoogleFonts.outfit(
                          fontSize: isSmallScreen ? 22 : 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: isSmallScreen ? 10 : 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.9),
                        ),
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
}

// ----------------------------------------------------
// TAB 2: MANAGEMENT SCREEN
// ----------------------------------------------------
class AdminManagementTab extends StatelessWidget {
  final bool isDarkMode;
  const AdminManagementTab({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Management',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Direct access to view, update, query, or delete user accounts and bookings directories.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildGridCard(
                        context,
                        '👨‍⚕️ Doctors',
                        'Verify & manage doctor roster',
                        Colors.purple,
                        Icons.people_alt_outlined,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => DoctorManagementScreen(isDarkMode: isDarkMode))),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildGridCard(
                        context,
                        '🧑 Patients',
                        'View & moderate patient accounts',
                        Colors.blue,
                        Icons.person_search_outlined,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => PatientManagementScreen(isDarkMode: isDarkMode))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildGridCard(
                        context,
                        '📅 Appointments',
                        'Read-only consultation logs',
                        Colors.teal,
                        Icons.calendar_today_outlined,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentsManagementScreen(isDarkMode: isDarkMode))),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildGridCard(
                        context,
                        '✅ Doctor Verification',
                        'Pending credentials reviews',
                        Colors.orange,
                        Icons.verified_user_outlined,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => PendingVerificationsScreen(isDarkMode: isDarkMode))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildGridCard(
                        context,
                        '🔬 Labs Verification',
                        'Approve or moderate lab rosters',
                        Colors.purple,
                        Icons.science_outlined,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => LabsManagementScreen(isDarkMode: isDarkMode))),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, String title, String desc, Color color, IconData icon, VoidCallback onTap) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF252538).withOpacity(0.7) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.02),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: isSmallScreen ? 16 : 20,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: isSmallScreen ? 16 : 20),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: isSmallScreen ? 13 : 15,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: GoogleFonts.outfit(
                fontSize: isSmallScreen ? 9 : 10,
                color: isDarkMode ? Colors.white70 : Colors.grey[500],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// TAB 3: ADMIN PROFILE TAB
// ----------------------------------------------------
class AdminProfileTab extends StatelessWidget {
  final dynamic user;
  final bool isDarkMode;
  const AdminProfileTab({super.key, required this.user, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final primaryColor = isDarkMode ? Colors.cyanAccent : theme.primaryColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: CircleAvatar(
              radius: 54,
              backgroundColor: primaryColor.withOpacity(0.12),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'A',
                style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold, color: primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.red.withOpacity(0.15) : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDarkMode ? Colors.red.withOpacity(0.3) : Colors.red[100]!),
              ),
              child: Text(
                'Administrator',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.red[300] : Colors.red[700],
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Card(
            elevation: 0,
            color: isDarkMode ? const Color(0xFF252538).withOpacity(0.7) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey[200]!),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text('Logout', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () => authProvider.signOut(),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// SUBSCREEN: DOCTORS MANAGEMENT
// ----------------------------------------------------
class DoctorManagementScreen extends StatefulWidget {
  final bool isDarkMode;
  const DoctorManagementScreen({super.key, required this.isDarkMode});

  @override
  State<DoctorManagementScreen> createState() => _DoctorManagementScreenState();
}

class _DoctorManagementScreenState extends State<DoctorManagementScreen> {
  final AdminService _adminService = AdminService();
  List<dynamic> _allDoctors = [];
  List<dynamic> _filteredDoctors = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedStatus = 'All'; // All, Pending, Verified, Rejected
  String _selectedOnline = 'All'; // All, Online, Offline

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    try {
      final list = await _adminService.getAllDoctors();
      if (mounted) {
        setState(() {
          _allDoctors = list;
          _isLoading = false;
          _filterData();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterData() {
    setState(() {
      _filteredDoctors = _allDoctors.where((doc) {
        final name = (doc['name'] ?? '').toString().toLowerCase();
        final license = (doc['license'] ?? doc['registrationNumber'] ?? '').toString().toLowerCase();
        final dept = (doc['department'] ?? doc['category'] ?? '').toString().toLowerCase();
        final spec = (doc['specialization'] ?? '').toString().toLowerCase();

        final matchesSearch = name.contains(_searchQuery.toLowerCase()) ||
            license.contains(_searchQuery.toLowerCase()) ||
            dept.contains(_searchQuery.toLowerCase()) ||
            spec.contains(_searchQuery.toLowerCase());

        bool matchesStatus = true;
        if (_selectedStatus != 'All') {
          final statusStr = (doc['status'] ?? '').toString().toLowerCase();
          matchesStatus = statusStr == _selectedStatus.toLowerCase();
        }

        bool matchesOnline = true;
        if (_selectedOnline != 'All') {
          final rawOnline = doc['onlineStatus'];
          final isOnline = rawOnline == true || rawOnline == null || rawOnline.toString().toLowerCase() == 'online';
          matchesOnline = (_selectedOnline == 'Online') ? isOnline : !isOnline;
        }

        return matchesSearch && matchesStatus && matchesOnline;
      }).toList();
    });
  }

  Future<void> _approveDoctor(String uid) async {
    try {
      await _adminService.verifyDoctor(uid, 'verified');
      _fetchDoctors();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor request approved!')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action failed')));
    }
  }

  Future<void> _rejectDoctor(String uid) async {
    String? selectedReason = 'Fake registration number';
    final reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gpp_bad_outlined, color: Colors.red, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Reject Verification',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select a reason for rejecting this doctor\'s verification request:',
                      style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: Text('Fake registration number', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
                            subtitle: Text('Number could not be verified in databases.', style: GoogleFonts.outfit(fontSize: 11)),
                            value: 'Fake registration number',
                            groupValue: selectedReason,
                            onChanged: (val) => setDlgState(() => selectedReason = val),
                            activeColor: Colors.red,
                          ),
                          const Divider(height: 1),
                          RadioListTile<String>(
                            title: Text('Invalid details', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
                            subtitle: Text('Details provided are inconsistent or fake.', style: GoogleFonts.outfit(fontSize: 11)),
                            value: 'Invalid details',
                            groupValue: selectedReason,
                            onChanged: (val) => setDlgState(() => selectedReason = val),
                            activeColor: Colors.red,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey[600])),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, selectedReason),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Confirm Reject', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (reason != null) {
      try {
        await _adminService.rejectDoctor(uid, reason);
        _fetchDoctors();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor request rejected.')));
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reject doctor.')));
      }
    }
  }

  Future<void> _deleteDoctor(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'This action will permanently delete this account and associated records. This action cannot be undone.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _adminService.deleteUser(uid, 'doctor');
        _fetchDoctors();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor account deleted.')));
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deletion failed.')));
      }
    }
  }

  void _viewDoctorDetails(dynamic doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final rawOnline = doc['onlineStatus'];
        final isOnline = rawOnline == true || rawOnline == null || rawOnline.toString().toLowerCase() == 'online';
        final name = doc['name'] ?? 'N/A';
        final email = doc['email'] ?? 'N/A';
        final phone = doc['phoneNumber'] ?? doc['phone'] ?? 'N/A';
        final status = (doc['status'] ?? 'N/A').toString().toUpperCase();
        final qual = doc['qualification'] ?? 'N/A';
        final dept = doc['department'] ?? doc['category'] ?? 'N/A';
        final spec = doc['specialization'] ?? 'N/A';
        final hospital = doc['hospital'] ?? 'N/A';
        final exp = doc['experience'] ?? 'N/A';
        final fee = doc['consultationFee']?.toString() ?? 'N/A';
        final lang = (doc['languages'] as List?)?.join(', ') ?? 'N/A';
        final regNum = doc['license'] ?? doc['registrationNumber'] ?? 'N/A';

        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF1E1E2E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(color: widget.isDarkMode ? Colors.grey[700] : Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.purple.withOpacity(0.1),
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'D', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.purple)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87)),
                              Text('$qual • $dept', style: GoogleFonts.outfit(color: widget.isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDetailTile('Verification Status', status, status == 'VERIFIED' ? Colors.green : (status == 'REJECTED' ? Colors.red : Colors.orange)),
                    _buildDetailTile('Practice Status', isOnline ? 'Online' : 'Offline', isOnline ? Colors.green : Colors.grey),
                    _buildDetailTile('Email', email, Colors.black87),
                    _buildDetailTile('Phone Number', phone, Colors.black87),
                    _buildDetailTile('Registration License', regNum, Colors.black87),
                    _buildDetailTile('Specialization', spec, Colors.black87),
                    _buildDetailTile('Hospital / Clinic', hospital, Colors.black87),
                    _buildDetailTile('Experience', '$exp years', Colors.black87),
                    _buildDetailTile('Consultation Fee', '₹$fee', Colors.black87),
                    _buildDetailTile('Languages Spoken', lang, Colors.black87),
                    if (doc['rejectionReason'] != null)
                      _buildDetailTile('Rejection Reason', doc['rejectionReason'].toString(), Colors.red[800]!),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailTile(String label, String value, Color valueColor) {
    final isDark = widget.isDarkMode;
    final labelColor = isDark ? Colors.white54 : Colors.grey[500];
    final displayValueColor = (valueColor == Colors.black87 && isDark) ? Colors.white : valueColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 12, color: labelColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(fontSize: 15, color: displayValueColor, fontWeight: FontWeight.w500)),
          Divider(height: 12, color: isDark ? Colors.white.withOpacity(0.08) : null),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("Doctors loaded: ${_allDoctors.length}");
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode;
    final primaryColor = isDark ? Colors.cyanAccent : theme.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Doctors Management',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF0F0F1A),
                    const Color(0xFF1E1E2E),
                  ]
                : [
                    Colors.white,
                    theme.primaryColor.withOpacity(0.04),
                    theme.primaryColor.withOpacity(0.08),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: TextFormField(
                      style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search by Name, Reg Number, Specialty...',
                        hintStyle: GoogleFonts.outfit(color: isDark ? Colors.white54 : Colors.grey),
                        prefixIcon: Icon(Icons.search, color: primaryColor),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryColor, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) {
                        _searchQuery = val;
                        _filterData();
                      },
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Text(
                          'Verification: ',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        ...['All', 'Pending', 'Verified', 'Rejected'].map((status) {
                          final isSel = _selectedStatus == status;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(status, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
                              selected: isSel,
                              selectedColor: primaryColor.withOpacity(0.15),
                              backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey[100],
                              labelStyle: TextStyle(
                                color: isSel
                                    ? primaryColor
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  _selectedStatus = status;
                                  _filterData();
                                }
                              },
                            ),
                          );
                        }),
                        const SizedBox(width: 12),
                        Text(
                          'Status: ',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        ...['All', 'Online', 'Offline'].map((online) {
                          final isSel = _selectedOnline == online;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(online, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
                              selected: isSel,
                              selectedColor: primaryColor.withOpacity(0.15),
                              backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey[100],
                              labelStyle: TextStyle(
                                color: isSel
                                    ? primaryColor
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  _selectedOnline = online;
                                  _filterData();
                                }
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _filteredDoctors.isEmpty
                        ? Center(
                            child: Text(
                              'No doctors match selected filters.',
                              style: GoogleFonts.outfit(color: isDark ? Colors.white54 : Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredDoctors.length,
                            itemBuilder: (context, index) {
                              final doc = _filteredDoctors[index];
                              final rawOnline = doc['onlineStatus'];
                              final isOnline = rawOnline == true || rawOnline == null || rawOnline.toString().toLowerCase() == 'online';
                              final isVerified = doc['verified'] == true || doc['status']?.toString().toLowerCase() == 'verified';
                              final statusStr = doc['status']?.toString().toLowerCase() ?? 'pending';

                              final statusColor = statusStr == 'verified'
                                  ? Colors.green
                                  : (statusStr == 'rejected' ? Colors.red : Colors.orange);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF252538).withOpacity(0.7) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          width: 5,
                                          color: statusColor,
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(14),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 26,
                                                      backgroundColor: Colors.purple.withOpacity(0.08),
                                                      child: Text(
                                                        doc['name'].isNotEmpty ? doc['name'][0].toUpperCase() : 'D',
                                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.purple),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 14),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  doc['name'],
                                                                  style: GoogleFonts.outfit(
                                                                    fontSize: 15,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: isDark ? Colors.white : Colors.black87,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                              if (isVerified) ...[
                                                                const SizedBox(width: 4),
                                                                const Icon(Icons.verified, color: Colors.blue, size: 16),
                                                              ],
                                                            ],
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            '${doc['qualification'] ?? 'MBBS'} • ${doc['department'] ?? doc['category'] ?? 'General'}',
                                                            style: GoogleFonts.outfit(
                                                              fontSize: 11,
                                                              color: isDark ? Colors.white60 : Colors.grey[600],
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          Text(
                                                            doc['hospital'] ?? 'N/A Hospital',
                                                            style: GoogleFonts.outfit(
                                                              fontSize: 11,
                                                              color: isDark ? Colors.white54 : Colors.grey[500],
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Row(
                                                            children: [
                                                              Container(
                                                                width: 6,
                                                                height: 6,
                                                                decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? Colors.green : Colors.grey),
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                isOnline ? 'Online' : 'Offline',
                                                                style: GoogleFonts.outfit(
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: isOnline ? Colors.green[700] : Colors.grey[600],
                                                                ),
                                                              ),
                                                              const SizedBox(width: 12),
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: statusStr == 'verified' ? Colors.green[50] : (statusStr == 'rejected' ? Colors.red[50] : Colors.orange[50]),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Text(
                                                                  statusStr.toUpperCase(),
                                                                  style: GoogleFonts.outfit(
                                                                    fontSize: 9,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: statusStr == 'verified' ? Colors.green[800] : (statusStr == 'rejected' ? Colors.red[800] : Colors.orange[800]),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.08) : null),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  alignment: WrapAlignment.spaceBetween,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  spacing: 8,
                                                  runSpacing: 6,
                                                  children: [
                                                    TextButton.icon(
                                                      onPressed: () => _viewDoctorDetails(doc),
                                                      icon: Icon(Icons.info_outline, size: 16, color: primaryColor),
                                                      label: Text('View Details', style: TextStyle(fontSize: 12, color: primaryColor)),
                                                      style: TextButton.styleFrom(
                                                        padding: EdgeInsets.zero,
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                    ),
                                                    Wrap(
                                                      spacing: 4,
                                                      crossAxisAlignment: WrapCrossAlignment.center,
                                                      children: [
                                                        if (statusStr != 'verified')
                                                          TextButton(
                                                            onPressed: () => _approveDoctor(doc['uid']),
                                                            style: TextButton.styleFrom(
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                            ),
                                                            child: const Text('Approve', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                                          ),
                                                        if (statusStr != 'rejected')
                                                          TextButton(
                                                            onPressed: () => _rejectDoctor(doc['uid']),
                                                            style: TextButton.styleFrom(
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                            ),
                                                            child: const Text('Reject', style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                                                          ),
                                                        IconButton(
                                                          onPressed: () => _deleteDoctor(doc['uid']),
                                                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                                          constraints: const BoxConstraints(),
                                                          padding: const EdgeInsets.all(8),
                                                        ),
                                                      ],
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

// ----------------------------------------------------
// SUBSCREEN: PATIENTS MANAGEMENT
// ----------------------------------------------------
class PatientManagementScreen extends StatefulWidget {
  final bool isDarkMode;
  const PatientManagementScreen({super.key, required this.isDarkMode});

  @override
  State<PatientManagementScreen> createState() => _PatientManagementScreenState();
}

class _PatientManagementScreenState extends State<PatientManagementScreen> {
  final AdminService _adminService = AdminService();
  List<dynamic> _allPatients = [];
  List<dynamic> _filteredPatients = [];
  Map<String, int> _patientApptCounts = {};
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedGender = 'All'; // All, Male, Female
  String _selectedAgeRange = 'All'; // All, Under 18, 18-35, 36-50, Over 50

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    try {
      final list = await _adminService.getAllPatients();
      final appts = await _adminService.getAllAppointments();
      
      final Map<String, int> counts = {};
      for (final appt in appts) {
        final pid = appt['patient_id'];
        if (pid != null) {
          counts[pid] = (counts[pid] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _allPatients = list;
          _patientApptCounts = counts;
          _isLoading = false;
          _filterData();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterData() {
    setState(() {
      _filteredPatients = _allPatients.where((pat) {
        final name = (pat['name'] ?? '').toString().toLowerCase();
        final phone = (pat['phoneNumber'] ?? pat['phone'] ?? '').toString().toLowerCase();

        final matchesSearch = name.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery.toLowerCase());

        bool matchesGender = true;
        if (_selectedGender != 'All') {
          final genderStr = (pat['gender'] ?? '').toString().toLowerCase();
          matchesGender = genderStr == _selectedGender.toLowerCase();
        }

        bool matchesAge = true;
        if (_selectedAgeRange != 'All') {
          final ageVal = int.tryParse(pat['age']?.toString() ?? '');
          if (ageVal == null) {
            matchesAge = false;
          } else {
            if (_selectedAgeRange == 'Under 18') {
              matchesAge = ageVal < 18;
            } else if (_selectedAgeRange == '18-35') {
              matchesAge = ageVal >= 18 && ageVal <= 35;
            } else if (_selectedAgeRange == '36-50') {
              matchesAge = ageVal >= 36 && ageVal <= 50;
            } else if (_selectedAgeRange == 'Over 50') {
              matchesAge = ageVal > 50;
            }
          }
        }

        return matchesSearch && matchesGender && matchesAge;
      }).toList();
    });
  }

  Future<void> _deletePatient(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'This action will permanently delete this account and associated records. This action cannot be undone.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _adminService.deleteUser(uid, 'patient');
        _fetchPatients();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient account deleted.')));
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deletion failed.')));
      }
    }
  }

  void _viewPatientProfile(dynamic pat) {
    final name = pat['name'] ?? 'N/A';
    final email = pat['email'] ?? 'N/A';
    final phone = pat['phoneNumber'] ?? pat['phone'] ?? 'N/A';
    final age = pat['age']?.toString() ?? 'N/A';
    final gender = pat['gender'] ?? 'N/A';
    final count = _patientApptCounts[pat['uid']] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'P', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87)),
                        Text('Patient User', style: GoogleFonts.outfit(color: widget.isDarkMode ? Colors.white54 : Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailItem('Email Address', email),
              _buildDetailItem('Phone Number', phone),
              Row(
                children: [
                  Expanded(child: _buildDetailItem('Age', age)),
                  Expanded(child: _buildDetailItem('Gender', gender)),
                ],
              ),
              _buildDetailItem('Total Booked Appointments', '$count times'),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    final isDark = widget.isDarkMode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[500], fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(value, style: GoogleFonts.outfit(fontSize: 14, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("Patients loaded: ${_allPatients.length}");
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode;
    final primaryColor = isDark ? Colors.cyanAccent : theme.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Patients Management',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF0F0F1A),
                    const Color(0xFF1E1E2E),
                  ]
                : [
                    Colors.white,
                    theme.primaryColor.withOpacity(0.04),
                    theme.primaryColor.withOpacity(0.08),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: TextFormField(
                      style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search by Patient Name or Phone...',
                        hintStyle: GoogleFonts.outfit(color: isDark ? Colors.white54 : Colors.grey),
                        prefixIcon: Icon(Icons.search, color: primaryColor),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryColor, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) {
                        _searchQuery = val;
                        _filterData();
                      },
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Text(
                          'Gender: ',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        ...['All', 'Male', 'Female'].map((gen) {
                          final isSel = _selectedGender == gen;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(gen, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
                              selected: isSel,
                              selectedColor: primaryColor.withOpacity(0.15),
                              backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey[100],
                              labelStyle: TextStyle(
                                color: isSel
                                    ? primaryColor
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  _selectedGender = gen;
                                  _filterData();
                                }
                              },
                            ),
                          );
                        }),
                        const SizedBox(width: 12),
                        Text(
                          'Age: ',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        ...['All', 'Under 18', '18-35', '36-50', 'Over 50'].map((age) {
                          final isSel = _selectedAgeRange == age;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(age, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
                              selected: isSel,
                              selectedColor: primaryColor.withOpacity(0.15),
                              backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey[100],
                              labelStyle: TextStyle(
                                color: isSel
                                    ? primaryColor
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  _selectedAgeRange = age;
                                  _filterData();
                                }
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _filteredPatients.isEmpty
                        ? Center(
                            child: Text(
                              'No patients match selected filters.',
                              style: GoogleFonts.outfit(color: isDark ? Colors.white54 : Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredPatients.length,
                            itemBuilder: (context, index) {
                              final pat = _filteredPatients[index];
                              final String photoUrl = pat['profileImageUrl'] ?? pat['photoUrl'] ?? '';
                              final String name = pat['name'] ?? 'Patient';
                              final String age = pat['age']?.toString() ?? 'N/A';
                              final String gender = pat['gender'] ?? 'N/A';
                              final count = _patientApptCounts[pat['uid']] ?? 0;

                              return GestureDetector(
                                onTap: () => _viewPatientProfile(pat),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.06),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      color: isDark ? const Color(0xFF252538) : Colors.white,
                                      child: Row(
                                        children: [
                                          // Left accent stripe
                                          Container(
                                            width: 5,
                                            height: 80,
                                            color: primaryColor,
                                          ),
                                          const SizedBox(width: 12),
                                          // Avatar
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: Colors.blue.withOpacity(0.08),
                                            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                            child: photoUrl.isEmpty
                                                ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'P', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue))
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          // Info text
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : Colors.black87,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    'Age: $age  •  Gender: $gender',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      color: isDark ? Colors.white60 : Colors.grey[600],
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Appointments: $count',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      color: isDark ? Colors.white54 : Colors.grey[500],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          // Action buttons — isolated hit targets
                                          SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: IconButton(
                                              onPressed: () => _viewPatientProfile(pat),
                                              icon: Icon(Icons.info_outline, color: primaryColor, size: 20),
                                              padding: EdgeInsets.zero,
                                              splashRadius: 20,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: IconButton(
                                              onPressed: () => _deletePatient(pat['uid']),
                                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                              padding: EdgeInsets.zero,
                                              splashRadius: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                      ),
                                    ),
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
}
            // ----------------------------------------------------
// SUBSCREEN: APPOINTMENTS MANAGEMENT (READ-ONLY)
// ----------------------------------------------------
class AppointmentsManagementScreen extends StatefulWidget {
  final bool isDarkMode;
  const AppointmentsManagementScreen({super.key, required this.isDarkMode});

  @override
  State<AppointmentsManagementScreen> createState() => _AppointmentsManagementScreenState();
}

class _AppointmentsManagementScreenState extends State<AppointmentsManagementScreen> {
  final AdminService _adminService = AdminService();
  List<dynamic> _allAppointments = [];
  List<dynamic> _filteredAppointments = [];
  bool _isLoading = true;
  String _selectedFilter = 'Today'; // Today, Upcoming, Completed, Cancelled

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    try {
      final list = await _adminService.getAllAppointments();
      if (mounted) {
        setState(() {
          _allAppointments = list;
          _isLoading = false;
          _filterData();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterData() {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    setState(() {
      _filteredAppointments = _allAppointments.where((appt) {
        final dateStr = appt['date'] ?? '';
        final status = (appt['status'] ?? '').toString().toLowerCase();

        if (_selectedFilter == 'Today') {
          return dateStr == todayStr;
        } else if (_selectedFilter == 'Upcoming') {
          try {
            final apptDate = DateFormat('yyyy-MM-dd').parse(dateStr);
            final todayDate = DateFormat('yyyy-MM-dd').parse(todayStr);
            return apptDate.isAfter(todayDate) && (status == 'approved' || status == 'pending');
          } catch (_) {
            return false;
          }
        } else if (_selectedFilter == 'Completed') {
          return status == 'completed';
        } else if (_selectedFilter == 'Cancelled') {
          return status == 'rejected' || status == 'cancelled';
        }
        return true;
      }).toList();

      _filteredAppointments.sort((a, b) {
        final dateA = a['date'] ?? '';
        final dateB = b['date'] ?? '';
        final cmp = dateA.compareTo(dateB);
        if (cmp != 0) return cmp;

        final slotA = a['time_slot'] ?? '';
        final slotB = b['time_slot'] ?? '';
        return slotA.compareTo(slotB);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode;
    final primaryColor = isDark ? Colors.cyanAccent : theme.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Appointments Tracker',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF0F0F1A),
                    const Color(0xFF1E1E2E),
                  ]
                : [
                    Colors.white,
                    theme.primaryColor.withOpacity(0.04),
                    theme.primaryColor.withOpacity(0.08),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['Today', 'Upcoming', 'Completed', 'Cancelled'].map((filter) {
                        final isSel = _selectedFilter == filter;
                        return ChoiceChip(
                          label: Text(filter, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                          selected: isSel,
                          selectedColor: primaryColor.withOpacity(0.15),
                          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey[100],
                          labelStyle: TextStyle(
                            color: isSel
                                ? primaryColor
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedFilter = filter;
                                _filterData();
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  Expanded(
                    child: _filteredAppointments.isEmpty
                        ? Center(
                            child: Text(
                              'No appointments in this category.',
                              style: GoogleFonts.outfit(color: isDark ? Colors.white54 : Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredAppointments.length,
                            itemBuilder: (context, index) {
                              final appt = _filteredAppointments[index];
                              final patientName = appt['patient_name'] ?? 'Patient';
                              final doctorName = appt['doctor_name'] ?? 'Doctor';
                              final date = appt['date'] ?? '';
                              final time = appt['time_slot'] ?? '';
                              final symptoms = appt['symptoms'] ?? 'No symptoms described';
                              final statusStr = appt['status']?.toString().toLowerCase() ?? 'pending';

                              final statusColor = statusStr == 'completed'
                                  ? Colors.green
                                  : (statusStr == 'approved'
                                      ? Colors.blue
                                      : (statusStr == 'checked_in'
                                          ? Colors.purple
                                          : (statusStr == 'pending' ? Colors.orange : Colors.red)));

                              final Color badgeBg;
                              final Color badgeText;
                              if (isDark) {
                                if (statusStr == 'completed') {
                                  badgeBg = Colors.green.withOpacity(0.15);
                                  badgeText = Colors.green[300]!;
                                } else if (statusStr == 'approved') {
                                  badgeBg = Colors.blue.withOpacity(0.15);
                                  badgeText = Colors.blue[300]!;
                                } else if (statusStr == 'checked_in') {
                                  badgeBg = Colors.purple.withOpacity(0.15);
                                  badgeText = Colors.purple[300]!;
                                } else if (statusStr == 'pending') {
                                  badgeBg = Colors.orange.withOpacity(0.15);
                                  badgeText = Colors.orange[300]!;
                                } else {
                                  badgeBg = Colors.red.withOpacity(0.15);
                                  badgeText = Colors.red[300]!;
                                }
                              } else {
                                if (statusStr == 'completed') {
                                  badgeBg = Colors.green[50]!;
                                  badgeText = Colors.green[800]!;
                                } else if (statusStr == 'approved') {
                                  badgeBg = Colors.blue[50]!;
                                  badgeText = Colors.blue[800]!;
                                } else if (statusStr == 'checked_in') {
                                  badgeBg = Colors.purple[50]!;
                                  badgeText = Colors.purple[800]!;
                                } else if (statusStr == 'pending') {
                                  badgeBg = Colors.orange[50]!;
                                  badgeText = Colors.orange[800]!;
                                } else {
                                  badgeBg = Colors.red[50]!;
                                  badgeText = Colors.red[800]!;
                                }
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF252538).withOpacity(0.7) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          width: 5,
                                          color: statusColor,
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Patient: $patientName',
                                                        style: GoogleFonts.outfit(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15,
                                                          color: isDark ? Colors.white : Colors.black87,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: badgeBg,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        statusStr.toUpperCase(),
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: badgeText,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Doctor: $doctorName',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 13,
                                                    color: isDark ? Colors.white70 : Colors.grey[700],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(Icons.calendar_today, size: 14, color: isDark ? Colors.white60 : Colors.grey),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '$date  •  $time',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 12,
                                                        color: isDark ? Colors.white60 : Colors.grey[600],
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[50],
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    'Symptoms: $symptoms',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 12,
                                                      color: isDark ? Colors.white70 : Colors.grey[600],
                                                      fontStyle: FontStyle.italic,
                                                    ),
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
                  ),
                ],
              ),
      ),
    );
  }
}

// ----------------------------------------------------
// SUBSCREEN: PENDING DOCTOR VERIFICATION SCREEN
// ----------------------------------------------------
class PendingVerificationsScreen extends StatefulWidget {
  final bool isDarkMode;
  const PendingVerificationsScreen({super.key, required this.isDarkMode});

  @override
  State<PendingVerificationsScreen> createState() => _PendingVerificationsScreenState();
}

class _PendingVerificationsScreenState extends State<PendingVerificationsScreen> {
  final AdminService _adminService = AdminService();
  List<dynamic> _allDoctors = [];
  List<dynamic> _filteredDoctors = [];
  bool _isLoading = true;
  String _selectedTab = 'Pending'; // Pending, Verified, Rejected

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    try {
      final list = await _adminService.getAllDoctors();
      if (mounted) {
        setState(() {
          _allDoctors = list;
          _isLoading = false;
          _filterData();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterData() {
    setState(() {
      _filteredDoctors = _allDoctors.where((doc) {
        final status = (doc['status'] ?? '').toString().toLowerCase();
        return status == _selectedTab.toLowerCase();
      }).toList();
    });
  }

  Future<void> _approveDoctor(String uid) async {
    try {
      await _adminService.verifyDoctor(uid, 'verified');
      _fetchDoctors();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor request approved!')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action failed')));
    }
  }

  Future<void> _rejectDoctor(String uid) async {
    String? selectedReason = 'Fake registration number';
    final reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gpp_bad_outlined, color: Colors.red, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Reject Verification',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select a reason for rejecting this doctor\'s request:',
                      style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: Text('Fake registration number', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
                            value: 'Fake registration number',
                            groupValue: selectedReason,
                            onChanged: (val) => setDlgState(() => selectedReason = val),
                            activeColor: Colors.red,
                          ),
                          const Divider(height: 1),
                          RadioListTile<String>(
                            title: Text('Invalid details', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
                            value: 'Invalid details',
                            groupValue: selectedReason,
                            onChanged: (val) => setDlgState(() => selectedReason = val),
                            activeColor: Colors.red,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey[600])),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, selectedReason),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          child: Text('Confirm Reject', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (reason != null) {
      try {
        await _adminService.rejectDoctor(uid, reason);
        _fetchDoctors();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor request rejected.')));
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reject doctor.')));
      }
    }
  }

  Future<void> _deleteDoctor(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'This action will permanently delete this account and associated records. This action cannot be undone.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _adminService.deleteUser(uid, 'doctor');
        _fetchDoctors();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor account deleted.')));
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deletion failed.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode;
    final primaryColor = isDark ? Colors.cyanAccent : theme.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Doctor Verification',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF0F0F1A),
                    const Color(0xFF1E1E2E),
                  ]
                : [
                    Colors.white,
                    theme.primaryColor.withOpacity(0.04),
                    theme.primaryColor.withOpacity(0.08),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: ['Pending', 'Verified', 'Rejected'].map((tab) {
                        final isSel = _selectedTab == tab;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text('$tab Doctors', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                            selected: isSel,
                            selectedColor: primaryColor.withOpacity(0.15),
                            backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey[100],
                            labelStyle: TextStyle(
                              color: isSel
                                  ? primaryColor
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedTab = tab;
                                  _filterData();
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Expanded(
                    child: _filteredDoctors.isEmpty
                        ? Center(
                            child: Text(
                              'No $_selectedTab doctors found.',
                              style: GoogleFonts.outfit(color: isDark ? Colors.white54 : Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredDoctors.length,
                            itemBuilder: (context, index) {
                              final doc = _filteredDoctors[index];
                              final license = doc['license'] ?? doc['registrationNumber'] ?? 'N/A';
                              final dept = doc['department'] ?? doc['category'] ?? 'N/A';
                              final spec = doc['specialization'] ?? 'N/A';

                              final statusColor = _selectedTab == 'Verified'
                                  ? Colors.green
                                  : (_selectedTab == 'Rejected' ? Colors.red : Colors.orange);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF252538).withOpacity(0.7) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          width: 5,
                                          color: statusColor,
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  doc['name'],
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Email: ${doc['email']}',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    color: isDark ? Colors.white60 : Colors.grey[600],
                                                  ),
                                                ),
                                                Text(
                                                  'License Number: $license',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    color: isDark ? Colors.white60 : Colors.grey[600],
                                                  ),
                                                ),
                                                Text(
                                                  'Dept: $dept  •  Spec: $spec',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    color: isDark ? Colors.white60 : Colors.grey[600],
                                                  ),
                                                ),
                                                if (doc['rejectionReason'] != null) ...[
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Rejection Reason: ${doc['rejectionReason']}',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 12,
                                                      color: isDark ? Colors.red[300] : Colors.red[800],
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 14),
                                                Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.08) : null),
                                                const SizedBox(height: 10),
                                                Wrap(
                                                  alignment: WrapAlignment.end,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  spacing: 8,
                                                  runSpacing: 4,
                                                  children: [
                                                    if (_selectedTab != 'Verified')
                                                      ElevatedButton(
                                                        onPressed: () => _approveDoctor(doc['uid']),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.green,
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                          minimumSize: Size.zero,
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        ),
                                                        child: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                      ),
                                                    if (_selectedTab != 'Rejected') ...[
                                                      ElevatedButton(
                                                        onPressed: () => _rejectDoctor(doc['uid']),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.orange,
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                          minimumSize: Size.zero,
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        ),
                                                        child: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                      ),
                                                    ],
                                                    IconButton(
                                                      onPressed: () => _deleteDoctor(doc['uid']),
                                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                                      constraints: const BoxConstraints(),
                                                      padding: const EdgeInsets.all(8),
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

// ----------------------------------------------------
// UI HELPERS & ANIMATIONS
// ----------------------------------------------------
class AdminPressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const AdminPressableCard({super.key, required this.child, required this.onTap});

  @override
  State<AdminPressableCard> createState() => _AdminPressableCardState();
}

class _AdminPressableCardState extends State<AdminPressableCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class AnimatedCounter extends StatefulWidget {
  final int value;
  final TextStyle style;
  const AnimatedCounter({super.key, required this.value, required this.style});

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: oldWidget.value.toDouble(),
        end: widget.value.toDouble(),
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          _animation.value.round().toString(),
          style: widget.style,
        );
      },
    );
  }
}

class LabsManagementScreen extends StatefulWidget {
  final bool isDarkMode;
  const LabsManagementScreen({super.key, required this.isDarkMode});

  @override
  State<LabsManagementScreen> createState() => _LabsManagementScreenState();
}

class _LabsManagementScreenState extends State<LabsManagementScreen> {
  final AdminService _adminService = AdminService();
  List<dynamic> _filteredLabs = [];
  bool _isLoading = true;
  String _selectedTab = 'Pending'; // Pending, Approved, Rejected

  @override
  void initState() {
    super.initState();
    _fetchLabs();
  }

  Future<void> _fetchLabs() async {
    setState(() => _isLoading = true);
    try {
      final list = await _adminService.getLabsByStatus(_selectedTab);
      if (mounted) {
        setState(() {
          _filteredLabs = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveLab(String uid) async {
    try {
      await _adminService.verifyLab(uid, 'approved');
      _fetchLabs();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lab request approved!')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action failed')));
    }
  }

  Future<void> _rejectLab(String uid) async {
    String? selectedReason = 'Fake registration details';
    final reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gpp_bad_outlined, color: Colors.red, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Reject Verification',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select rejection reason for this Lab registration request:',
                      style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: [
                        'Fake registration details',
                        'Incomplete credentials',
                        'Invalid Google Maps location',
                        'Unresponsive contact number',
                      ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setDlgState(() => selectedReason = v),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, null),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(context, selectedReason),
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (reason == null) return;

    try {
      await _adminService.rejectLab(uid, reason);
      _fetchLabs();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lab request rejected')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = widget.isDarkMode ? Colors.white60 : Colors.grey[600];
    final cardBg = widget.isDarkMode ? const Color(0xFF1E1E2E) : Colors.white;

    return Scaffold(
      backgroundColor: widget.isDarkMode ? const Color(0xFF0F0F1A) : Colors.grey[50],
      appBar: AppBar(
        title: Text('Labs Verification', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Pending', 'Approved', 'Rejected'].map((tabName) {
                final isSelected = _selectedTab == tabName;
                return ChoiceChip(
                  label: Text(tabName, style: GoogleFonts.outfit(color: isSelected ? Colors.white : textColor)),
                  selected: isSelected,
                  selectedColor: Colors.purple,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedTab = tabName;
                      });
                      _fetchLabs();
                    }
                  },
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLabs.isEmpty
                    ? Center(child: Text('No Labs in $_selectedTab list.', style: GoogleFonts.outfit(color: subtitleColor)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredLabs.length,
                        itemBuilder: (context, idx) {
                          final lab = _filteredLabs[idx];
                          final uid = lab['uid'] ?? '';
                          final name = lab['name'] ?? 'Owner';
                          final email = lab['email'] ?? '';

                          return FutureBuilder<Map<String, dynamic>?>(
                            future: FirebaseFirestore.instance.collection('lab_profiles').doc(uid).get().then((d) => d.data()),
                            builder: (context, snapshot) {
                              final profile = snapshot.data ?? {};
                              final labName = profile['labName'] ?? 'Pending Profile Complete';
                              final address = profile['address'] ?? 'N/A';
                              final location = profile['location'] ?? '';
                              final website = profile['website'] ?? '';
                              final phone = profile['phone'] ?? lab['phone'] ?? 'N/A';
                              final openingTime = profile['openingTime'] ?? 'N/A';
                              final closingTime = profile['closingTime'] ?? 'N/A';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: widget.isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      labName,
                                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Owner: $name', style: GoogleFonts.outfit(fontSize: 13, color: subtitleColor)),
                                    Text('Email: $email', style: GoogleFonts.outfit(fontSize: 13, color: subtitleColor)),
                                    Text('Phone: $phone', style: GoogleFonts.outfit(fontSize: 13, color: subtitleColor)),
                                    Text('Address: $address', style: GoogleFonts.outfit(fontSize: 13, color: subtitleColor)),
                                    Text('Hours: $openingTime - $closingTime', style: GoogleFonts.outfit(fontSize: 13, color: subtitleColor)),
                                    if (website.isNotEmpty)
                                      Text('Website: $website', style: GoogleFonts.outfit(fontSize: 13, color: Colors.blue)),
                                    const SizedBox(height: 10),
                                    if (location.isNotEmpty)
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final uri = Uri.parse(location);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          }
                                        },
                                        icon: const Icon(Icons.map, size: 14),
                                        label: const Text('Open Google Maps'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          textStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                                          minimumSize: const Size(0, 36),
                                        ),
                                      ),
                                    if (_selectedTab == 'Pending') ...[
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () => _rejectLab(uid),
                                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                                            child: const Text('Reject'),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () => _approveLab(uid),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(0, 40),
                                            ),
                                            child: const Text('Approve'),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (_selectedTab == 'Rejected' && lab['rejectionReason'] != null) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        'Rejection Reason: ${lab['rejectionReason']}',
                                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.red[800], fontWeight: FontWeight.bold),
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
    );
  }
}

