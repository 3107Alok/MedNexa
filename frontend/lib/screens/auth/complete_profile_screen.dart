import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/models/user_model.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  UserRole? _selectedRole;
  
  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Patient fields
  final _ageController = TextEditingController();
  String _selectedGender = 'Male';

  // Doctor fields
  final _regNumController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _experienceController = TextEditingController();
  final _feeController = TextEditingController(text: '500');
  final _languagesController = TextEditingController(text: 'English, Hindi');
  final _clinicNameController = TextEditingController();
  final _clinicAddressController = TextEditingController();
  final _googleMapsUrlController = TextEditingController();
  String _selectedCategory = 'General Physician';
  String _selectedSpecialty = 'General Practice';

  // Lab fields
  final _labNameController = TextEditingController();
  final _labOwnerNameController = TextEditingController();
  final _labAddressController = TextEditingController();
  final _labLocationController = TextEditingController();
  final _labWebsiteController = TextEditingController();
  final _labPhoneController = TextEditingController();
  String _openingTime = '09:00 AM';
  String _closingTime = '06:00 PM';
  bool _homeCollection = false;
  bool _emergencyTesting = false;

  final List<String> _categories = [
    'General Physician',
    'Dentist',
    'Dermatologist',
    'Physiotherapist',
    'Psychologist',
    'Dietician',
    'Pediatrician'
  ];

  final List<String> _specialties = [
    'General Practice',
    'Cardiology',
    'Neurology',
    'Orthopedics',
    'Nephrology',
    'Oncology',
    'Endocrinology',
    'ENT',
    'Gastroenterology',
    'Pulmonology',
    'Urology'
  ];

  @override
  void initState() {
    super.initState();
    // Prefill name from auth provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null && authProvider.user!.name.isNotEmpty && authProvider.user!.name != 'New User') {
        _nameController.text = authProvider.user!.name;
        _labOwnerNameController.text = authProvider.user!.name;
      } else {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
          _nameController.text = currentUser.displayName!;
          _labOwnerNameController.text = currentUser.displayName!;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _regNumController.dispose();
    _qualificationController.dispose();
    _hospitalController.dispose();
    _experienceController.dispose();
    _feeController.dispose();
    _languagesController.dispose();
    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    _googleMapsUrlController.dispose();
    
    _labNameController.dispose();
    _labOwnerNameController.dispose();
    _labAddressController.dispose();
    _labLocationController.dispose();
    _labWebsiteController.dispose();
    _labPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool success = false;
    if (_selectedRole == UserRole.patient) {
      success = await authProvider.completePatientProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        age: _ageController.text.trim(),
        gender: _selectedGender,
      );
    } else if (_selectedRole == UserRole.doctor) {
      final languagesList = _languagesController.text.isNotEmpty
          ? _languagesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : ['English', 'Hindi'];
      final feeDouble = double.tryParse(_feeController.text) ?? 500.0;

      success = await authProvider.completeDoctorProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        registrationNumber: _regNumController.text.trim(),
        qualification: _qualificationController.text.trim(),
        department: _selectedCategory,
        specialization: _selectedSpecialty,
        hospital: _hospitalController.text.trim(),
        experience: _experienceController.text.trim(),
        languages: languagesList,
        consultationFee: feeDouble,
        clinicName: _clinicNameController.text.trim(),
        clinicAddress: _clinicAddressController.text.trim(),
        googleMapsUrl: _googleMapsUrlController.text.trim(),
      );
    } else if (_selectedRole == UserRole.labOwner) {
      success = await authProvider.completeLabOwnerProfile(
        name: _labOwnerNameController.text.trim(),
        phone: _labPhoneController.text.trim(),
        labName: _labNameController.text.trim(),
        address: _labAddressController.text.trim(),
        location: _labLocationController.text.trim(),
        website: _labWebsiteController.text.trim(),
        openingTime: _openingTime,
        closingTime: _closingTime,
        homeCollection: _homeCollection,
        emergencyTesting: _emergencyTesting,
      );
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save profile. Please try again.')),
      );
    }
  }

  Widget _buildPremiumRoleSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.grey[100]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildRoleSelectorButton(
              role: UserRole.patient,
              label: 'Patient',
              icon: Icons.personal_injury_outlined,
              theme: theme,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildRoleSelectorButton(
              role: UserRole.doctor,
              label: 'Doctor',
              icon: Icons.medical_services_outlined,
              theme: theme,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildRoleSelectorButton(
              role: UserRole.labOwner,
              label: 'Lab',
              icon: Icons.science_outlined,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelectorButton({
    required UserRole role,
    required String label,
    required IconData icon,
    required ThemeData theme,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSpecificFields(ThemeData theme) {
    if (_selectedRole == UserRole.patient) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _ageController,
            decoration: const InputDecoration(
              labelText: 'Age',
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (_selectedRole == UserRole.patient) {
                return v!.isEmpty ? 'Enter age' : null;
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              prefixIcon: Icon(Icons.people_outline),
            ),
            items: ['Male', 'Female', 'Other']
                .map((gender) => DropdownMenuItem(
                      value: gender,
                      child: Text(gender),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedGender = v!),
          ),
        ],
      );
    } else if (_selectedRole == UserRole.doctor) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _regNumController,
            decoration: const InputDecoration(
              labelText: 'Medical Registration Number',
              prefixIcon: Icon(Icons.assignment_outlined),
            ),
            validator: (v) {
              if (_selectedRole == UserRole.doctor) {
                return v!.isEmpty ? 'Required' : null;
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _qualificationController,
            decoration: const InputDecoration(
              labelText: 'Qualification (e.g. MBBS, MD)',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            validator: (v) {
              if (_selectedRole == UserRole.doctor) {
                return v!.isEmpty ? 'Required' : null;
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Department / Category',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: _categories
                .map((cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedCategory = v!),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedSpecialty,
            decoration: const InputDecoration(
              labelText: 'Specialization',
              prefixIcon: Icon(Icons.health_and_safety_outlined),
            ),
            items: _specialties
                .map((spec) => DropdownMenuItem(
                      value: spec,
                      child: Text(spec),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedSpecialty = v!),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _hospitalController,
            decoration: const InputDecoration(
              labelText: 'Hospital / Clinic Name',
              prefixIcon: Icon(Icons.local_hospital_outlined),
            ),
            validator: (v) {
              if (_selectedRole == UserRole.doctor) {
                return v!.isEmpty ? 'Required' : null;
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _experienceController,
            decoration: const InputDecoration(
              labelText: 'Years of Experience',
              prefixIcon: Icon(Icons.work_history_outlined),
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (_selectedRole == UserRole.doctor) {
                return v!.isEmpty ? 'Required' : null;
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _feeController,
            decoration: const InputDecoration(
              labelText: 'Consultation Fee (INR)',
              prefixIcon: Icon(Icons.currency_rupee_outlined),
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (_selectedRole == UserRole.doctor) {
                return v!.isEmpty ? 'Required' : null;
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _languagesController,
            decoration: const InputDecoration(
              labelText: 'Languages Spoken (comma separated)',
              prefixIcon: Icon(Icons.language_outlined),
            ),
            validator: (v) {
              if (_selectedRole == UserRole.doctor) {
                return v!.isEmpty ? 'Required' : null;
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _clinicNameController,
            decoration: const InputDecoration(
              labelText: 'Clinic / Hospital Name',
              prefixIcon: Icon(Icons.local_hospital_outlined),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _clinicAddressController,
            decoration: const InputDecoration(
              labelText: 'Clinic Address',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _googleMapsUrlController,
            decoration: const InputDecoration(
              labelText: 'Google Maps URL (Optional)',
              prefixIcon: Icon(Icons.map_outlined),
            ),
          ),
        ],
      );
    } else if (_selectedRole == UserRole.labOwner) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _labNameController,
            decoration: const InputDecoration(
              labelText: 'Lab Name',
              prefixIcon: Icon(Icons.science_outlined),
            ),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _labOwnerNameController,
            decoration: const InputDecoration(
              labelText: 'Owner Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _labPhoneController,
            decoration: const InputDecoration(
              labelText: 'Lab Contact Number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _labAddressController,
            decoration: const InputDecoration(
              labelText: 'Lab Physical Address',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            maxLines: 2,
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _labLocationController,
            decoration: const InputDecoration(
              labelText: 'Google Maps Location Link',
              prefixIcon: Icon(Icons.map_outlined),
              helperText: 'Must be a valid maps link (maps.google.com, goo.gl or maps.app.goo.gl)',
              helperMaxLines: 2,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (!v.contains('google.com') && !v.contains('goo.gl') && !v.contains('http')) {
                return 'Please enter a valid Google Maps link';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _labWebsiteController,
            decoration: const InputDecoration(
              labelText: 'Website / Hyperlink (Optional)',
              prefixIcon: Icon(Icons.link_outlined),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _openingTime,
                  decoration: const InputDecoration(
                    labelText: 'Opens At',
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  items: ['07:00 AM', '08:00 AM', '09:00 AM', '10:00 AM']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _openingTime = v!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _closingTime,
                  decoration: const InputDecoration(
                    labelText: 'Closes At',
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  items: ['05:00 PM', '06:00 PM', '07:00 PM', '08:00 PM', '09:00 PM']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _closingTime = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: Text('Home Collection Available', style: GoogleFonts.outfit(fontSize: 15)),
            value: _homeCollection,
            onChanged: (v) => setState(() => _homeCollection = v),
          ),
          SwitchListTile(
            title: Text('Emergency Testing Support', style: GoogleFonts.outfit(fontSize: 15)),
            value: _emergencyTesting,
            onChanged: (v) => setState(() => _emergencyTesting = v),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final email = authProvider.user?.email ?? FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) || _selectedRole != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_selectedRole != null) {
                    setState(() {
                      _selectedRole = null;
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
              )
            : null,
        title: const Text('Complete Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.signOut(),
          ),
        ],
      ),
      body: authProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Welcome to MediNexa',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please choose your role to set up your account.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      if (_selectedRole == null) ...[
                        _buildRoleSelectionCards(theme),
                      ] else ...[
                        _buildPremiumRoleSelector(theme),
                        const SizedBox(height: 24),
                        
                        if (_selectedRole != UserRole.labOwner) ...[
                          // Shared Fields for Patient & Doctor
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => v!.isEmpty ? 'Enter full name' : null,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            initialValue: email,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined),
                              helperText: 'Email is linked to your sign-in account and cannot be changed here.',
                              helperMaxLines: 2,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (v) => v!.isEmpty ? 'Enter phone number' : null,
                          ),
                          const SizedBox(height: 20),
                        ],
                        
                        // Dynamic fields
                        _buildRoleSpecificFields(theme),
                        
                        const SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: _submitProfile,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            _selectedRole == UserRole.patient ? 'Get Started' : 'Submit for Verification',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildRoleSelectionCards(ThemeData theme) {
    return Column(
      children: [
        _buildRoleCard(
          theme: theme,
          role: UserRole.patient,
          title: 'Patient',
          description: 'Book appointments, consult AI & view reports',
          icon: Icons.personal_injury_outlined,
          color: Colors.blue,
        ),
        const SizedBox(height: 14),
        _buildRoleCard(
          theme: theme,
          role: UserRole.doctor,
          title: 'Doctor',
          description: 'Manage schedules, consult AI & patients',
          icon: Icons.medical_services_outlined,
          color: Colors.teal,
        ),
        const SizedBox(height: 14),
        _buildRoleCard(
          theme: theme,
          role: UserRole.labOwner,
          title: 'Lab Owner',
          description: 'Manage laboratory bookings & upload reports',
          icon: Icons.science_outlined,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required ThemeData theme,
    required UserRole role,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.5),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedRole = role),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class DoctorPendingScreen extends StatelessWidget {
  const DoctorPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isRejected = user?.status.toLowerCase() == 'rejected';
    final reason = user?.rejectionReason;

    return Scaffold(
      appBar: AppBar(
        title: Text(isRejected ? 'Verification Rejected' : 'Account Pending'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => authProvider.refreshUser(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.signOut(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRejected ? Icons.gpp_bad_rounded : Icons.pending_actions,
                size: 100,
                color: isRejected ? Colors.red : Colors.orange,
              ),
              const SizedBox(height: 24),
              Text(
                isRejected ? 'Verification Rejected' : 'Verification Pending',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isRejected ? Colors.red[800] : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isRejected
                    ? "Your medical profile has been reviewed and rejected by the admin. Please verify your details or contact support."
                    : "Your account has been submitted for verification. You'll be able to access doctor features after admin approval.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              if (isRejected && reason != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Reason: $reason',
                          style: GoogleFonts.outfit(
                            color: Colors.red[900],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 48),
              if (isRejected) ...[
                ElevatedButton.icon(
                  onPressed: () => authProvider.reapplyAsDoctor(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.edit_note),
                  label: Text(
                    'Edit Details / Re-submit',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                onPressed: () => authProvider.signOut(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.logout),
                label: Text(
                  'Logout',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LabPendingScreen extends StatelessWidget {
  const LabPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isRejected = user?.status.toLowerCase() == 'rejected';
    final reason = user?.rejectionReason;

    return Scaffold(
      appBar: AppBar(
        title: Text(isRejected ? 'Lab Verification Rejected' : 'Lab Account Pending'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => authProvider.refreshUser(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.signOut(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRejected ? Icons.gpp_bad_rounded : Icons.pending_actions_rounded,
                size: 100,
                color: isRejected ? Colors.red : Colors.purple,
              ),
              const SizedBox(height: 24),
              Text(
                isRejected ? 'Lab Verification Rejected' : 'Lab Verification Pending',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isRejected ? Colors.red[800] : Colors.purple[800],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isRejected
                    ? "Your lab profile has been reviewed and rejected by the admin. Please verify your details or contact support."
                    : "Your lab registration has been submitted for verification. You'll be able to access lab owner features after admin approval.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              if (isRejected && reason != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Reason: $reason',
                          style: GoogleFonts.outfit(
                            color: Colors.red[900],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 48),
              if (isRejected) ...[
                ElevatedButton.icon(
                  onPressed: () => authProvider.reapplyAsLabOwner(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.edit_note),
                  label: Text(
                    'Edit Details / Re-submit',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                onPressed: () => authProvider.signOut(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.logout),
                label: Text(
                  'Logout',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
