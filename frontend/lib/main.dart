import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/theme/theme_notifier.dart';
import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/screens/auth/login_screen.dart';
import 'package:frontend/screens/auth/signup_screen.dart';
import 'package:frontend/screens/auth/complete_profile_screen.dart';
import 'package:frontend/screens/patient/patient_dashboard.dart';
import 'package:frontend/screens/doctor/doctor_dashboard.dart';
import 'package:frontend/screens/patient/chatbot_screen.dart';
import 'package:frontend/screens/patient/appointment_booking_screen.dart';
import 'package:frontend/screens/patient/medicine_reminder_screen.dart';
import 'package:frontend/screens/patient/prescription_reader_screen.dart';
import 'package:frontend/screens/patient/medical_history_screen.dart';
import 'package:frontend/screens/patient/lab_reports_screen.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/screens/admin/admin_dashboard.dart';


import 'package:frontend/screens/lab/lab_dashboard.dart';

import 'package:frontend/screens/patient/lab_booking_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
      ],
      child: const MediNexaApp(),
    ),
  );
}

class MediNexaApp extends StatelessWidget {
  const MediNexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      title: 'MediNexa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/complete-profile': (context) => const CompleteProfileScreen(),
        '/patient-home': (context) => const PatientDashboard(),
        '/doctor-home': (context) => const DoctorDashboard(),
        '/admin-home': (context) => const AdminDashboard(),
        '/lab-dashboard': (context) => const LabDashboard(),
        '/chatbot': (context) => const ChatbotScreen(),
        '/book-appointment': (context) => const AppointmentBookingScreen(),
        '/book-lab': (context) => const LabBookingScreen(),
        '/medicine-reminders': (context) => const MedicineReminderScreen(),
        '/ocr-reader': (context) => const PrescriptionReaderScreen(),
        '/medical-history': (context) => const MedicalHistoryScreen(),
        '/lab-reports': (context) => const LabReportsScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (authProvider.isAuthenticated) {
      final user = authProvider.user;
      if (user != null) {
        if (!user.profileCompleted) {
          return const CompleteProfileScreen();
        }
        
        final role = user.role;
        if (role == UserRole.patient) return const PatientDashboard();
        if (role == UserRole.doctor) {
          if (user.verified) {
            return const DoctorDashboard();
          } else {
            return const DoctorPendingScreen();
          }
        }
        if (role == UserRole.labOwner) {
          if (user.status == 'approved' || user.verified) {
            return const LabDashboard();
          } else {
            return const LabPendingScreen();
          }
        }
        if (role == UserRole.admin) return const AdminDashboard();
      }
    }

    return const LoginScreen();
  }
}
