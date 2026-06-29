import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/theme/theme_notifier.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/theme/glassmorphism.dart';
import 'package:frontend/widgets/shared_glass_components.dart';
import 'package:frontend/services/prescription_service.dart';
import 'package:frontend/models/prescription_model.dart';

class PrescriptionReaderScreen extends StatefulWidget {
  const PrescriptionReaderScreen({super.key});

  @override
  State<PrescriptionReaderScreen> createState() => _PrescriptionReaderScreenState();
}

class _PrescriptionReaderScreenState extends State<PrescriptionReaderScreen> {
  File? _image;
  bool _isLoading = false;
  PrescriptionAnalysisResult? _analysisResult;
  final PrescriptionService _prescriptionService = PrescriptionService();
  String _loadingMessage = 'Processing image...';

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85, // Compress slightly to ensure quick uploads
      );
      
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _analysisResult = null;
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to pick image: $e');
    }
  }

  Future<void> _analyzePrescription() async {
    if (_image == null) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Uploading to server...';
    });

    // Simple delayed updates to loading message for better user experience feedback
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isLoading) {
        setState(() => _loadingMessage = 'Gemini AI is reading the prescription...');
      }
    });
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _isLoading) {
        setState(() => _loadingMessage = 'Extracting structured medicine details...');
      }
    });

    try {
      final result = await _prescriptionService.analyzePrescription(_image!);
      
      if (!mounted) return;
      
      setState(() {
        _analysisResult = result;
      });
      
      if (!result.success) {
        _showErrorDialog(result.message.isNotEmpty 
            ? result.message 
            : 'Gemini could not read the prescription. Please ensure the image is clear.');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _reset() {
    setState(() {
      _image = null;
      _analysisResult = null;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline, size: 40, color: Colors.red),
        title: Text('Analysis Error', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeNotifier>(context).isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'MediDoc Analyze',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor),
        ),
        actions: [
          if (_image != null || _analysisResult != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
              onPressed: _reset,
              color: textColor,
            )
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.getBackgroundGradient(isDark),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_analysisResult == null) ...[
                  _buildImageSelectorCard(theme, isDark),
                const SizedBox(height: 24),
                if (_image != null && !_isLoading)
                  ElevatedButton.icon(
                    onPressed: _analyzePrescription,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.analytics_outlined),
                    label: Text(
                      'Analyze Prescription',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
                if (_isLoading) _buildLoadingState(theme, isDark),
                if (_analysisResult != null && !_isLoading) _buildResultsView(theme, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSelectorCard(ThemeData theme, bool isDark) {
    return GlassContainer(
      isDarkMode: isDark,
      borderRadius: 24,
      child: Container(
        height: 320,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
        ),
        child: _image != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_image!, fit: BoxFit.cover),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black54],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildImageActionButton(
                          icon: Icons.camera_alt,
                          label: 'Retake',
                          onPressed: () => _pickImage(ImageSource.camera),
                        ),
                        _buildImageActionButton(
                          icon: Icons.photo_library,
                          label: 'Gallery',
                          onPressed: () => _pickImage(ImageSource.gallery),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.document_scanner_outlined,
                      size: 64,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Scan Your Prescription',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'Take a photo of your handwritten/printed prescription or select it from gallery.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildImageActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withAlpha(200),
        foregroundColor: Colors.black87,
        elevation: 0,
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    return GlassContainer(
      isDarkMode: isDark,
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
      child: Column(
        children: [
          const CircularProgressIndicator(strokeWidth: 4),
          const SizedBox(height: 24),
          Text(
            'Analyzing Prescription',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _loadingMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(ThemeData theme, bool isDark) {
    final result = _analysisResult!;
    
    if (!result.success) {
      return _buildUnknownDocumentView(theme, result);
    }

    switch (result.documentType) {
      case 'Laboratory Report':
        return _buildLabReportView(theme, result);
      case 'Medical Bill':
        return _buildMedicalBillView(theme, result);
      case 'Discharge Summary':
        return _buildDischargeSummaryView(theme, result);
      case 'Unknown Medical Document':
        return _buildUnknownDocumentView(theme, result);
      case 'Prescription':
      default:
        return _buildPrescriptionView(theme, result);
    }
  }

  Widget _buildPrescriptionView(ThemeData theme, PrescriptionAnalysisResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Prescription Overview Info
        Text(
          'Prescription Details',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        _buildOverviewCard(theme, result),
        const SizedBox(height: 24),
        
        // Medicines Title
        Text(
          'Extracted Medicines (${result.medicines.length})',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        
        if (result.medicines.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No medicines were identified. Please review the image manually.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: result.medicines.length,
            itemBuilder: (context, index) {
              return _buildMedicineCard(theme, result.medicines[index]);
            },
          ),
          
        const SizedBox(height: 12),
        if (result.notes.isNotEmpty) ...[
          Text(
            'Doctor Notes',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                result.notes,
                style: GoogleFonts.outfit(fontSize: 14, color: theme.colorScheme.onSurface),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        ElevatedButton.icon(
          onPressed: _reset,
          style: ElevatedButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.document_scanner),
          label: Text(
            'Scan Another Prescription',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLabReportView(ThemeData theme, PrescriptionAnalysisResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Report Type Card
        Card(
          color: theme.colorScheme.primaryContainer.withAlpha(40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(Icons.science, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  '🧪 Report Type: ',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Expanded(
                  child: Text(
                    result.reportType.isNotEmpty ? result.reportType : 'General Lab Report',
                    style: GoogleFonts.outfit(fontSize: 16, color: theme.colorScheme.onSurface),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Test Results
        Text(
          '📊 Test Results',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),

        if (result.labResults.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No lab parameters were extracted.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: result.labResults.length,
            itemBuilder: (context, index) {
              final item = result.labResults[index];
              Color statusColor = Colors.grey;
              if (item.status.toLowerCase() == 'normal') statusColor = Colors.green;
              if (item.status.toLowerCase() == 'high') statusColor = Colors.red;
              if (item.status.toLowerCase() == 'low') statusColor = Colors.orange;
              if (item.status.toLowerCase() == 'borderline') statusColor = Colors.amber;

              final shortExplanation = _getShortExplanation(item.explanation);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.parameter,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.status.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Value', style: GoogleFonts.outfit(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.value} ${item.unit}',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Reference Range', style: GoogleFonts.outfit(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 2),
                                Text(
                                  item.referenceRange.isNotEmpty ? item.referenceRange : 'N/A',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (shortExplanation.isNotEmpty &&
                          (item.status.toLowerCase() == 'high' ||
                           item.status.toLowerCase() == 'low' ||
                           item.status.toLowerCase() == 'borderline')) ...[
                        const Divider(height: 20),
                        Text(
                          '💡 $shortExplanation',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        // Overall Summary
        if (result.summary.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.description_outlined, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Overall Summary',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                result.summary,
                style: GoogleFonts.outfit(fontSize: 14, color: theme.colorScheme.onSurface),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Lifestyle Recommendations
        if (result.recommendation.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.spa_outlined, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Lifestyle Recommendations',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                result.recommendation,
                style: GoogleFonts.outfit(fontSize: 14, color: theme.colorScheme.onSurface),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Doctor Advice
        if (result.warnings.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Doctor Advice',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                result.warnings,
                style: GoogleFonts.outfit(
                  fontSize: 14, 
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        ElevatedButton.icon(
          onPressed: _reset,
          style: ElevatedButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.document_scanner),
          label: Text(
            'Scan Another Document',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMedicalBillView(ThemeData theme, PrescriptionAnalysisResult result) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bill Details Card
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (result.hospital.isNotEmpty)
                  _buildOverviewRow(theme, Icons.local_hospital_outlined, 'Hospital', result.hospital, isDark),
                if (result.date.isNotEmpty)
                  _buildOverviewRow(theme, Icons.calendar_today_outlined, 'Bill Date', result.date, isDark),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Bill Summary Breakdown
        Text(
          '💵 Bill Summary',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),

        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analysis & Charges Breakdown:',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Text(
                  result.summary.isNotEmpty ? result.summary : 'No billing summary breakdown was generated.',
                  style: GoogleFonts.outfit(fontSize: 14, color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton.icon(
          onPressed: _reset,
          style: ElevatedButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.document_scanner),
          label: Text(
            'Scan Another Document',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDischargeSummaryView(ThemeData theme, PrescriptionAnalysisResult result) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Overview Details
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (result.patientName.isNotEmpty)
                  _buildOverviewRow(theme, Icons.person_outline, 'Patient', result.patientName, isDark),
                if (result.hospital.isNotEmpty)
                  _buildOverviewRow(theme, Icons.local_hospital_outlined, 'Hospital', result.hospital, isDark),
                if (result.date.isNotEmpty)
                  _buildOverviewRow(theme, Icons.calendar_today_outlined, 'Discharge Date', result.date, isDark),
                if (result.diagnosis.isNotEmpty)
                  _buildOverviewRow(theme, Icons.healing_outlined, 'Diagnosis', result.diagnosis, isDark),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Prescribed Medicines
        if (result.medicines.isNotEmpty) ...[
          Text(
            '💊 Discharge Medicines (${result.medicines.length})',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: result.medicines.length,
            itemBuilder: (context, index) {
              return _buildMedicineCard(theme, result.medicines[index]);
            },
          ),
          const SizedBox(height: 20),
        ],

        // Follow up Advice
        if (result.followUp.isNotEmpty) ...[
          Text(
            '📅 Follow-up Advice',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                result.followUp,
                style: GoogleFonts.outfit(fontSize: 14, color: theme.colorScheme.onSurface),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // AI Summary / Explanation
        if (result.summary.isNotEmpty) ...[
          Text(
            '📝 AI Summary',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                result.summary,
                style: GoogleFonts.outfit(fontSize: 14, color: theme.colorScheme.onSurface),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        ElevatedButton.icon(
          onPressed: _reset,
          style: ElevatedButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.document_scanner),
          label: Text(
            'Scan Another Document',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildUnknownDocumentView(ThemeData theme, PrescriptionAnalysisResult result) {
    return Column(
      children: [
        Card(
          color: theme.colorScheme.errorContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Icon(Icons.warning_amber_rounded, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  'Identification Failed',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onErrorContainer),
                ),
                const SizedBox(height: 8),
                Text(
                  'We could not identify this medical document. Please upload a clearer image.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 14, color: theme.colorScheme.onErrorContainer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Try Another Image'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(ThemeData theme, PrescriptionAnalysisResult result) {
    final isDark = Provider.of<ThemeNotifier>(context, listen: false).isDarkMode;
    return GlassContainer(
      isDarkMode: isDark,
      borderRadius: 20,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (result.patientName.isNotEmpty)
            _buildOverviewRow(theme, Icons.person_outline, 'Patient', result.patientName, isDark),
          if (result.doctorName.isNotEmpty)
            _buildOverviewRow(theme, Icons.medical_services_outlined, 'Doctor', result.doctorName, isDark),
          if (result.hospital.isNotEmpty)
            _buildOverviewRow(theme, Icons.local_hospital_outlined, 'Hospital', result.hospital, isDark),
          if (result.date.isNotEmpty)
            _buildOverviewRow(theme, Icons.calendar_today_outlined, 'Date', result.date, isDark),
          if (result.diagnosis.isNotEmpty)
            _buildOverviewRow(theme, Icons.healing_outlined, 'Diagnosis', result.diagnosis, isDark),
          if (result.followUp.isNotEmpty)
            _buildOverviewRow(theme, Icons.event_repeat_outlined, 'Follow-up', result.followUp, isDark),
        ],
      ),
    );
  }

  Widget _buildOverviewRow(ThemeData theme, IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(ThemeData theme, MedicineModel med) {
    final isDark = Provider.of<ThemeNotifier>(context, listen: false).isDarkMode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        isDarkMode: isDark,
        borderRadius: 16,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                  child: Icon(Icons.medication, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (med.strength.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Strength: ${med.strength}',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                if (med.dosage.isNotEmpty)
                  Expanded(
                    child: _buildMedicineDetailItem(theme, Icons.adjust, 'Dosage', med.dosage),
                  ),
                if (med.frequency.isNotEmpty)
                  Expanded(
                    child: _buildMedicineDetailItem(theme, Icons.repeat, 'Frequency', med.frequency),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (med.duration.isNotEmpty)
                  Expanded(
                    child: _buildMedicineDetailItem(theme, Icons.hourglass_empty, 'Duration', med.duration),
                  ),
                if (med.instruction.isNotEmpty)
                  Expanded(
                    child: _buildMedicineDetailItem(theme, Icons.info_outline, 'Instruction', med.instruction),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineDetailItem(ThemeData theme, IconData icon, String title, String val) {
    final isDark = Provider.of<ThemeNotifier>(context, listen: false).isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.secondaryColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 22.0),
          child: Text(
            val,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  String _getShortExplanation(String explanation) {
    if (explanation.isEmpty) return '';
    // Split by sentence delimiters (. or ! or ?)
    final sentences = explanation.split(RegExp(r'[.!?]'));
    String firstSentence = sentences.first.trim();
    if (firstSentence.isEmpty && sentences.length > 1) {
      firstSentence = sentences[1].trim();
    }
    // Split by spaces to count words
    final words = firstSentence.split(RegExp(r'\s+'));
    if (words.length > 10) {
      return '${words.take(10).join(' ')}...';
    }
    return firstSentence.isNotEmpty ? '$firstSentence.' : '';
  }
}
