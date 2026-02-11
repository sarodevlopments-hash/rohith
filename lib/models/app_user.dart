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

  @HiveField(7)
  final String? role; // 'owner', 'buyer', 'seller', or null (default buyer)

  AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    this.phoneNumber = '', // Optional - empty string if not provided
    required this.createdAt,
    this.lastLoginAt,
    this.isRegistered = false,
    this.role,
  });

  AppUser copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isRegistered,
    String? role,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isRegistered: isRegistered ?? this.isRegistered,
      role: role ?? this.role,
    );
  }

  bool get isOwner => role == 'owner';
  bool get isSeller => role == 'seller' || role == null; // Default to seller if no role
  bool get isBuyer => role == 'buyer' || role == null; // Default to buyer if no role
}

