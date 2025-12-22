import '../models/user_model.dart';

class AuthService {
  static UserModel currentUser =
      UserModel(uid: 'demo-user'); // simulate logged in user

  static Future<void> updateFssai(String fssai) async {
    currentUser = currentUser.copyWith(fssaiLicense: fssai);
  }
}
