import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = true; // Start with loading while checking initial auth state
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;

  void clearErrorMessage() {
    _errorMessage = null;
  }

  AuthProvider() {
    _authService.user.listen((firebaseUser) async {
      if (firebaseUser == null) {
        _user = null;
        _isLoading = false;
        notifyListeners();
      } else {
        _isLoading = true;
        notifyListeners();

        try {
          await firebaseUser.reload();
          final freshUser = FirebaseAuth.instance.currentUser;
          if (freshUser != null && !freshUser.emailVerified) {
            // Unverified user shouldn't be logged in
            _user = null;
            _isLoading = false;
            notifyListeners();
            return;
          }

          final doc = await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            data['uid'] = firebaseUser.uid;
            _user = UserModel.fromJson(data);
          } else {
            // New user authenticated but document doesn't exist yet
            _user = UserModel(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              name: firebaseUser.displayName ?? 'New User',
              role: null,
              profileCompleted: false,
            );
          }
        } catch (e) {
          _user = null;
        }

        _isLoading = false;
        notifyListeners();
      }
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String getFirebaseAuthErrorMessage(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'The email address is already in use by another account.';
        case 'weak-password':
          return 'The password is too weak. Please use a stronger password.';
        case 'invalid-email':
          return 'The email address is badly formatted.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'user-not-found':
          return 'No user found for that email address.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'too-many-requests':
          return 'Too many login attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network unavailable. Please check your connection.';
        case 'email-not-verified':
          return 'Please verify your email address before logging in.';
        default:
          return e.message ?? 'Authentication failed.';
      }
    }
    return e.toString();
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _user = await _authService.signUp(
        email: email,
        password: password,
        name: name,
      );
      final success = _user != null;
      // Force user state to null since email is not verified yet
      _user = null;
      _setLoading(false);
      return success;
    } catch (e) {
      _errorMessage = getFirebaseAuthErrorMessage(e);
      _user = null;
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _user = await _authService.signIn(email, password);
      _setLoading(false);
      return _user != null;
    } catch (e) {
      _errorMessage = getFirebaseAuthErrorMessage(e);
      _user = null;
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _user = await _authService.signInWithGoogle();
      _setLoading(false);
      return _user != null;
    } catch (e) {
      _errorMessage = getFirebaseAuthErrorMessage(e);
      _user = null;
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = getFirebaseAuthErrorMessage(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> completePatientProfile({
    required String name,
    required String phone,
    required String age,
    required String gender,
  }) async {
    _setLoading(true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final uid = currentUser.uid;
        final photoUrl = currentUser.photoURL ?? '';
        final userData = {
          'uid': uid,
          'name': name,
          'email': currentUser.email ?? '',
          'phone': phone,
          'age': age,
          'gender': gender,
          'role': 'patient',
          'profileCompleted': true,
          'createdAt': FieldValue.serverTimestamp(),
          'photoUrl': photoUrl,
          'status': 'active',
        };
        await FirebaseFirestore.instance.collection('users').doc(uid).set(userData);
        _user = UserModel.fromJson(userData);
        _setLoading(false);
        return true;
      }
    } catch (e) {
      // error handled in UI
    }
    _setLoading(false);
    return false;
  }

  Future<bool> completeDoctorProfile({
    required String name,
    required String phone,
    required String registrationNumber,
    required String qualification,
    required String department,
    required String specialization,
    required String hospital,
    required String experience,
    required List<String> languages,
    required double consultationFee,
    String? clinicName,
    String? clinicAddress,
    String? googleMapsUrl,
  }) async {
    _setLoading(true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final uid = currentUser.uid;
        final photoUrl = currentUser.photoURL ?? '';
        final defaultAvailability = DoctorAvailability.defaultVal();
        
        final userData = {
          'uid': uid,
          'name': name,
          'email': currentUser.email ?? '',
          'phone': phone,
          'role': 'doctor',
          'qualification': qualification,
          'department': department,
          'specialization': specialization,
          'registrationNumber': registrationNumber,
          'license': registrationNumber,
          'hospital': hospital,
          'experience': experience,
          'languages': languages,
          'consultationFee': consultationFee,
          'clinicName': clinicName,
          'clinicAddress': clinicAddress,
          'googleMapsUrl': googleMapsUrl,
          'onlineStatus': true,
          'availability': defaultAvailability.toJson(),
          'verified': false,
          'status': 'pending',
          'profileCompleted': true,
          'createdAt': FieldValue.serverTimestamp(),
          'photoUrl': photoUrl,
        };
        await FirebaseFirestore.instance.collection('users').doc(uid).set(userData);
        _user = UserModel.fromJson(userData);
        _setLoading(false);
        return true;
      }
    } catch (e) {
      // Error handled in UI
    }
    _setLoading(false);
    return false;
  }

  Future<bool> reapplyAsDoctor() async {
    _setLoading(true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final uid = currentUser.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'profileCompleted': false,
          'status': 'pending',
          'rejectionReason': FieldValue.delete(),
        });
        // Re-fetch user document to sync state
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          data['uid'] = uid;
          _user = UserModel.fromJson(data);
        }
        _setLoading(false);
        return true;
      }
    } catch (e) {
      // error
    }
    _setLoading(false);
    return false;
  }

  Future<bool> completeLabOwnerProfile({
    required String name,
    required String phone,
    required String labName,
    required String address,
    required String location,
    required String website,
    required String openingTime,
    required String closingTime,
    required bool homeCollection,
    required bool emergencyTesting,
  }) async {
    _setLoading(true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final uid = currentUser.uid;
        final photoUrl = currentUser.photoURL ?? '';
        final userData = {
          'uid': uid,
          'name': name,
          'email': currentUser.email ?? '',
          'phone': phone,
          'phoneNumber': phone,
          'role': 'labOwner',
          'status': 'pending',
          'verified': false,
          'profileCompleted': true,
          'createdAt': FieldValue.serverTimestamp(),
          'photoUrl': photoUrl,
        };

        final labProfileData = {
          'labId': uid,
          'labName': labName,
          'ownerName': name,
          'phone': phone,
          'email': currentUser.email ?? '',
          'address': address,
          'location': location,
          'website': website,
          'openingTime': openingTime,
          'closingTime': closingTime,
          'homeCollection': homeCollection,
          'emergencyTesting': emergencyTesting,
          'status': 'pending',
          'verified': false,
          'createdAt': FieldValue.serverTimestamp(),
          'services': {}, // Default empty services map
        };

        final batch = FirebaseFirestore.instance.batch();
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final profileRef = FirebaseFirestore.instance.collection('lab_profiles').doc(uid);

        batch.set(userRef, userData);
        batch.set(profileRef, labProfileData);
        await batch.commit();

        _user = UserModel.fromJson(userData);
        _setLoading(false);
        return true;
      }
    } catch (e) {
      // error handled in UI
    }
    _setLoading(false);
    return false;
  }

  Future<bool> reapplyAsLabOwner() async {
    _setLoading(true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final uid = currentUser.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'profileCompleted': false,
          'status': 'pending',
          'rejectionReason': FieldValue.delete(),
        });
        await FirebaseFirestore.instance.collection('lab_profiles').doc(uid).update({
          'status': 'pending',
        });
        // Re-fetch user
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          data['uid'] = uid;
          _user = UserModel.fromJson(data);
        }
        _setLoading(false);
        return true;
      }
    } catch (e) {
      // error
    }
    _setLoading(false);
    return false;
  }

  Future<void> refreshUser() async {
    _setLoading(true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          data['uid'] = currentUser.uid;
          _user = UserModel.fromJson(data);
        }
      }
    } catch (e) {
      // error
    }
    _setLoading(false);
  }
}
