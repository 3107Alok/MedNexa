import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:frontend/config/api_config.dart';
import 'package:frontend/screens/pdf_viewer_screen.dart';
import 'package:frontend/screens/image_viewer_screen.dart';
import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/services/booking_service.dart';

class PatientDetailsScreen extends StatefulWidget {
  final String patientId;

  const PatientDetailsScreen({super.key, required this.patientId});

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  final BookingService _bookingService = BookingService();
  bool _isLoading = true;
  bool _hasAccess = false;
  Map<String, dynamic>? _patientData;
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _visits = [];
  List<dynamic> _patientDocuments = [];
  bool _isLoadingDocs = true;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoadData();
  }

  Future<void> _checkAccessAndLoadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final doctor = authProvider.user;

    if (doctor == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Verify doctor-patient privacy access
      final hasAccess = await _bookingService.verifyDoctorAccessToPatient(doctor.uid, widget.patientId);
      
      if (!hasAccess) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
        return;
      }

      // 2. Load Patient Basic Info
      final patientInfo = await _bookingService.getPatientById(widget.patientId);
      
      // 3. Load Lab Reports from Flask Backend MongoDB storage_metadata
      List<Map<String, dynamic>> labReports = [];
      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        final url = '${ApiConfig.baseUrl}/storage/patient/${widget.patientId}/lab-reports';
        final response = await http.get(
          Uri.parse(url),
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        );
        if (response.statusCode == 200) {
          final List<dynamic> decoded = jsonDecode(response.body);
          labReports = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } catch (e) {
        debugPrint("Error loading patient lab reports: $e");
      }
      
      // 4. Load Completed Visits with THIS doctor only
      final visits = await _bookingService.getPreviousVisitsWithDoctor(doctor.uid, widget.patientId);

      // 5. Load Patient Documents from Flask Backend MongoDB storage_metadata
      List<dynamic> docsList = [];
      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        final url = '${ApiConfig.baseUrl}/storage/patient/${widget.patientId}/documents';
        final response = await http.get(
          Uri.parse(url),
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        );
        if (response.statusCode == 200) {
          docsList = jsonDecode(response.body);
        }
      } catch (e) {
        debugPrint("Error loading patient documents: $e");
      }

      setState(() {
        _hasAccess = true;
        _patientData = patientInfo;
        _reports = labReports;
        _visits = visits;
        _patientDocuments = docsList;
        _isLoadingDocs = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patient Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: theme.colorScheme.errorContainer,
          foregroundColor: theme.colorScheme.onErrorContainer,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              color: theme.colorScheme.errorContainer.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: theme.colorScheme.error.withOpacity(0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gpp_bad_rounded, size: 80, color: theme.colorScheme.error),
                    const SizedBox(height: 24),
                    Text(
                      'Access Denied',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Strict Patient Privacy Policy. You can only view profiles of patients scheduled for appointment with you.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final String name = _patientData?['name'] ?? 'Patient Details';
    final String age = _patientData?['age'] ?? 'N/A';
    final String gender = _patientData?['gender'] ?? 'N/A';
    final String phone = _patientData?['phone'] ?? _patientData?['phoneNumber'] ?? 'N/A';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.outfit(),
            tabs: const [
              Tab(text: 'Overview & Reports', icon: Icon(Icons.info_outline)),
              Tab(text: 'Visit History', icon: Icon(Icons.history)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Overview & Reports Tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic Details Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Basic Details', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _buildDetailRow(Icons.cake_outlined, 'Age', '$age years'),
                          _buildDetailRow(Icons.wc_outlined, 'Gender', gender),
                          _buildDetailRow(Icons.phone_outlined, 'Phone', phone),
                          _buildDetailRow(Icons.fingerprint_outlined, 'Patient ID', widget.patientId),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Lab & Medical Reports Section
                  Text('Lab & Medical Reports', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_reports.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No lab reports available.', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13)),
                    ),
                  ] else ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final report = _reports[index];
                        final fileId = report['fileId'] ?? '';
                        final originalFilename = report['originalFilename'] ?? 'report.pdf';
                        final documentName = report['documentName'] ?? originalFilename;
                        final rawDate = report['createdAt'];
                        
                        String displayDate = 'Uploaded recently';
                        if (rawDate != null) {
                          try {
                            final dt = DateTime.parse(rawDate.toString());
                            displayDate = '${dt.day}/${dt.month}/${dt.year}';
                          } catch (_) {}
                        }
                        
                        final labName = report['labName'];
                        final displayLab = labName != null ? 'Lab: $labName' : 'Lab: N/A';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.withOpacity(0.12),
                              child: const Icon(Icons.analytics_outlined, color: Colors.blue),
                            ),
                            title: Text(documentName, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('Date: $displayDate  •  $displayLab', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500])),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.blue, size: 20),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PdfViewerScreen(
                                          fileId: fileId,
                                          filename: documentName,
                                        ),
                                      ),
                                    );
                                  },
                                  tooltip: 'View Report',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.download, color: Colors.green, size: 20),
                                  onPressed: () => _downloadDocument(fileId, originalFilename),
                                  tooltip: 'Download Report',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  _buildPatientDocumentsSection(),
                ],
              ),
            ),
            
            // Visits Tab (History with THIS doctor only)
            _visits.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No Previous Visits',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Completed appointments between you and this patient will appear here.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _visits.length,
                    itemBuilder: (context, index) {
                      final visit = _visits[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[200]!),
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
                                    visit['date'] ?? '',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: theme.primaryColor),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Completed',
                                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.green[800], fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Time Slot: ${visit['time_slot'] ?? ''}', style: GoogleFonts.outfit(fontSize: 14)),
                              const SizedBox(height: 8),
                              if (visit['symptoms'] != null) ...[
                                Text('Symptoms / Symptoms Details:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[700])),
                                Text(visit['symptoms'], style: GoogleFonts.outfit(fontSize: 14)),
                              ],
                            ],
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Text('$label: ', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.grey[600])),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(String title, String date, String summary, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(date, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 12),
            Text(
              summary,
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[800], height: 1.4),
            ),
          ],
        ),
      ),
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

  String _getDocumentEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('prescription') || lower.contains('rx') || lower.contains('medicine') || lower.contains('doctor')) {
      return '🩺 ';
    } else if (lower.contains('mri') || lower.contains('scan') || lower.contains('xray') || lower.contains('x-ray') || lower.contains('image') || lower.contains('photo') || lower.contains('ultrasound')) {
      return '🖼 ';
    } else if (lower.contains('insurance') || lower.contains('card') || lower.contains('id') || lower.contains('policy')) {
      return '📄 ';
    } else if (lower.contains('blood') || lower.contains('test') || lower.contains('lab') || lower.contains('report')) {
      return '🩸 ';
    }
    return '📄 ';
  }

  Widget _buildPatientDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('Patient Health Documents', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _isLoadingDocs
            ? const Center(child: CircularProgressIndicator())
            : _patientDocuments.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No health documents uploaded by patient.', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
                            '${_getDocumentEmoji(name)}$name',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
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
                                'Uploaded by: Patient',
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
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ],
    );
  }
}
