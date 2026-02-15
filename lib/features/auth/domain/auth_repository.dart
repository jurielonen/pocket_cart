import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> authStateChanges();

  Future<void> signIn({
    required String email,
    required String password,
  });

  Future<void> signUp({
    required String email,
    required String password,
  });

  Future<void> resetPassword({
    required String email,
  });

  Future<void> signOut();
}
