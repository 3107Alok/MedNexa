import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/services/booking_service.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/screens/doctor/patient_details_screen.dart';
import 'package:frontend/screens/doctor/history_screen.dart';
import 'package:frontend/theme/theme_notifier.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final user = authProvider.user;
    final bool _isDarkMode = themeNotifier.isDarkMode;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // List of screens to display in bottom tabs
    final List<Widget> tabs = [
      DoctorHomeTab(doctorId: user.uid, isDarkMode: _isDarkMode),
      DoctorAppointmentsTab(doctorId: user.uid, isDarkMode: _isDarkMode),
      DoctorProfileTab(user: user, isDarkMode: _isDarkMode),
    ];

    final scaffoldBg = _isDarkMode ? const Color(0xFF0F0F1A) : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E2E) : Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _isDarkMode ? Colors.white : Colors.black87),
        title: Text(
          'MediNexa',
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
            onPressed: () => themeNotifier.toggleDarkMode(),
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
      bottomNavigationBar: _buildGlassmorphicBottomNav(context),
    );
  }

  Widget _buildGlassmorphicBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeNotifier>(context, listen: false).isDarkMode;
    final navBg = isDark ? const Color(0xFF1E1E2E).withOpacity(0.85) : Colors.white.withOpacity(0.85);
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.4);
    final shadowColor = isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.06);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: navBg,
            border: Border(top: BorderSide(color: borderColor, width: 1.5)),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 20,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', 0, theme),
              _buildNavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Appointments', 1, theme),
              _buildNavItem(Icons.person_outline, Icons.person, 'Profile', 2, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData unselectedIcon, IconData selectedIcon, String label, int index, ThemeData theme) {
    final isSelected = _currentIndex == index;
    final isDark = Provider.of<ThemeNotifier>(context, listen: false).isDarkMode;
    final primaryColor = isDark ? const Color(0xFFBB86FC) : theme.primaryColor;
    
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected ? primaryColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


// ----------------------------------------------------
// TAB 1: HOME TAB
// ----------------------------------------------------
class DoctorHomeTab extends StatefulWidget {
  final String doctorId;
  final bool isDarkMode;
  const DoctorHomeTab({super.key, required this.doctorId, required this.isDarkMode});

  @override
  State<DoctorHomeTab> createState() => _DoctorHomeTabState();
}

class _DoctorHomeTabState extends State<DoctorHomeTab> {
  final BookingService _bookingService = BookingService();
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    _bookingService.getDoctorAppointmentsStream(widget.doctorId).listen((data) {
      if (mounted) {
        setState(() {
          _appointments = data;
          _isLoading = false;
        });
      }
    });
  }

  Map<String, dynamic>? _getUpcomingAppointment() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final upcoming = _appointments.where((appt) {
      final status = appt['status']?.toString().toLowerCase() ?? '';
      final apptDate = appt['date'] ?? '';
      return apptDate == todayStr && (status == 'approved' || status == 'checked_in');
    }).toList();

    if (upcoming.isEmpty) return null;

    // Sort by time slot (Format: "hh:mm AM/PM")
    upcoming.sort((a, b) {
      try {
        final timeA = DateFormat('hh:mm a').parse(a['time_slot']);
        final timeB = DateFormat('hh:mm a').parse(b['time_slot']);
        return timeA.compareTo(timeB);
      } catch (_) {
        return 0;
      }
    });

    // Check if the slot has already passed
    final now = DateTime.now();
    for (final appt in upcoming) {
      try {
        final parsedTime = DateFormat('hh:mm a').parse(appt['time_slot']);
        final apptTime = DateTime(now.year, now.month, now.day, parsedTime.hour, parsedTime.minute);
        
        // If appointment time is within the next 45 minutes or is in the future, it is upcoming
        if (apptTime.add(const Duration(minutes: 30)).isAfter(now)) {
          return appt;
        }
      } catch (_) {}
    }

    return upcoming.first; // Fallback
  }

  String _getRemainingTime(String dateStr, String slotStr) {
    try {
      final now = DateTime.now();
      final parsedTime = DateFormat('hh:mm a').parse(slotStr);
      final apptTime = DateTime(now.year, now.month, now.day, parsedTime.hour, parsedTime.minute);
      final diff = apptTime.difference(now);

      if (diff.isNegative) {
        final minsAgo = diff.inMinutes.abs();
        if (minsAgo > 60) {
          return "Started ${minsAgo ~/ 60} hr ${minsAgo % 60} mins ago";
        }
        return "Started $minsAgo mins ago";
      } else {
        final minsLeft = diff.inMinutes;
        if (minsLeft > 60) {
          return "Starts in ${minsLeft ~/ 60} hr ${minsLeft % 60} mins";
        }
        return "Starts in $minsLeft mins";
      }
    } catch (_) {
      return "Scheduled";
    }
  }

  Map<String, int> _getStats() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    int todayAppts = 0;
    int pending = 0;
    int completedToday = 0;
    final Set<String> patientsSeen = {};

    for (final appt in _appointments) {
      final status = appt['status']?.toString().toLowerCase() ?? '';
      final date = appt['date'] ?? '';
      final patientId = appt['patient_id'] ?? '';

      if (status == 'pending') pending++;
      
      if (date == todayStr) {
        if (status == 'approved' || status == 'checked_in') todayAppts++;
        if (status == 'completed') completedToday++;
      }

      if (status == 'completed' && patientId.isNotEmpty) {
        patientsSeen.add(patientId);
      }
    }

    return {
      'todayAppts': todayAppts,
      'pending': pending,
      'completedToday': completedToday,
      'totalPatients': patientsSeen.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[600];
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final upcoming = _getUpcomingAppointment();
    final stats = _getStats();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Upcoming Appointment Section
          Text('Upcoming Appointment', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 12),
          if (upcoming == null) ...[
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(color: isDark ? Colors.black38 : Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_available, size: 48, color: isDark ? Colors.grey[700] : Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No upcoming appointments today',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(color: isDark ? Colors.black38 : Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            upcoming['patient_name'] ?? 'Patient Profile',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getRemainingTime(upcoming['date'] ?? '', upcoming['time_slot'] ?? ''),
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: theme.primaryColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Patient ID: ${upcoming['patient_id'] ?? 'N/A'}', style: GoogleFonts.outfit(color: subtitleColor, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: subtitleColor),
                        const SizedBox(width: 4),
                        Text(
                          '${upcoming['time_slot']} (Today)',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: isDark ? Colors.white24 : null),
                    const SizedBox(height: 8),
                    Text(
                      'Problem Summary:',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12, color: subtitleColor),
                    ),
                    Text(
                      upcoming['symptoms'] ?? 'No symptoms provided',
                      style: GoogleFonts.outfit(fontSize: 14, color: textColor),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PatientDetailsScreen(patientId: upcoming['patient_id']),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_search_outlined, size: 18),
                      label: const Text('View Patient'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 28),
          
          // 2. Stats Section
          Text('Dashboard Summary', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildStatSummaryCard("Today's Appointments", stats['todayAppts'].toString(), Colors.blue, Icons.calendar_today_outlined, isDark),
              _buildStatSummaryCard("Pending Requests", stats['pending'].toString(), Colors.orange, Icons.hourglass_empty_outlined, isDark),
              _buildStatSummaryCard("Completed Today", stats['completedToday'].toString(), Colors.green, Icons.check_circle_outline, isDark),
              _buildStatSummaryCard("Total Patients", stats['totalPatients'].toString(), Colors.indigo, Icons.group_outlined, isDark),
            ],
          ),
          
          const SizedBox(height: 28),
          
          // 3. AI Assistant Section
          Text('AI Health Assistant', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _buildAIActionButton(Icons.chat_bubble_outline, 'Medical Chat', isDark),
              _buildAIActionButton(Icons.analytics_outlined, 'Lab Report Analysis', isDark),
              _buildAIActionButton(Icons.description_outlined, 'Prescription Analysis', isDark),
              _buildAIActionButton(Icons.tips_and_updates_outlined, 'Clinical Suggestions', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIActionButton(IconData icon, String label, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: isDark ? Colors.black38 : Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (label == 'Medical Chat') {
            Navigator.pushNamed(context, '/chatbot');
          } else if (label == 'Lab Report Analysis') {
            Navigator.pushNamed(context, '/lab-reports');
          } else if (label == 'Prescription Analysis') {
            Navigator.pushNamed(context, '/ocr-reader');
          } else if (label == 'Clinical Suggestions') {
            Navigator.pushNamed(context, '/chatbot');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: isDark ? Colors.purple[300] : Colors.purple[800], size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey[800]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatSummaryCard(String label, String value, Color color, IconData icon, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? color.withOpacity(0.3) : color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: isDark ? Colors.black38 : Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            Text(
              label,
              style: GoogleFonts.outfit(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey[700], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// TAB 2: APPOINTMENTS TAB
// ----------------------------------------------------
class DoctorAppointmentsTab extends StatefulWidget {
  final String doctorId;
  final bool isDarkMode;
  const DoctorAppointmentsTab({super.key, required this.doctorId, required this.isDarkMode});

  @override
  State<DoctorAppointmentsTab> createState() => _DoctorAppointmentsTabState();
}

class _DoctorAppointmentsTabState extends State<DoctorAppointmentsTab> {
  final BookingService _bookingService = BookingService();
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  final Set<String> _selectedPendingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  void _fetchAppointments() {
    _bookingService.getDoctorAppointmentsStream(widget.doctorId).listen((data) {
      if (mounted) {
        setState(() {
          _appointments = data;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await _bookingService.updateAppointmentStatus(id, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Appointment $status successfully.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status.')),
        );
      }
    }
  }

  Future<void> _bulkAction(String status) async {
    if (_selectedPendingIds.isEmpty) return;
    
    try {
      for (final id in _selectedPendingIds) {
        await _bookingService.updateAppointmentStatus(id, status);
      }
      
      setState(() {
        _selectedPendingIds.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk $status updated successfully.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bulk action failed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final pending = _appointments
        .where((appt) => appt['status']?.toString().toLowerCase() == 'pending')
        .toList();
        
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final approved = _appointments.where((appt) {
      final status = appt['status']?.toString().toLowerCase() ?? '';
      final date = appt['date'] ?? '';
      return date == todayStr && (status == 'approved' || status == 'checked_in');
    }).toList();

    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = isDark ? const Color(0xFF0F0F1A) : Colors.white;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Manage Schedules',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DoctorHistoryScreen(appointments: _appointments),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('View History'),
                    ),
                  ],
                ),
              ),
              TabBar(
                labelColor: isDark ? Colors.white : Colors.black87,
                unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                indicatorColor: Theme.of(context).primaryColor,
                tabs: const [
                  Tab(text: 'Pending Requests'),
                  Tab(text: 'Today\'s Approved'),
                ],
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // PENDING REQUESTS VIEW
            _buildPendingRequestsList(pending),
            
            // APPROVED APPOINTMENTS VIEW
            _buildApprovedAppointmentsList(approved),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequestsList(List<Map<String, dynamic>> pendingList) {
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[600];

    if (pendingList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty_outlined, size: 48, color: isDark ? Colors.grey[700] : Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No pending requests found.', style: GoogleFonts.outfit(color: subtitleColor)),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_selectedPendingIds.isNotEmpty)
          Container(
            color: theme.primaryColor.withOpacity(0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedPendingIds.length} requests selected',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: theme.primaryColor),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _bulkAction('rejected'),
                      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                      label: const Text('Reject', style: TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _bulkAction('approved'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendingList.length,
            itemBuilder: (context, index) {
              final appt = pendingList[index];
              final id = appt['id'] ?? '';
              final isSelected = _selectedPendingIds.contains(id);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? theme.primaryColor : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!)),
                  boxShadow: [
                    BoxShadow(color: isDark ? Colors.black38 : Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedPendingIds.add(id);
                                } else {
                                  _selectedPendingIds.remove(id);
                                }
                              });
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appt['patient_name'] ?? 'Patient Profile',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text('ID: ${appt['patient_id'] ?? ''}', style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Profile Linked',
                                  style: GoogleFonts.outfit(fontSize: 10, color: isDark ? Colors.blue[300] : Colors.blue[800], fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 4),
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: BookingService().getPatientReports(appt['patient_id'] ?? ''),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.description, size: 10, color: Colors.red),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Reports (${snapshot.data!.length})',
                                            style: GoogleFonts.outfit(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: subtitleColor),
                          const SizedBox(width: 4),
                          Text(appt['date'] ?? '', style: GoogleFonts.outfit(fontSize: 14, color: textColor)),
                          const SizedBox(width: 16),
                          Icon(Icons.access_time, size: 16, color: subtitleColor),
                          const SizedBox(width: 4),
                          Text(appt['time_slot'] ?? '', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Symptoms / Problem:', style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w500)),
                      Text(appt['symptoms'] ?? 'No symptoms specified', style: GoogleFonts.outfit(fontSize: 14, color: textColor)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PatientDetailsScreen(patientId: appt['patient_id']),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                textStyle: const TextStyle(fontSize: 12),
                                minimumSize: const Size(0, 36),
                              ),
                              child: const Text('View Reports', maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _updateStatus(id, 'rejected'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                textStyle: const TextStyle(fontSize: 12),
                                minimumSize: const Size(0, 36),
                              ),
                              child: const Text('Reject', maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _updateStatus(id, 'approved'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                textStyle: const TextStyle(fontSize: 12),
                                minimumSize: const Size(0, 36),
                              ),
                              child: const Text('Approve', maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
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
    );
  }

  Widget _buildApprovedAppointmentsList(List<Map<String, dynamic>> approvedList) {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[600];

    if (approvedList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_outlined, size: 48, color: isDark ? Colors.grey[700] : Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No approved appointments today.', style: GoogleFonts.outfit(color: subtitleColor)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: approvedList.length,
      itemBuilder: (context, index) {
        final appt = approvedList[index];
        final status = appt['status']?.toString().toLowerCase() ?? 'approved';
        final isCheckedIn = status == 'checked_in';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isCheckedIn ? (isDark ? Colors.green[700]! : Colors.green) : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!)),
            boxShadow: [
              BoxShadow(color: isDark ? Colors.black38 : Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      appt['patient_name'] ?? 'Patient Profile',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCheckedIn ? (isDark ? Colors.green.withOpacity(0.15) : Colors.green[50]) : (isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCheckedIn ? 'Checked-In' : 'Approved',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: isCheckedIn ? (isDark ? Colors.green[300] : Colors.green[800]) : (isDark ? Colors.blue[300] : Colors.blue[800]),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                 Text('ID: ${appt['patient_id'] ?? ''}', style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: subtitleColor),
                    const SizedBox(width: 4),
                    Text(appt['time_slot'] ?? '', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person_search_outlined),
                      tooltip: 'Patient Details',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PatientDetailsScreen(patientId: appt['patient_id']),
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    if (!isCheckedIn)
                      Flexible(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(appt['id'], 'checked_in'),
                          icon: const Icon(Icons.login_outlined, size: 16),
                          label: const Text('Mark Checked-In', maxLines: 1, overflow: TextOverflow.ellipsis),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                      ),
                    if (isCheckedIn)
                      Flexible(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(appt['id'], 'completed'),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Complete Appointment', maxLines: 1, overflow: TextOverflow.ellipsis),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------
// TAB 3: PROFILE TAB (Availability configuration)
// ----------------------------------------------------
class DoctorProfileTab extends StatefulWidget {
  final UserModel user;
  final bool isDarkMode;
  const DoctorProfileTab({super.key, required this.user, required this.isDarkMode});

  @override
  State<DoctorProfileTab> createState() => _DoctorProfileTabState();
}

class _DoctorProfileTabState extends State<DoctorProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late bool _isOnline;
  late double _consultationFee;
  late List<String> _workingDays;
  late String _startTime;
  late String _endTime;
  late int _duration;
  late int _buffer;
  late String _breakStart;
  late String _breakEnd;
  late String _languagesString;

  final List<String> _allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final avail = widget.user.availability ?? DoctorAvailability.defaultVal();
    _isOnline = widget.user.onlineStatus ?? true;
    _consultationFee = widget.user.consultationFee ?? 500.0;
    _workingDays = List<String>.from(avail.workingDays);
    _startTime = avail.startTime;
    _endTime = avail.endTime;
    _duration = avail.consultationDuration;
    _buffer = avail.bufferTime;
    _breakStart = avail.breakTimeStart;
    _breakEnd = avail.breakTimeEnd;
    _languagesString = widget.user.languages?.join(', ') ?? 'English, Hindi';
  }

  Future<void> _selectTime(BuildContext context, bool isStart, String current, Function(String) onSelected) async {
    final parts = current.split(':');
    final time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(context: context, initialTime: time);
    
    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minStr = picked.minute.toString().padLeft(2, '0');
      setState(() {
        onSelected('$hourStr:$minStr');
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);

    try {
      final updatedAvailability = DoctorAvailability(
        workingDays: _workingDays,
        startTime: _startTime,
        endTime: _endTime,
        consultationDuration: _duration,
        bufferTime: _buffer,
        breakTimeStart: _breakStart,
        breakTimeEnd: _breakEnd,
      );

      final languagesList = _languagesString
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await _db.collection('users').doc(widget.user.uid).update({
        'onlineStatus': _isOnline,
        'consultationFee': _consultationFee,
        'languages': languagesList,
        'availability': updatedAvailability.toJson(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile availability saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save profile details.')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[600];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Doctor Profile Header
            Container(
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
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: theme.primaryColor.withOpacity(0.1),
                      child: Text(
                        widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'D',
                        style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: theme.primaryColor),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.user.name,
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              if (widget.user.verified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, color: Colors.blue, size: 18),
                              ],
                            ],
                          ),
                          Text(widget.user.qualification ?? 'Physician', style: GoogleFonts.outfit(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                          Text('Dept: ${widget.user.department ?? 'N/A'}', style: GoogleFonts.outfit(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[500])),
                          Text('License: ${widget.user.rejectionReason ?? widget.user.uid.substring(0, 8)}', style: GoogleFonts.outfit(fontSize: 11, color: isDark ? Colors.grey[600] : Colors.grey[400])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Online Switch & Fee Card
            Container(
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
                  children: [
                    SwitchListTile(
                      title: Text('Practice Status', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
                      subtitle: Text(_isOnline ? 'Online' : 'Offline', style: TextStyle(color: subtitleColor)),
                      value: _isOnline,
                      onChanged: (val) => setState(() => _isOnline = val),
                    ),
                    Divider(color: isDark ? Colors.white24 : null),
                    TextFormField(
                      initialValue: _consultationFee.toInt().toString(),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Consultation Fee (INR)',
                        labelStyle: TextStyle(color: subtitleColor),
                        prefixIcon: Icon(Icons.currency_rupee, color: subtitleColor),
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      onChanged: (val) {
                        final valDouble = double.tryParse(val);
                        if (valDouble != null) {
                          _consultationFee = valDouble;
                        }
                      },
                    ),
                    Divider(color: isDark ? Colors.white24 : null),
                    TextFormField(
                      initialValue: _languagesString,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Languages (comma separated)',
                        labelStyle: TextStyle(color: subtitleColor),
                        prefixIcon: Icon(Icons.language_outlined, color: subtitleColor),
                        border: InputBorder.none,
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      onChanged: (val) => _languagesString = val,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Availability Settings Card
            Text('Availability Configuration', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 12),
            Container(
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
                  children: [
                    // Working Days Checklist
                    Text('Select Working Days:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _allDays.map((day) {
                        final isSelected = _workingDays.contains(day);
                        return FilterChip(
                          label: Text(day, style: GoogleFonts.outfit(fontSize: 12, color: isSelected ? Colors.white : textColor)),
                          selected: isSelected,
                          selectedColor: theme.primaryColor,
                          backgroundColor: isDark ? const Color(0xFF252538) : Colors.grey[100],
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _workingDays.add(day);
                              } else {
                                _workingDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const Divider(height: 24),
                    
                    // Start/End Timings
                    Text('Consultation Hours:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectTime(context, true, _startTime, (val) => _startTime = val),
                            icon: Icon(Icons.login_outlined, color: textColor),
                            label: Text('Start: $_startTime', style: TextStyle(color: textColor)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectTime(context, false, _endTime, (val) => _endTime = val),
                            icon: Icon(Icons.logout_outlined, color: textColor),
                            label: Text('End: $_endTime', style: TextStyle(color: textColor)),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Consultation duration and buffer
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _duration,
                            dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                            decoration: InputDecoration(
                              labelText: 'Duration',
                              labelStyle: TextStyle(color: subtitleColor),
                            ),
                            items: [15, 20, 30].map((mins) {
                              return DropdownMenuItem(
                                value: mins,
                                child: Text('$mins mins', style: TextStyle(color: textColor)),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _duration = val!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _buffer,
                            dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                            decoration: InputDecoration(
                              labelText: 'Buffer Time',
                              labelStyle: TextStyle(color: subtitleColor),
                            ),
                            items: [0, 5, 10].map((mins) {
                              return DropdownMenuItem(
                                value: mins,
                                child: Text('$mins mins', style: TextStyle(color: textColor)),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _buffer = val!),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Break Time Timings
                    Text('Break Time (Lunch etc.):', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectTime(context, true, _breakStart, (val) => _breakStart = val),
                            icon: Icon(Icons.free_breakfast_outlined, color: textColor),
                            label: Text('Break Start: $_breakStart', style: TextStyle(color: textColor)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectTime(context, false, _breakEnd, (val) => _breakEnd = val),
                            icon: Icon(Icons.work_history_outlined, color: textColor),
                            label: Text('Break End: $_breakEnd', style: TextStyle(color: textColor)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Save Settings', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
