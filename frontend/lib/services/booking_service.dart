import 'package:cloud_firestore/cloud_firestore.dart';

class BookingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<dynamic>> getVerifiedDoctors() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        })
        .where((data) {
          final roleStr = data['role']?.toString().toLowerCase();
          final statusStr = data['status']?.toString().toLowerCase() ?? '';
          
          bool isDoc = false;
          if (roleStr == 'doctor') {
            isDoc = true;
          } else if (roleStr != 'patient' && roleStr != 'admin') {
            isDoc = data.containsKey('qualification') ||
                data.containsKey('specialization') ||
                data.containsKey('license') ||
                data.containsKey('registrationNumber') ||
                data.containsKey('hospital') ||
                data.containsKey('consultationFee') ||
                data.containsKey('availability');
          }
          
          final isVerified = data['verified'] == true || statusStr == 'verified';
          final isProfileCompleted = data['profileCompleted'] ?? true;
          
          return isDoc && isVerified && isProfileCompleted;
        })
        .toList();
  }

  Future<void> bookAppointment(Map<String, dynamic> bookingData) async {
    await _db.collection('appointments').add(bookingData);

    final String doctorId = bookingData['doctor_id'] ?? '';
    final String patientName = bookingData['patient_name'] ?? 'A patient';
    if (doctorId.isNotEmpty) {
      await _db.collection('notifications').add({
        'userId': doctorId,
        'title': 'New Appointment Booking 📅',
        'body': '$patientName has booked an appointment with you for ${bookingData['date']} at ${bookingData['time_slot']}.',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }
  }

  Future<void> bookLabTest(Map<String, dynamic> labBookingData) async {
    await _db.collection('lab_bookings').add(labBookingData);
  }

  Future<List<Map<String, dynamic>>> getUserLabBookings(String uid) async {
    final snapshot = await _db
        .collection('lab_bookings')
        .where('uid', isEqualTo: uid)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getUserAppointments(String uid) async {
    final snapshot = await _db
        .collection('appointments')
        .where('patient_id', isEqualTo: uid)
        .get();
    
    final doctorSnapshot = await _db
        .collection('appointments')
        .where('doctor_id', isEqualTo: uid)
        .get();

    final all = [...snapshot.docs, ...doctorSnapshot.docs];
    return all.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> getDoctorAppointmentsStream(String doctorId) {
    return _db
        .collection('appointments')
        .where('doctor_id', isEqualTo: doctorId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Stream<List<Map<String, dynamic>>> getPatientAppointmentsStream(String patientId) {
    return _db
        .collection('appointments')
        .where('patient_id', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    await _db.collection('appointments').doc(appointmentId).update({
      'status': status.toLowerCase(),
    });

    if (status.toLowerCase() == 'approved') {
      try {
        final doc = await _db.collection('appointments').doc(appointmentId).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final patientId = data['patient_id'] ?? '';
          final doctorName = data['doctor_name'] ?? 'Doctor';
          if (patientId.isNotEmpty) {
            await _db.collection('notifications').add({
              'userId': patientId,
              'title': 'Appointment Accepted 📅',
              'body': 'Your appointment with $doctorName is accepted.',
              'createdAt': FieldValue.serverTimestamp(),
              'isRead': false,
            });
          }
        }
      } catch (e) {
        // ignore
      }
    }
  }

  Future<Map<String, dynamic>?> getPatientById(String patientId) async {
    final doc = await _db.collection('users').doc(patientId).get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      data['uid'] = doc.id;
      return data;
    }
    return null;
  }

  Future<bool> verifyDoctorAccessToPatient(String doctorId, String patientId) async {
    final snapshot = await _db
        .collection('appointments')
        .where('doctor_id', isEqualTo: doctorId)
        .where('patient_id', isEqualTo: patientId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getPatientReports(String patientId) async {
    return [];
  }

  Future<List<Map<String, dynamic>>> getPreviousVisitsWithDoctor(String doctorId, String patientId) async {
    final snapshot = await _db
        .collection('appointments')
        .where('doctor_id', isEqualTo: doctorId)
        .where('patient_id', isEqualTo: patientId)
        .where('status', isEqualTo: 'completed')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<List<String>> getBookedSlotsForDoctor(String doctorId, String date) async {
    final snapshot = await _db
        .collection('appointments')
        .where('doctor_id', isEqualTo: doctorId)
        .where('date', isEqualTo: date)
        .get();
    
    return snapshot.docs
        .map((doc) => doc.data()['time_slot']?.toString())
        .where((slot) => slot != null)
        .cast<String>()
        .toList();
  }
}
