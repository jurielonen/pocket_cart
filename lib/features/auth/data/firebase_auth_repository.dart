import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/auth_repository.dart';

part 'firebase_auth_repository.g.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  @override
  Future<void> signIn({required String email, required String password}) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signUp({required String email, required String password}) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> resetPassword({required String email}) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }
}

@riverpod
AuthRepository authRepository(Ref ref) {
  return FirebaseAuthRepository(FirebaseAuth.instance);
}

@riverpod
Stream<User?> authStateChanges(Ref ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges();
}
