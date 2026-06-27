import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/theme/theme_notifier.dart';
import 'package:frontend/models/lab_profile_model.dart';
import 'package:frontend/services/lab_service.dart';

class LabBookingScreen extends StatefulWidget {
  final String? selectedTest;
  const LabBookingScreen({super.key, this.selectedTest});

  @override
  State<LabBookingScreen> createState() => _LabBookingScreenState();
}

class _LabBookingScreenState extends State<LabBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final LabService _labService = LabService();

  String? _selectedTest;
  DateTime? _selectedDate;
  LabProfileModel? _selectedLab;
  String? _selectedSlot;
  final _symptomsController = TextEditingController();

  List<LabProfileModel> _availableLabs = [];
  bool _isLoadingLabs = false;
  List<String> _slots = [];
  bool _isLoadingSlots = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedTest != null) {
      _selectedTest = widget.selectedTest;
    }
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    super.dispose();
  }

  // Fetch Labs offering selected test
  Future<void> _fetchAvailableLabs() async {
    if (_selectedTest == null || _selectedDate == null) return;
    setState(() {
      _isLoadingLabs = true;
      _selectedLab = null;
      _selectedSlot = null;
      _availableLabs = [];
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('lab_profiles')
          .where('status', isEqualTo: 'approved')
          .get();

      final list = <LabProfileModel>[];
      for (var doc in querySnapshot.docs) {
        final profile = LabProfileModel.fromJson(doc.data());
        final testName = _selectedTest!.split(' (').first;
        if (profile.services.containsKey(testName) && profile.services[testName]!.enabled) {
          list.add(profile);
        }
      }

      setState(() {
        _availableLabs = list;
        _isLoadingLabs = false;
      });
    } catch (_) {
      setState(() => _isLoadingLabs = false);
    }
  }

  // Generate Slots dynamically for selected date & lab
  Future<void> _generateAvailableSlots() async {
    if (_selectedLab == null || _selectedDate == null) return;
    setState(() {
      _isLoadingSlots = true;
      _selectedSlot = null;
      _slots = [];
    });

    try {
      // 1. Get already booked slots for this lab and date
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final bookingsQuery = await FirebaseFirestore.instance
          .collection('lab_bookings')
          .where('labId', isEqualTo: _selectedLab!.labId)
          .where('date', isEqualTo: dateStr)
          .get();

      final bookedSlots = bookingsQuery.docs
          .map((doc) => doc.data()['time_slot']?.toString())
          .where((s) => s != null)
          .toList();

      // 2. Parse Opening / Closing times (e.g. "09:00 AM" / "06:00 PM")
      final openFormat = DateFormat('hh:mm a');
      final openTime = openFormat.parse(_selectedLab!.openingTime);
      final closeTime = openFormat.parse(_selectedLab!.closingTime);

      final generated = <String>[];
      var current = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, openTime.hour, openTime.minute);
      final end = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, closeTime.hour, closeTime.minute);

      final now = DateTime.now();
      final isToday = dateStr == DateFormat('yyyy-MM-dd').format(now);

      while (current.isBefore(end)) {
        final slotStr = DateFormat('hh:mm a').format(current);
        
        bool isFuture = true;
        if (isToday) {
          if (current.isBefore(now)) {
            isFuture = false;
          }
        }

        if (isFuture && !bookedSlots.contains(slotStr)) {
          generated.add(slotStr);
        }
        current = current.add(const Duration(hours: 1)); // Hourly slots
      }

      setState(() {
        _slots = generated;
        _isLoadingSlots = false;
      });
    } catch (_) {
      setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _confirmBooking() async {
    if (!_formKey.currentState!.validate() || _selectedLab == null || _selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select lab, date, slot & enter symptoms.')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final testName = _selectedTest!.split(' (').first;
    final price = _selectedLab!.services[testName]?.price ?? 500.0;

    final bookingData = {
      'patientId': authProvider.user?.uid,
      'patientName': authProvider.user?.name ?? 'Patient',
      'labId': _selectedLab!.labId,
      'labName': _selectedLab!.labName,
      'testName': testName,
      'price': price,
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
      'time_slot': _selectedSlot,
      'symptoms': _symptomsController.text.trim(),
    };

    try {
      await _labService.bookLabTest(bookingData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lab Appointment Booked Successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking Failed. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeNotifier>(context).isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[700];

    return Scaffold(
      appBar: AppBar(
        title: Text('Book Lab Test', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Select Test
              DropdownButtonFormField<String>(
                value: _selectedTest,
                decoration: const InputDecoration(
                  labelText: 'Select Diagnostic Test',
                  prefixIcon: Icon(Icons.science),
                ),
                items: _labService.getPredefinedTests().map((t) {
                  return DropdownMenuItem(value: t, child: Text(t));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedTest = val;
                  });
                  _fetchAvailableLabs();
                },
              ),
              const SizedBox(height: 20),

              // 2. Select Date
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Choose Booking Date',
                  prefixIcon: const Icon(Icons.calendar_today),
                  hintText: _selectedDate == null
                      ? 'Select date'
                      : DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDate!),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _fetchAvailableLabs();
                  }
                },
              ),
              const SizedBox(height: 28),

              // 3. Available Labs List
              if (_selectedTest != null && _selectedDate != null) ...[
                Text(
                  'Available Labs offering this test',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 12),
                _isLoadingLabs
                    ? const Center(child: CircularProgressIndicator())
                    : _availableLabs.isEmpty
                        ? Text(
                            'No labs available offering this test on this date.',
                            style: GoogleFonts.outfit(color: subtitleColor, fontSize: 13),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _availableLabs.length,
                            itemBuilder: (context, index) {
                              final lab = _availableLabs[index];
                              final isSelected = _selectedLab?.labId == lab.labId;
                              final testKey = _selectedTest!.split(' (').first;
                              final detail = lab.services[testKey];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.primaryColor
                                        : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedLab = lab);
                                    _generateAvailableSlots();
                                  },
                                  borderRadius: BorderRadius.circular(16),
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
                                                lab.labName,
                                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'INR ${detail?.price ?? 500.0}',
                                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: theme.primaryColor),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Report Delivery: Approx ${detail?.reportTime ?? 24} Hours',
                                          style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor),
                                        ),
                                        Text(
                                          'Address: ${lab.address}',
                                          style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor),
                                        ),
                                        const SizedBox(height: 8),
                                        if (lab.location.isNotEmpty)
                                          GestureDetector(
                                            onTap: () async {
                                              final uri = Uri.parse(lab.location);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                              }
                                            },
                                            child: Row(
                                              children: [
                                                const Icon(Icons.map, size: 14, color: Colors.blue),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'View on Google Maps',
                                                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ],
              const SizedBox(height: 20),

              // 4. Select Time Slot
              if (_selectedLab != null) ...[
                Text(
                  'Select Available Time Slot',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 12),
                _isLoadingSlots
                    ? const Center(child: CircularProgressIndicator())
                    : _slots.isEmpty
                        ? Text(
                            'No slots available for today/selected date.',
                            style: GoogleFonts.outfit(color: subtitleColor, fontSize: 13),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _slots.map((s) {
                              final isSel = _selectedSlot == s;
                              return ChoiceChip(
                                label: Text(s, style: GoogleFonts.outfit(color: isSel ? Colors.white : textColor)),
                                selected: isSel,
                                selectedColor: theme.primaryColor,
                                onSelected: (val) {
                                  if (val) setState(() => _selectedSlot = s);
                                },
                              );
                            }).toList(),
                          ),
              ],
              const SizedBox(height: 20),

              // 5. Symptoms / Comments
              if (_selectedSlot != null) ...[
                TextFormField(
                  controller: _symptomsController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for visit / Symptoms',
                    prefixIcon: Icon(Icons.comment),
                  ),
                  maxLines: 3,
                  validator: (v) => v!.isEmpty ? 'Please enter reason for visit' : null,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _confirmBooking,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Book Test Now',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
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
