import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'firebase_firestore_provider.g.dart';

@Riverpod(keepAlive: true)
FirebaseFirestore firebaseFirestore(Ref ref) {
  return FirebaseFirestore.instance;
}
