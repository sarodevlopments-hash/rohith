class UserModel {
  final String uid;
  final String? fssaiLicense;

  UserModel({
    required this.uid,
    this.fssaiLicense,
  });

  UserModel copyWith({String? fssaiLicense}) {
    return UserModel(
      uid: uid,
      fssaiLicense: fssaiLicense ?? this.fssaiLicense,
    );
  }
}
