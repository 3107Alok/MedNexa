class LabServiceDetail {
  final double price;
  final int reportTime; // in hours
  final bool enabled;

  LabServiceDetail({
    required this.price,
    required this.reportTime,
    required this.enabled,
  });

  factory LabServiceDetail.fromJson(Map<String, dynamic> json) {
    return LabServiceDetail(
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      reportTime: (json['reportTime'] as num?)?.toInt() ?? 24,
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'price': price,
      'reportTime': reportTime,
      'enabled': enabled,
    };
  }
}

class LabProfileModel {
  final String labId;
  final String labName;
  final String ownerName;
  final String phone;
  final String email;
  final String address;
  final String location;
  final String website;
  final String openingTime;
  final String closingTime;
  final bool homeCollection;
  final bool emergencyTesting;
  final Map<String, LabServiceDetail> services;

  LabProfileModel({
    required this.labId,
    required this.labName,
    required this.ownerName,
    required this.phone,
    required this.email,
    required this.address,
    required this.location,
    required this.website,
    required this.openingTime,
    required this.closingTime,
    required this.homeCollection,
    required this.emergencyTesting,
    required this.services,
  });

  factory LabProfileModel.fromJson(Map<String, dynamic> json) {
    final servicesMap = <String, LabServiceDetail>{};
    if (json['services'] != null) {
      (json['services'] as Map<String, dynamic>).forEach((key, val) {
        servicesMap[key] = LabServiceDetail.fromJson(Map<String, dynamic>.from(val));
      });
    }

    return LabProfileModel(
      labId: json['labId'] ?? '',
      labName: json['labName'] ?? '',
      ownerName: json['ownerName'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      address: json['address'] ?? '',
      location: json['location'] ?? '',
      website: json['website'] ?? '',
      openingTime: json['openingTime'] ?? '09:00 AM',
      closingTime: json['closingTime'] ?? '06:00 PM',
      homeCollection: json['homeCollection'] as bool? ?? false,
      emergencyTesting: json['emergencyTesting'] as bool? ?? false,
      services: servicesMap,
    );
  }

  Map<String, dynamic> toJson() {
    final servicesJson = <String, dynamic>{};
    services.forEach((key, val) {
      servicesJson[key] = val.toJson();
    });

    return {
      'labId': labId,
      'labName': labName,
      'ownerName': ownerName,
      'phone': phone,
      'email': email,
      'address': address,
      'location': location,
      'website': website,
      'openingTime': openingTime,
      'closingTime': closingTime,
      'homeCollection': homeCollection,
      'emergencyTesting': emergencyTesting,
      'services': servicesJson,
    };
  }
}
