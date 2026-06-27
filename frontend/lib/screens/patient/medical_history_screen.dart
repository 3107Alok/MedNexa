import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/services/booking_service.dart';
import 'package:frontend/services/lab_service.dart';
import 'package:frontend/theme/theme_notifier.dart';

class MedicalHistoryScreen extends StatefulWidget {
  const MedicalHistoryScreen({super.key});

  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  final BookingService _bookingService = BookingService();
  final LabService _labService = LabService();

  List<Map<String, dynamic>>? _doctorBookings;
  List<Map<String, dynamic>>? _labBookings;

  StreamSubscription? _doctorSub;
  StreamSubscription? _labSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final patientId = authProvider.user?.uid ?? '';

      _doctorSub = _bookingService.getPatientAppointmentsStream(patientId).listen((data) {
        if (mounted) {
          setState(() => _doctorBookings = data);
        }
      });

      _labSub = _labService.getPatientLabBookingsStream(patientId).listen((data) {
        if (mounted) {
          setState(() {
            _labBookings = data.map((e) {
              e['isLab'] = true;
              return e;
            }).toList();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _doctorSub?.cancel();
    _labSub?.cancel();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'approved':
        return Colors.blue;
      case 'checked_in':
      case 'checked in':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDarkMode;

    final bgColor = isDark ? const Color(0xFF0F0F1A) : Colors.grey[50];
    final cardBgColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[600];

    if (_doctorBookings == null || _labBookings == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text('Appointment History')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final combined = [..._doctorBookings!, ..._labBookings!];
    combined.sort((a, b) {
      final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      return bTime.compareTo(aTime);
    });

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Appointment History',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.transparent,
      ),
      body: combined.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 64, color: isDark ? Colors.grey[700] : Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Appointments Booked',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your booked appointments & lab tests will appear here.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: combined.length,
              itemBuilder: (context, index) {
                final appt = combined[index];
                final isLab = appt['isLab'] == true;
                final status = appt['status']?.toString() ?? 'pending';
                final statusColor = _getStatusColor(status);

                final bookingTimeText = appt['createdAt'] != null
                    ? DateFormat('MMM dd, yyyy • hh:mm a').format((appt['createdAt'] as Timestamp).toDate())
                    : 'Just now';

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: cardBgColor,
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
                                          isLab
                                              ? (appt['labName'] ?? 'Diagnostic Lab')
                                              : (appt['doctor_name'] ?? 'Doctor'),
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  if (isLab)
                                    Text(
                                      'LAB BOOKING • ${appt['testName']}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: subtitleColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else
                                    FutureBuilder<Map<String, dynamic>?>(
                                      future: _bookingService.getPatientById(appt['doctor_id'] ?? ''),
                                      builder: (context, docSnapshot) {
                                        if (docSnapshot.hasData && docSnapshot.data != null) {
                                          final docData = docSnapshot.data!;
                                          final dept = docData['department'] ?? docData['category'] ?? 'General Medicine';
                                          final spec = docData['specialization'] ?? '';
                                          final displayInfo = spec.isNotEmpty ? '$dept ($spec)' : dept;
                                          return Text(
                                            displayInfo,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: subtitleColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        }
                                        return Text(
                                          'General Medicine',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: subtitleColor,
                                          ),
                                        );
                                      },
                                    ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 14, color: subtitleColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${appt['date']}  •  ${appt['time_slot']}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Reason / Symptoms:',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: subtitleColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    appt['symptoms'] ?? 'No symptoms provided',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isLab ? 'Booking ID:' : 'Booked On:',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          color: subtitleColor,
                                        ),
                                      ),
                                      Text(
                                        isLab ? (appt['bookingId'] ?? '') : bookingTimeText,
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          color: subtitleColor,
                                          fontWeight: FontWeight.w500,
                                        ),
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
    );
  }
}
