import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:frontend/config/api_config.dart';

class PdfViewerScreen extends StatefulWidget {
  final String fileId;
  final String filename;

  const PdfViewerScreen({
    super.key,
    required this.fileId,
    required this.filename,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _error;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final url = '${ApiConfig.baseUrl}/storage/file/${widget.fileId}';
      
      final response = await http.get(
        Uri.parse(url),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      // Debug logs
      debugPrint("=== PDF Viewer Debug Log ===");
      debugPrint("Requested fileId: ${widget.fileId}");
      debugPrint("HTTP status code: ${response.statusCode}");
      debugPrint("Response content-type: ${response.headers['content-type']}");
      debugPrint("Response size (bytes): ${response.bodyBytes.length}");
      
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _pdfBytes = response.bodyBytes;
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to load PDF (HTTP ${response.statusCode}): ${response.body}");
      }
    } catch (e, stackTrace) {
      debugPrint("Exception stack trace: $stackTrace");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadPdf(Uint8List bytes) async {
    try {
      String path = "";
      String finalFilename = widget.filename;
      bool wroteSuccessfully = false;
      String filePath = "";

      // Try writing to public Downloads folder first on Android
      if (Platform.isAndroid) {
        try {
          final dir = Directory('/storage/emulated/0/Download');
          if (await dir.exists()) {
            filePath = "${dir.path}/$finalFilename";
            var file = File(filePath);
            if (await file.exists()) {
              final nameWithoutExt = finalFilename.endsWith('.pdf') 
                  ? finalFilename.substring(0, finalFilename.length - 4) 
                  : finalFilename;
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              filePath = "${dir.path}/${nameWithoutExt}_$timestamp.pdf";
            }
            file = File(filePath);
            await file.writeAsBytes(bytes);
            wroteSuccessfully = true;
          }
        } catch (e) {
          debugPrint("Failed to write directly to public Downloads folder: $e. Falling back to application documents directory.");
        }
      }

      // Fallback/Default for iOS or if Android public write fails
      if (!wroteSuccessfully) {
        final appDir = await getApplicationDocumentsDirectory();
        path = appDir.path;
        filePath = "$path/$finalFilename";
        var file = File(filePath);
        if (await file.exists()) {
          final nameWithoutExt = finalFilename.endsWith('.pdf') 
              ? finalFilename.substring(0, finalFilename.length - 4) 
              : finalFilename;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          filePath = "$path/${nameWithoutExt}_$timestamp.pdf";
        }
        file = File(filePath);
        await file.writeAsBytes(bytes);
        wroteSuccessfully = true;
      }

      // Debug logs as requested
      debugPrint("=== Download Debug Log ===");
      debugPrint("Download path: $filePath");
      debugPrint("File size: ${bytes.length} bytes");
      debugPrint("Save success: true");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report downloaded successfully'),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                try {
                  final result = await OpenFilex.open(filePath);
                  debugPrint("OpenFilex result: ${result.message}");
                } catch (e, stackTrace) {
                  debugPrint("OpenFilex exception: $e");
                  debugPrint("Stack trace: $stackTrace");
                }
              },
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint("=== Download Debug Log ===");
      debugPrint("Save success: false");
      debugPrint("Exception: $e");
      debugPrint("Stack trace: $stackTrace");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save file locally: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filename, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                : const Icon(Icons.download),
            tooltip: 'Download PDF',
            onPressed: (_pdfBytes == null || _isDownloading)
                ? null
                : () async {
                    setState(() {
                      _isDownloading = true;
                    });
                    await _downloadPdf(_pdfBytes!);
                    setState(() {
                      _isDownloading = false;
                    });
                  },
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading PDF: $_error',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (_pdfBytes != null) {
            return SfPdfViewer.memory(_pdfBytes!);
          }
          return const Center(child: Text('No PDF data available'));
        },
      ),
    );
  }
}
