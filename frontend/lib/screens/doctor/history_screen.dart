import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:frontend/screens/doctor/patient_details_screen.dart';

class DoctorHistoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> appointments;

  const DoctorHistoryScreen({super.key, required this.appointments});

  @override
  State<DoctorHistoryScreen> createState() => _DoctorHistoryScreenState();
}

class _DoctorHistoryScreenState extends State<DoctorHistoryScreen> {
  Map<String, List<Map<String, dynamic>>> _groupedAppointments = {};
  List<String> _sortedDates = [];

  @override
  void initState() {
    super.initState();
    _groupAndSortAppointments();
  }

  void _groupAndSortAppointments() {
    final completed = widget.appointments
        .where((appt) => appt['status']?.toString().toLowerCase() == 'completed')
        .toList();

    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final appt in completed) {
      final dateStr = appt['date'] ?? 'Unknown Date';
      if (!groups.containsKey(dateStr)) {
        groups[dateStr] = [];
      }
      groups[dateStr]!.add(appt);
    }

    // Sort dates descending
    final dates = groups.keys.toList();
    dates.sort((a, b) => b.compareTo(a));

    setState(() {
      _groupedAppointments = groups;
      _sortedDates = dates;
    });
  }

  String _formatHeaderDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Appointment History', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: _sortedDates.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No History Available',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When you complete appointments, they will show up here grouped by date.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sortedDates.length,
              itemBuilder: (context, index) {
                final dateKey = _sortedDates[index];
                final list = _groupedAppointments[dateKey] ?? [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      _formatHeaderDate(dateKey),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: theme.primaryColor),
                    ),
                    subtitle: Text('${list.length} appointments completed', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
                    leading: const Icon(Icons.calendar_today_outlined),
                    shape: const Border(),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: list.map((appt) {
                      final patientId = appt['patient_id'] ?? 'N/A';
                      final symptoms = appt['symptoms'] ?? 'No symptoms reported';
                      final timeSlot = appt['time_slot'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Slot: $timeSlot',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PatientDetailsScreen(patientId: patientId),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'View Patient ID: $patientId',
                                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: theme.primaryColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Reason for visit / Symptoms:',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              symptoms,
                              style: GoogleFonts.outfit(fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}
