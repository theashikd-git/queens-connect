// lib/demo/demo_data.dart
// All fake data - no Firebase needed

class DemoUser {
  final String id;
  final String name;
  final String email;
  final String role;

  const DemoUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  bool get isManager => role == 'manager';
}

class DemoHospital {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String city;

  const DemoHospital({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.city,
  });
}

class DemoVisit {
  final String id;
  final String userId;
  final String userName;
  final String manualHospitalName;
  final String doctorName;
  final String purpose;
  final String? notes;
  final double gpsLatitude;
  final double gpsLongitude;
  final double gpsAccuracy;
  final DateTime timestamp;
  final double? distanceFromHospital;
  final String status;
  final bool isMockGps;
  final double? hospitalLatitude;
  final double? hospitalLongitude;

  const DemoVisit({
    required this.id,
    required this.userId,
    required this.userName,
    required this.manualHospitalName,
    required this.doctorName,
    required this.purpose,
    this.notes,
    required this.gpsLatitude,
    required this.gpsLongitude,
    required this.gpsAccuracy,
    required this.timestamp,
    this.distanceFromHospital,
    required this.status,
    this.isMockGps = false,
    this.hospitalLatitude,
    this.hospitalLongitude,
  });
}

class DemoData {
  // ── Demo Login Accounts ──────────────────────────────────────────────
  static const List<Map<String, String>> loginAccounts = [
    {
      'email': 'manager@demo.com',
      'password': '123456',
      'role': 'manager',
      'name': 'Ahmed Rahman',
    },
    {
      'email': 'user@demo.com',
      'password': '123456',
      'role': 'user',
      'name': 'Rahim Uddin',
    },
  ];

  // ── Demo Hospitals ───────────────────────────────────────────────────
  static const List<DemoHospital> hospitals = [
    DemoHospital(
      id: 'h1',
      name: 'Dhaka Medical College Hospital',
      latitude: 23.7261,
      longitude: 90.3945,
      city: 'Dhaka',
    ),
    DemoHospital(
      id: 'h2',
      name: 'Square Hospitals Ltd',
      latitude: 23.7516,
      longitude: 90.3747,
      city: 'Dhaka',
    ),
    DemoHospital(
      id: 'h3',
      name: 'United Hospital',
      latitude: 23.7977,
      longitude: 90.4163,
      city: 'Dhaka',
    ),
    DemoHospital(
      id: 'h4',
      name: 'Apollo Hospitals Dhaka',
      latitude: 23.7800,
      longitude: 90.4010,
      city: 'Dhaka',
    ),
    DemoHospital(
      id: 'h5',
      name: 'BIRDEM General Hospital',
      latitude: 23.7383,
      longitude: 90.3873,
      city: 'Dhaka',
    ),
  ];

  // ── Demo Visits ──────────────────────────────────────────────────────
  static final List<DemoVisit> visits = [
    DemoVisit(
      id: 'v1',
      userId: 'u1',
      userName: 'Rahim Uddin',
      manualHospitalName: 'Dhaka Medical College Hospital',
      doctorName: 'Dr. Karim Hassan',
      purpose: 'Product Introduction',
      notes: 'Introduced new cardiac medication. Doctor showed interest.',
      gpsLatitude: 23.7265,
      gpsLongitude: 90.3948,
      gpsAccuracy: 8.5,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      distanceFromHospital: 45.0,
      status: 'valid',
      hospitalLatitude: 23.7261,
      hospitalLongitude: 90.3945,
    ),
    DemoVisit(
      id: 'v2',
      userId: 'u2',
      userName: 'Salma Begum',
      manualHospitalName: 'Square Hospitals Ltd',
      doctorName: 'Dr. Nasreen Akter',
      purpose: 'Follow-up Visit',
      notes: 'Doctor requested more samples for next week.',
      gpsLatitude: 23.7690,
      gpsLongitude: 90.3820,
      gpsAccuracy: 15.2,
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      distanceFromHospital: 185.0,
      status: 'warning',
      hospitalLatitude: 23.7516,
      hospitalLongitude: 90.3747,
    ),
    DemoVisit(
      id: 'v3',
      userId: 'u3',
      userName: 'Kamal Hossain',
      manualHospitalName: 'United Hospital',
      doctorName: 'Dr. Farhan Ahmed',
      purpose: 'Sample Delivery',
      gpsLatitude: 23.8500,
      gpsLongitude: 90.5000,
      gpsAccuracy: 22.0,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      distanceFromHospital: 890.0,
      status: 'suspicious',
      isMockGps: true,
      hospitalLatitude: 23.7977,
      hospitalLongitude: 90.4163,
    ),
    DemoVisit(
      id: 'v4',
      userId: 'u1',
      userName: 'Rahim Uddin',
      manualHospitalName: 'Apollo Hospitals Dhaka',
      doctorName: 'Dr. Sultana Razia',
      purpose: 'Scientific Meeting',
      notes: 'Attended CME session with 12 doctors.',
      gpsLatitude: 23.7803,
      gpsLongitude: 90.4015,
      gpsAccuracy: 6.0,
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      distanceFromHospital: 38.0,
      status: 'valid',
      hospitalLatitude: 23.7800,
      hospitalLongitude: 90.4010,
    ),
    DemoVisit(
      id: 'v5',
      userId: 'u2',
      userName: 'Salma Begum',
      manualHospitalName: 'BIRDEM General Hospital',
      doctorName: 'Dr. Rezaul Karim',
      purpose: 'Order Collection',
      gpsLatitude: 23.7390,
      gpsLongitude: 90.3880,
      gpsAccuracy: 12.0,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      distanceFromHospital: 88.0,
      status: 'valid',
      hospitalLatitude: 23.7383,
      hospitalLongitude: 90.3873,
    ),
  ];
}