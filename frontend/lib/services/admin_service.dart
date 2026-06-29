import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/services/notification_service.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isDoctor(Map<String, dynamic> data) {
    final roleStr = data['role']?.toString().toLowerCase();
    if (roleStr == 'doctor') return true;
    if (roleStr == 'patient' || roleStr == 'admin') return false;
    
    // Legacy detection fallback: doctor-specific fields
    return data.containsKey('qualification') ||
        data.containsKey('specialization') ||
        data.containsKey('license') ||
        data.containsKey('registrationNumber') ||
        data.containsKey('hospital') ||
        data.containsKey('consultationFee') ||
        data.containsKey('availability');
  }

  bool _isAdmin(Map<String, dynamic> data) {
    final roleStr = data['role']?.toString().toLowerCase();
    if (roleStr == 'admin') return true;
    final emailStr = data['email']?.toString().toLowerCase();
    if (emailStr == 'admin@medinexa.com') return true;
    return false;
  }

  bool _isPatient(Map<String, dynamic> data) {
    if (_isDoctor(data)) return false;
    if (_isAdmin(data)) return false;
    return true; // default fallback is patient
  }

  Future<List<dynamic>> getPendingDoctors() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        })
        .where((data) {
          final isDoc = _isDoctor(data);
          final statusStr = data['status']?.toString().toLowerCase() ?? '';
          return isDoc && statusStr == 'pending';
        })
        .toList();
  }

  Future<void> verifyDoctor(String uid, String status) async {
    await _db.collection('users').doc(uid).update({
      'status': status.toLowerCase(),
      'verified': status.toLowerCase() == 'verified',
      'rejectionReason': FieldValue.delete(),
    });

    if (status.toLowerCase() == 'verified') {
      await NotificationService.addNotification(
        userId: uid,
        title: 'Account Approved 🎉',
        body: 'Your doctor profile has been successfully verified by the Admin. You can now consult patients.',
      );
    }
  }

  Future<void> rejectDoctor(String uid, String reason) async {
    await _db.collection('users').doc(uid).update({
      'status': 'rejected',
      'verified': false,
      'rejectionReason': reason,
    });

    await NotificationService.addNotification(
      userId: uid,
      title: 'Account Rejection ❌',
      body: 'Your doctor profile verification was rejected. Reason: $reason',
    );
  }

  Future<Map<String, int>> getDashboardStats() async {
    try {
      final usersSnapshot = await _db.collection('users').get();
      final appointmentsSnapshot = await _db.collection('appointments').get();
      final labBookingsSnapshot = await _db.collection('lab_bookings').where('status', isEqualTo: 'completed').get();

      int patientCount = 0;
      int doctorCount = 0;
      int pendingCount = 0;
      int registeredLabsCount = 0;
      int completedLabTestsCount = labBookingsSnapshot.docs.length;

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final role = data['role']?.toString() ?? 'null';
        final status = data['status']?.toString() ?? 'null';
        final isDoc = _isDoctor(data);
        final isAdminUser = _isAdmin(data);
        final isPat = _isPatient(data);

        if (isDoc) {
          doctorCount++;
          final statusStr = status.toLowerCase();
          if (statusStr == 'pending') {
            pendingCount++;
          }
        } else if (isAdminUser) {
          // Exclude admin
        } else if (role == 'labOwner') {
          registeredLabsCount++;
          if (status.toLowerCase() == 'pending') {
            pendingCount++;
          }
        } else if (isPat) {
          patientCount++;
        }
      }

      final result = {
        'patients': patientCount,
        'doctors': doctorCount,
        'appointments': appointmentsSnapshot.docs.length,
        'pendingVerifications': pendingCount,
        'totalLabs': registeredLabsCount,
        'completedLabTests': completedLabTestsCount,
      };

      return result;
    } catch (e, stack) {
      print("Error in getDashboardStats: $e");
      print(stack);
      rethrow;
    }
  }

  Future<List<dynamic>> getAllDoctors() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        })
        .where((data) => _isDoctor(data))
        .toList();
  }

  Future<List<dynamic>> getAllPatients() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        })
        .where((data) => _isPatient(data) && data['role'] != 'labOwner')
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAllAppointments() async {
    final snapshot = await _db
        .collection('appointments')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // Lab management methods for Admin
  Future<List<dynamic>> getAllLabs() async {
    final snapshot = await _db.collection('users').where('role', isEqualTo: 'labOwner').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      return data;
    }).toList();
  }

  Future<List<dynamic>> getLabsByStatus(String status) async {
    final snapshot = await _db.collection('users')
        .where('role', isEqualTo: 'labOwner')
        .where('status', isEqualTo: status.toLowerCase())
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> verifyLab(String uid, String status) async {
    final isApproved = status.toLowerCase() == 'approved';
    await _db.collection('users').doc(uid).update({
      'status': status.toLowerCase(),
      'verified': isApproved,
      'rejectionReason': FieldValue.delete(),
    });
    await _db.collection('lab_profiles').doc(uid).update({
      'status': status.toLowerCase(),
      'verified': isApproved,
      'rejectionReason': FieldValue.delete(),
    });
  }

  Future<void> rejectLab(String uid, String reason) async {
    await _db.collection('users').doc(uid).update({
      'status': 'rejected',
      'verified': false,
      'rejectionReason': reason,
    });
    await _db.collection('lab_profiles').doc(uid).update({
      'status': 'rejected',
      'verified': false,
      'rejectionReason': reason,
    });
  }

  Future<void> deleteUser(String uid, String role) async {
    // 1. Delete associated appointments where this user is patient or doctor
    final apptsPatient = await _db
        .collection('appointments')
        .where('patient_id', isEqualTo: uid)
        .get();
    for (var doc in apptsPatient.docs) {
      await doc.reference.delete();
    }

    final apptsDoctor = await _db
        .collection('appointments')
        .where('doctor_id', isEqualTo: uid)
        .get();
    for (var doc in apptsDoctor.docs) {
      await doc.reference.delete();
    }

    // 2. If patient, delete all reports under users/{uid}/reports subcollection
    if (role == 'patient') {
      final reports = await _db
          .collection('users')
          .doc(uid)
          .collection('reports')
          .get();
      for (var doc in reports.docs) {
        await doc.reference.delete();
      }
    }

    // 3. Delete the user document itself
    await _db.collection('users').doc(uid).delete();
    
    if (role == 'labOwner') {
      await _db.collection('lab_profiles').doc(uid).delete();
    }
  }
}
