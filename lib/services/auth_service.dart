import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:twain/models/twain_user.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Stream<User?> get userChanges => _auth.authStateChanges();

  Stream<TwainUser?> twainUserStream() {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return TwainUser(
        id: user.uid,
        email: data['email'],
        displayName: data['displayName'],
        avatarUrl: data['avatarUrl'],
        pairId: data['pairId'],
        fcmToken: data['fcmToken'],
        deviceId: data['deviceId'],
        status: data['status'],
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        updatedAt: (data['updatedAt'] as Timestamp).toDate(),
        preferences: data['preferences'],
        metaData: data['metaData'],
      );
    });
  }

  Future<TwainUser?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user;
    if (user == null) return null;

    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'email': user.email,
        'displayName': user.displayName,
        'avatarUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.update({'updatedAt': FieldValue.serverTimestamp()});
    }

    return _getUserFromFirestore(user.uid);
  }

  Future<TwainUser?> _getUserFromFirestore(String? uid) async {
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    return TwainUser(
      id: uid,
      email: data['email'],
      displayName: data['displayName'],
      avatarUrl: data['avatarUrl'],
      pairId: data['pairId'],
      fcmToken: data['fcmToken'],
      deviceId: data['deviceId'],
      status: data['status'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      preferences: data['preferences'],
      metaData: data['metaData'],
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }
}
