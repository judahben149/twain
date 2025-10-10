import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:twain/models/twain_user.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Stream<User?> get userChanges => _auth.authStateChanges();

  Stream<TwainUser?> twainUserStream() {
    return _auth.authStateChanges().asyncMap((user) async {
      if(user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if(!doc.exists) return null;

      final data = doc.data()!;

      return TwainUser(
          id: user.uid,
          email: data['email'],
          displayName: data['displayName'],
          createdAt: DateTime.parse(data['createdAt']),
          updatedAt: DateTime.parse(data['updatedAt'])
      )
    })
  }
}