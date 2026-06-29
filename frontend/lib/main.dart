import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/theme/glassmorphism.dart';
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
import 'package:frontend/screens/notifications_screen.dart';

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
      child: const MedVerseApp(),
    ),
  );
}

class MedVerseApp extends StatelessWidget {
  const MedVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      title: 'MedVerse',
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
        '/notifications': (context) => const NotificationsScreen(),
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
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.getBackgroundGradient(Theme.of(context).brightness == Brightness.dark),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.health_and_safety_outlined, size: 80, color: Color(0xFF9E84FF)),
                const SizedBox(height: 32),
                GlassLoadingIndicator(isDarkMode: Theme.of(context).brightness == Brightness.dark),
              ],
            ),
          ),
        ),
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
