import 'package:hive/hive.dart';

part 'app_user.g.dart';

@HiveType(typeId: 9)
class AppUser extends HiveObject {
  @HiveField(0)
  final String uid; // Firebase UID

  @HiveField(1)
  final String fullName;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final String phoneNumber; // Optional phone number

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final DateTime? lastLoginAt;

  @HiveField(6)
  final bool isRegistered; // True after first-time registration

  AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    this.phoneNumber = '', // Optional - empty string if not provided
    required this.createdAt,
    this.lastLoginAt,
    this.isRegistered = false,
  });

  AppUser copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isRegistered,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isRegistered: isRegistered ?? this.isRegistered,
    );
  }
}

