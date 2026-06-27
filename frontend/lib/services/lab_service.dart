import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:frontend/config/api_config.dart';
import 'package:frontend/models/lab_profile_model.dart';

class LabService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Lab Profiles
  Future<LabProfileModel?> getLabProfile(String labId) async {
    final doc = await _db.collection('lab_profiles').doc(labId).get();
    if (doc.exists && doc.data() != null) {
      return LabProfileModel.fromJson(doc.data()!);
    }
    return null;
  }

  Future<void> updateLabProfile(LabProfileModel profile) async {
    await _db.collection('lab_profiles').doc(profile.labId).set(profile.toJson(), SetOptions(merge: true));
  }

  Stream<List<LabProfileModel>> getApprovedLabsStream() {
    return _db
        .collection('lab_profiles')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => LabProfileModel.fromJson(doc.data())).toList());
  }

  // Generate Sequential Booking ID: LABYYMMDDXXXX
  Future<String> generateBookingId() async {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final datePrefix = 'LAB$year$month$day';

    // Query today's bookings to count and generate sequential ID
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final query = await _db
        .collection('lab_bookings')
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThanOrEqualTo: endOfDay)
        .get();

    final sequence = (query.docs.length + 1).toString().padLeft(4, '0');
    return '$datePrefix$sequence';
  }

  // Book Appointment
  Future<void> bookLabTest(Map<String, dynamic> bookingData) async {
    final bookingId = await generateBookingId();
    bookingData['bookingId'] = bookingId;
    bookingData['status'] = 'pending';
    bookingData['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('lab_bookings').doc(bookingId).set(bookingData);
  }

  // Stream of bookings for a specific Lab
  Stream<List<Map<String, dynamic>>> getLabBookingsStream(String labId) {
    return _db
        .collection('lab_bookings')
        .where('labId', isEqualTo: labId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Stream of completed lab bookings for patient
  Stream<List<Map<String, dynamic>>> getPatientLabReportsStream(String patientId) {
    return _db
        .collection('lab_bookings')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Stream of all patient bookings (for history screen)
  Stream<List<Map<String, dynamic>>> getPatientLabBookingsStream(String patientId) {
    return _db
        .collection('lab_bookings')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Update Booking Status
  Future<void> updateBookingStatus(String bookingId, String status) async {
    final updateData = <String, dynamic>{
      'status': status,
    };
    if (status == 'completed') {
      updateData['completedAt'] = FieldValue.serverTimestamp();
    }
    await _db.collection('lab_bookings').doc(bookingId).update(updateData);
  }

  // Upload Report PDF
  Future<String> uploadReportPDF(String bookingId, File file) async {
    debugPrint('=== uploadReportPDF START ===');
    
    try {
      final bookingSnap = await _db.collection('lab_bookings').doc(bookingId).get();
      if (!bookingSnap.exists) {
        throw Exception('Booking not found');
      }
      
      final bookingData = bookingSnap.data()!;
      final patientId = bookingData['patientId'] ?? '';
      final labId = bookingData['labId'] ?? '';

      final uri = Uri.parse('${ApiConfig.baseUrl}/storage/upload');
      final request = http.MultipartRequest('POST', uri);
      
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken != null) {
        request.headers['Authorization'] = 'Bearer $idToken';
      }
      
      request.fields['patientId'] = patientId;
      request.fields['bookingId'] = bookingId;
      request.fields['labId'] = labId;
      request.fields['reportType'] = 'lab_report';
      
      final stream = http.ByteStream(file.openRead());
      final length = await file.length();
      final multipartFile = http.MultipartFile(
        'file',
        stream,
        length,
        filename: file.path.split('/').last,
        contentType: MediaType('application', 'pdf'),
      );
      request.files.add(multipartFile);

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        final decoded = jsonDecode(responseBody);
        final fileId = decoded['fileId'];
        
        await _db.collection('lab_bookings').doc(bookingId).update({
          'reportFileId': fileId,
          'reportType': 'lab_report',
          'reportUploadedAt': FieldValue.serverTimestamp(),
          'pdfUrl': FieldValue.delete(),
        });
        
        debugPrint('=== uploadReportPDF SUCCESS ===');
        return fileId;
      } else {
        throw Exception('Upload failed: $responseBody');
      }
    } catch (e, stackTrace) {
      debugPrint('=== uploadReportPDF FAILED ===');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  // Delete Report PDF
  Future<void> deleteReportPDF(String bookingId) async {
    try {
      final bookingSnap = await _db.collection('lab_bookings').doc(bookingId).get();
      if (bookingSnap.exists) {
        final fileId = bookingSnap.data()?['reportFileId'];
        if (fileId != null && fileId.toString().isNotEmpty) {
          final uri = Uri.parse('${ApiConfig.baseUrl}/storage/file/$fileId');
          final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
          
          await http.delete(
            uri,
            headers: idToken != null ? {'Authorization': 'Bearer $idToken'} : {},
          );
        }
      }
    } catch (_) {
      // ignore
    }
    await _db.collection('lab_bookings').doc(bookingId).update({
      'reportFileId': FieldValue.delete(),
      'reportUploadedAt': FieldValue.delete(),
      'pdfUrl': FieldValue.delete(),
    });
  }

  // Predefined Laboratory Tests List
  List<String> getPredefinedTests() {
    return [
      'CBC (Complete Blood Count)',
      'Blood Glucose / HbA1c',
      'Liver Function Test (LFT)',
      'Kidney Function Test (KFT)',
      'Thyroid Profile (T3, T4, TSH)',
      'Lipid Profile (Cholesterol)',
      'Vitamin D3 & B12',
      'Urine Analysis',
    ];
  }
}
