import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/theme/theme_notifier.dart';
import 'package:frontend/models/lab_profile_model.dart';
import 'package:frontend/services/lab_service.dart';

class LabDashboard extends StatefulWidget {
  const LabDashboard({super.key});

  @override
  State<LabDashboard> createState() => _LabDashboardState();
}

class _LabDashboardState extends State<LabDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F0F1A) : Colors.grey[50];

    final tabs = [
      const LabDashboardTab(key: ValueKey('tab_dashboard')),
      const LabManagementTab(key: ValueKey('tab_management')),
      const LabProfileTab(key: ValueKey('tab_profile')),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'MediNexa Lab',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.amber : Colors.blueGrey,
            ),
            onPressed: () => themeNotifier.toggleDarkMode(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Provider.of<AuthProvider>(context, listen: false).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: tabs[_currentIndex],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/chatbot'),
        backgroundColor: isDark ? const Color(0xFFBB86FC) : Colors.purple,
        foregroundColor: Colors.white,
        tooltip: 'AI Chatbot',
        child: const Icon(Icons.smart_toy_outlined),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          debugPrint('LabDashboard: BottomNavigationBar onTap: index = $index');
          setState(() => _currentIndex = index);
        },
        selectedItemColor: isDark ? const Color(0xFFBB86FC) : Colors.purple,
        unselectedItemColor: isDark ? Colors.white60 : Colors.grey[600],
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_outlined),
            activeIcon: Icon(Icons.fact_check),
            label: 'Management',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// TAB 1: LAB DASHBOARD
// ----------------------------------------------------
class LabDashboardTab extends StatefulWidget {
  const LabDashboardTab({super.key});

  @override
  State<LabDashboardTab> createState() => _LabDashboardTabState();
}

