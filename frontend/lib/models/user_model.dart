enum UserRole { patient, doctor, admin, labOwner }

class DoctorAvailability {
  final List<String> workingDays;
  final String startTime;
  final String endTime;
  final int consultationDuration;
  final int bufferTime;
  final String breakTimeStart;
  final String breakTimeEnd;

  DoctorAvailability({
    required this.workingDays,
    required this.startTime,
    required this.endTime,
    required this.consultationDuration,
    required this.bufferTime,
    required this.breakTimeStart,
    required this.breakTimeEnd,
  });

  factory DoctorAvailability.fromJson(Map<String, dynamic> json) {
    return DoctorAvailability(
      workingDays: List<String>.from(json['workingDays'] ?? []),
      startTime: json['startTime'] ?? "09:00",
      endTime: json['endTime'] ?? "17:00",
      consultationDuration: json['consultationDuration'] ?? 20,
      bufferTime: json['bufferTime'] ?? 10,
      breakTimeStart: json['breakTimeStart'] ?? "13:00",
      breakTimeEnd: json['breakTimeEnd'] ?? "14:00",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workingDays': workingDays,
      'startTime': startTime,
      'endTime': endTime,
      'consultationDuration': consultationDuration,
      'bufferTime': bufferTime,
      'breakTimeStart': breakTimeStart,
      'breakTimeEnd': breakTimeEnd,
    };
  }

  factory DoctorAvailability.defaultVal() {
    return DoctorAvailability(
      workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
      startTime: "09:00",
      endTime: "17:00",
      consultationDuration: 20,
      bufferTime: 10,
      breakTimeStart: "13:00",
      breakTimeEnd: "14:00",
    );
  }
}

class UserModel {
  final String uid;
  final String email;
  final String name;
  final UserRole? role;
  final String? phoneNumber;
  final String? profileImageUrl;
  final String status; // active, pending, verified, rejected, etc.
  final bool verified;
  final bool profileCompleted;
  final String? rejectionReason;
  
  // Doctor properties
  final String? qualification;
  final String? department;
  final String? specialization;
  final List<String>? languages;
  final double? consultationFee;
  final bool? onlineStatus;
  final DoctorAvailability? availability;

  // Patient properties
  final String? age;
  final String? gender;
  final String? bloodGroup;
  final String? address;
  final String? emergencyContact;
  final String? allergies;
  final String? chronicDiseases;
  final String? currentMedicines;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.role,
    this.phoneNumber,
    this.profileImageUrl,
    this.status = 'active',
    this.verified = false,
    this.profileCompleted = true,
    this.rejectionReason,
    this.qualification,
    this.department,
    this.specialization,
    this.languages,
    this.consultationFee,
    this.onlineStatus,
    this.availability,
    this.age,
    this.gender,
    this.bloodGroup,
    this.address,
    this.emergencyContact,
    this.allergies,
    this.chronicDiseases,
    this.currentMedicines,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    UserRole? mappedRole;
    if (json['role'] != null) {
      mappedRole = UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => UserRole.patient,
      );
    }

    List<String>? parsedLanguages;
    if (json['languages'] != null) {
      parsedLanguages = List<String>.from(json['languages']);
    }

    DoctorAvailability? parsedAvailability;
    if (json['availability'] != null) {
      parsedAvailability = DoctorAvailability.fromJson(Map<String, dynamic>.from(json['availability']));
    }

    double? fee;
    if (json['consultationFee'] != null) {
      fee = (json['consultationFee'] as num).toDouble();
    }

    bool? parsedOnline;
    if (json['onlineStatus'] != null) {
      if (json['onlineStatus'] is bool) {
        parsedOnline = json['onlineStatus'];
      } else {
        parsedOnline = json['onlineStatus'].toString().toLowerCase() == 'online';
      }
    }

    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: mappedRole,
      phoneNumber: json['phoneNumber'] ?? json['phone'],
      profileImageUrl: json['profileImageUrl'] ?? json['photoUrl'],
      status: json['status'] ?? 'active',
      verified: json['verified'] ?? (json['status']?.toString().toLowerCase() == 'verified'),
      profileCompleted: json['profileCompleted'] ?? true,
      rejectionReason: json['rejectionReason'],
      qualification: json['qualification'],
      department: json['department'] ?? json['category'],
      specialization: json['specialization'],
      languages: parsedLanguages,
      consultationFee: fee,
      onlineStatus: parsedOnline,
      availability: parsedAvailability,
      age: json['age']?.toString(),
      gender: json['gender']?.toString(),
      bloodGroup: json['bloodGroup']?.toString(),
      address: json['address']?.toString(),
      emergencyContact: json['emergencyContact']?.toString(),
      allergies: json['allergies']?.toString(),
      chronicDiseases: json['chronicDiseases']?.toString(),
      currentMedicines: json['currentMedicines']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role?.toString().split('.').last,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'status': status,
      'verified': verified,
      'profileCompleted': profileCompleted,
      'rejectionReason': rejectionReason,
      'qualification': qualification,
      'department': department,
      'specialization': specialization,
      'languages': languages,
      'consultationFee': consultationFee,
      'onlineStatus': onlineStatus,
      'availability': availability?.toJson(),
      'age': age,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'address': address,
      'emergencyContact': emergencyContact,
      'allergies': allergies,
      'chronicDiseases': chronicDiseases,
      'currentMedicines': currentMedicines,
    };
  }
}