class _LabDashboardTabState extends State<LabDashboardTab> {
  final LabService _labService = LabService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];
  Map<String, int> _counts = {
    'todayBookings': 0,
    'pending': 0,
    'checkedIn': 0,
    'completed': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  void _fetchDashboardData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final labId = authProvider.user?.uid ?? '';

    _labService.getLabBookingsStream(labId).listen((bookingsList) {
      if (!mounted) return;

      int todayCount = 0;
      int pendingCount = 0;
      int checkedInCount = 0;
      int completedCount = 0;

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      for (var b in bookingsList) {
        final status = b['status']?.toString().toLowerCase() ?? 'pending';
        final bookingDate = b['date'] ?? '';

        if (bookingDate == todayStr) {
          todayCount++;
        }

        if (status == 'pending') {
          pendingCount++;
        } else if (status == 'checked_in' || b['reportFileId'] != null) {
          if (status == 'completed') {
            completedCount++;
          } else {
            checkedInCount++;
          }
        } else if (status == 'completed') {
          completedCount++;
        }
      }

      setState(() {
        _bookings = bookingsList;
        _counts = {
          'todayBookings': todayCount,
          'pending': pendingCount,
          'checkedIn': checkedInCount,
          'completed': completedCount,
        };
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeNotifier>(context).isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[700];

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final recentActivities = _bookings.toList()
      ..sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome Back,',
            style: GoogleFonts.outfit(fontSize: 16, color: subtitleColor),
          ),
          Text(
            Provider.of<AuthProvider>(context).user?.name ?? 'Lab Owner',
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 24),
          Text(
            'Overview Summary',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _buildStatCard("Today's Bookings", _counts['todayBookings'].toString(), Colors.blue, Icons.today, isDark),
              _buildStatCard("Pending Requests", _counts['pending'].toString(), Colors.orange, Icons.hourglass_empty, isDark),
              _buildStatCard("Checked In", _counts['checkedIn'].toString(), Colors.indigo, Icons.where_to_vote, isDark),
              _buildStatCard("Completed Reports", _counts['completed'].toString(), Colors.green, Icons.check_circle_outline, isDark),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Recent Activities',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 12),
          recentActivities.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'No recent bookings or activities found.',
                      style: GoogleFonts.outfit(color: subtitleColor),
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentActivities.take(5).length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey[100]),
                    itemBuilder: (context, index) {
                      final item = recentActivities[index];
                      final status = item['status']?.toString().toUpperCase() ?? 'PENDING';
                      final testName = item['testName'] ?? 'Lab Test';
                      final patientName = item['patientName'] ?? 'Patient';

                      Color statusClr = Colors.orange;
                      if (status == 'ACCEPTED') statusClr = Colors.blue;
                      if (status == 'CHECKED_IN') statusClr = Colors.indigo;
                      if (status == 'COMPLETED') statusClr = Colors.green;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusClr.withOpacity(0.12),
                          child: Icon(Icons.science, color: statusClr, size: 20),
                        ),
                        title: Text(
                          '$testName - $patientName',
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        subtitle: Text(
                          'ID: ${item['bookingId'] ?? ''} • ${item['date']} ${item['time_slot']}',
                          style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusClr.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: statusClr),
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

  Widget _buildStatCard(String label, String value, Color color, IconData icon, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? color.withOpacity(0.3) : color.withOpacity(0.2)),
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
                Icon(icon, color: color, size: 22),
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            Text(
              label,
              style: GoogleFonts.outfit(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[700], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// TAB 2: LAB MANAGEMENT
// ----------------------------------------------------
class LabManagementTab extends StatefulWidget {
  const LabManagementTab({super.key});

  @override
  State<LabManagementTab> createState() => _LabManagementTabState();
}

class _LabManagementTabState extends State<LabManagementTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LabService _labService = LabService();

  // Search & Filter state
  String _searchQuery = '';
  String? _selectedTestFilter;
  DateTime? _selectedDateFilter;

  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;

  // File upload state mapping: bookingId -> progress/status
  final Map<String, double> _uploadProgress = {};
  final Map<String, String> _uploadStatus = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _fetchBookings() {
    final labId = Provider.of<AuthProvider>(context, listen: false).user?.uid ?? '';
    _labService.getLabBookingsStream(labId).listen((bookingsList) {
      if (mounted) {
        setState(() {
          _bookings = bookingsList;
          _isLoading = false;
        });
      }
    });
  }

  List<Map<String, dynamic>> _getFilteredList(String status) {
    return _bookings.where((b) {
      final bStatus = b['status']?.toString().toLowerCase() ?? 'pending';
      if (bStatus != status) return false;

      // Search filters
      final bookingId = (b['bookingId'] ?? '').toString().toLowerCase();
      final patientName = (b['patientName'] ?? '').toString().toLowerCase();
      final testName = (b['testName'] ?? '').toString().toLowerCase();

      final matchesSearch = bookingId.contains(_searchQuery.toLowerCase()) ||
          patientName.contains(_searchQuery.toLowerCase());

      final matchesTest = _selectedTestFilter == null || testName.contains(_selectedTestFilter!.toLowerCase());

      bool matchesDate = true;
      if (_selectedDateFilter != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDateFilter!);
        matchesDate = b['date'] == dateStr;
      }

      return matchesSearch && matchesTest && matchesDate;
    }).toList();
  }

  Future<void> _pickAndUploadPDF(String bookingId) async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final fileSizeMB = file.lengthSync() / (1024 * 1024);

    if (fileSizeMB > 10.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File exceeds 10 MB limit. Please select a smaller PDF.')),
      );
      return;
    }

    // If report already exists, show confirmation dialog
    final booking = _bookings.firstWhere((b) => b['bookingId'] == bookingId);
    if (booking['reportFileId'] != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace Report?'),
          content: const Text('A report is already uploaded for this booking. Do you want to replace it?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Replace')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _uploadProgress[bookingId] = 0.1;
      _uploadStatus[bookingId] = 'Uploading...';
    });

    try {
      await _labService.uploadReportPDF(bookingId, file);
      if (mounted) {
        setState(() {
          _uploadProgress[bookingId] = 1.0;
          _uploadStatus[bookingId] = 'Upload Complete';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report PDF uploaded successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Upload PDF error in lab_dashboard: $e');
      if (mounted) {
        setState(() {
          _uploadProgress.remove(bookingId);
          _uploadStatus.remove(bookingId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _deletePDF(String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report?'),
        content: const Text('Are you sure you want to delete the uploaded report PDF?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _labService.deleteReportPDF(bookingId);
      if (mounted) {
        setState(() {
          _uploadProgress.remove(bookingId);
          _uploadStatus.remove(bookingId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report PDF deleted successfully!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete PDF.')),
        );
      }
    }
  }

  void _showCheckInDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Check In Patient'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter Booking ID (e.g. LAB2606270001)',
              labelText: 'Booking ID',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final id = controller.text.trim();
                final bookingExists = _bookings.any((b) => b['bookingId'] == id && b['status'] == 'accepted');
                if (bookingExists) {
                  await _labService.updateBookingStatus(id, 'checked_in');
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Checked In Booking: $id')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Booking ID not found or not yet accepted.')),
                  );
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeNotifier>(context).isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[700];

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Search & Filter Panel
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Search by Patient Name or Booking ID...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedTestFilter,
                decoration: InputDecoration(
                  labelText: 'Filter Test',
                  fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Tests')),
                  ..._labService.getPredefinedTests().map((t) => DropdownMenuItem(
                        value: t.split(' (').first,
                        child: Text(t.split(' (').first, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (val) => setState(() => _selectedTestFilter = val),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDateFilter ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 90)),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        setState(() => _selectedDateFilter = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: subtitleColor),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDateFilter == null ? 'All Dates' : DateFormat('MMM dd').format(_selectedDateFilter!),
                              style: GoogleFonts.outfit(color: textColor, fontSize: 13),
                            ),
                            if (_selectedDateFilter != null) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() => _selectedDateFilter = null),
                                child: Icon(Icons.close, size: 14, color: subtitleColor),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _showCheckInDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFFBB86FC) : Colors.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        minimumSize: const Size(0, 40),
                      ),
                      child: const Text('Check In'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: isDark ? Colors.white : Colors.black87,
          unselectedLabelColor: subtitleColor,
          indicatorColor: isDark ? const Color(0xFFBB86FC) : Colors.purple,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'CheckedIn'),
            Tab(text: 'Completed'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildListSection('pending'),
              _buildListSection('accepted'),
              _buildListSection('checked_in'),
              _buildListSection('completed'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListSection(String status) {
    final list = _getFilteredList(status);
    final isDark = Provider.of<ThemeNotifier>(context).isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[700];

    if (list.isEmpty) {
      return Center(
        child: Text(
          'No bookings matching filters.',
          style: GoogleFonts.outfit(color: subtitleColor),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final b = list[index];
        final id = b['bookingId'] ?? '';
        final patientName = b['patientName'] ?? 'Patient';
        final testName = b['testName'] ?? 'Lab Test';
        final slot = b['time_slot'] ?? '';
        final date = b['date'] ?? '';
        final symptoms = b['symptoms'] ?? 'No comments';
        final pdfUrl = b['reportFileId'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      patientName,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'ID: $id',
                    style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Test: $testName',
                style: GoogleFonts.outfit(fontSize: 14, color: textColor, fontWeight: FontWeight.w500),
              ),
              Text(
                'Slot: $date  •  $slot',
                style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Patient Symptoms / Reason:',
                style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.bold),
              ),
              Text(
                symptoms,
                style: GoogleFonts.outfit(fontSize: 13, color: textColor),
              ),
              const SizedBox(height: 12),
              if (_uploadStatus.containsKey(id)) ...[
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _uploadProgress[id],
                        color: Colors.green,
                        backgroundColor: Colors.grey[300],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _uploadStatus[id]!,
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (status == 'pending') ...[
                    ElevatedButton(
                      onPressed: () => _labService.updateBookingStatus(id, 'accepted'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, minimumSize: const Size(0, 40)),
                      child: const Text('Accept Booking'),
                    ),
                  ],
                  if (status == 'accepted') ...[
                    ElevatedButton.icon(
                      onPressed: () => _labService.updateBookingStatus(id, 'checked_in'),
                      icon: const Icon(Icons.where_to_vote, size: 16),
                      label: const Text('Check In'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, minimumSize: const Size(0, 40)),
                    ),
                  ],
                  if (status == 'checked_in') ...[
                    if (pdfUrl != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deletePDF(id),
                        tooltip: 'Delete Uploaded PDF',
                      ),
                    ElevatedButton.icon(
                      onPressed: () => _pickAndUploadPDF(id),
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: Text(pdfUrl != null ? 'Replace PDF' : 'Upload PDF Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pdfUrl != null ? Colors.amber[800] : Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                      ),
                    ),
                    if (pdfUrl != null)
                      ElevatedButton(
                        onPressed: () => _labService.updateBookingStatus(id, 'completed'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(0, 40)),
                        child: const Text('Mark Completed'),
                      ),
                  ],
                  if (status == 'completed') ...[
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'Completed & Shared',
                      style: GoogleFonts.outfit(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------
// TAB 3: LAB PROFILE
// ----------------------------------------------------
class LabProfileTab extends StatefulWidget {
  const LabProfileTab({super.key});

  @override
  State<LabProfileTab> createState() => _LabProfileTabState();
}

class _LabProfileTabState extends State<LabProfileTab> {
  final LabService _labService = LabService();
  LabProfileModel? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('LabProfileTab: initState called');
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    debugPrint('LabProfileTab: _fetchProfile started');
    try {
      final labId = Provider.of<AuthProvider>(context, listen: false).user?.uid ?? '';
      debugPrint('LabProfileTab: user labId = $labId');
      final data = await _labService.getLabProfile(labId);
      debugPrint('LabProfileTab: fetched profile data = $data');
      if (mounted) {
        setState(() {
          _profile = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("LabProfileTab: Error fetching lab profile: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile details: $e')),
        );
      }
    }
  }

  void _showEditServiceDialog(String testName, LabServiceDetail? currentDetail) {
    final priceController = TextEditingController(text: currentDetail?.price.toString() ?? '500');
    final timeController = TextEditingController(text: currentDetail?.reportTime.toString() ?? '24');
    bool enabled = currentDetail?.enabled ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('Edit $testName Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price (INR)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(labelText: 'Approx Report Time (Hours)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Offer this test'),
                value: enabled,
                onChanged: (val) => setDlgState(() => enabled = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final price = double.tryParse(priceController.text) ?? 500.0;
                final time = int.tryParse(timeController.text) ?? 24;

                final updatedServices = Map<String, LabServiceDetail>.from(_profile?.services ?? {});
                updatedServices[testName] = LabServiceDetail(price: price, reportTime: time, enabled: enabled);

                final updatedProfile = LabProfileModel(
                  labId: _profile!.labId,
                  labName: _profile!.labName,
                  ownerName: _profile!.ownerName,
                  phone: _profile!.phone,
                  email: _profile!.email,
                  address: _profile!.address,
                  location: _profile!.location,
                  website: _profile!.website,
                  openingTime: _profile!.openingTime,
                  closingTime: _profile!.closingTime,
                  homeCollection: _profile!.homeCollection,
                  emergencyTesting: _profile!.emergencyTesting,
                  services: updatedServices,
                );

                await _labService.updateLabProfile(updatedProfile);
                await _fetchProfile();
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('LabProfileTab: build called (isLoading = $_isLoading, profile = $_profile)');
    final isDark = Provider.of<ThemeNotifier>(context).isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[700];

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                'Lab Profile Details Missing',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Please complete or re-create your lab profile registration details.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: subtitleColor),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  setState(() => _isLoading = true);
                  final labId = Provider.of<AuthProvider>(context, listen: false).user?.uid ?? '';
                  final userModel = Provider.of<AuthProvider>(context, listen: false).user;
                  if (userModel != null) {
                    final labProfileData = {
                      'labId': labId,
                      'labName': 'My Lab',
                      'ownerName': userModel.name,
                      'phone': userModel.phoneNumber ?? '',
                      'email': userModel.email,
                      'address': '',
                      'location': '',
                      'website': '',
                      'openingTime': '09:00 AM',
                      'closingTime': '06:00 PM',
                      'homeCollection': false,
                      'emergencyTesting': false,
                      'status': 'pending',
                      'verified': false,
                      'createdAt': FieldValue.serverTimestamp(),
                      'services': {},
                    };
                    try {
                      await _labService.updateLabProfile(LabProfileModel.fromJson(labProfileData));
                      await _fetchProfile();
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to initialize: $e')),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 45)),
                child: const Text('Re-initialize Profile'),
              )
            ],
          ),
        ),
      );
    }

    final predefinedTests = _labService.getPredefinedTests();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Lab Identity Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.purple.withOpacity(0.12),
                      child: const Icon(Icons.science, size: 30, color: Colors.purple),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile!.labName,
                            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          Text(
                            'Owner: ${_profile!.ownerName}',
                            style: GoogleFonts.outfit(fontSize: 14, color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.phone, _profile!.phone, textColor),
                const SizedBox(height: 10),
                _buildInfoRow(Icons.email, _profile!.email, textColor),
                const SizedBox(height: 10),
                _buildInfoRow(Icons.location_on, _profile!.address, textColor),
                const SizedBox(height: 10),
                _buildInfoRow(Icons.access_time, 'Hours: ${_profile!.openingTime} - ${_profile!.closingTime}', textColor),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (_profile!.location.isNotEmpty) ...[
                      ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(_profile!.location);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.map, size: 16),
                        label: const Text('Open Maps'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.withOpacity(0.12),
                          foregroundColor: Colors.purple,
                          elevation: 0,
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_profile!.website.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(_profile!.website);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.language, size: 16),
                        label: const Text('Website'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.withOpacity(0.12),
                          foregroundColor: Colors.blue,
                          elevation: 0,
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Offered Lab Services',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: predefinedTests.length,
            itemBuilder: (context, index) {
              final testFull = predefinedTests[index];
              final testName = testFull.split(' (').first;
              final currentDetail = _profile!.services[testName];
              final isOffered = currentDetail?.enabled ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOffered
                        ? (isDark ? Colors.purple.withOpacity(0.5) : Colors.purple.withOpacity(0.3))
                        : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!),
                  ),
                ),
                child: ListTile(
                  title: Text(
                    testFull,
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  subtitle: isOffered
                      ? Text(
                          'Price: INR ${currentDetail!.price} • Report: ${currentDetail.reportTime} Hours',
                          style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor),
                        )
                      : Text(
                          'Not currently offered',
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                        ),
                  trailing: Icon(
                    isOffered ? Icons.check_circle : Icons.add_circle_outline,
                    color: isOffered ? Colors.green : Colors.grey,
                  ),
                  onTap: () => _showEditServiceDialog(testName, currentDetail),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(fontSize: 13, color: textColor),
          ),
        ),
      ],
    );
  }
}
