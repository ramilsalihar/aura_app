import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<bool>((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.authStateChanges.map((u) => u != null);
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.currentUserStream;
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Updated GoogleSignIn initialization
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Stream<UserModel?> get currentUserStream {
    return authStateChanges.asyncMap((user) async {
      if (user == null) return null;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.exists ? UserModel.fromMap(doc.data()!, doc.id) : null;
    });
  }

  Future<UserCredential?> signInWithGoogle() async {
  try {
    // Return if already signed in
    if (_auth.currentUser != null) {
      debugPrint('User already signed in: ${_auth.currentUser!.email}');
      return null; // or return a dummy credential if needed
    }

    // Start the sign-in process
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    await _createUserIfNotExists(userCredential.user!);
    return userCredential;
  } catch (e) {
    debugPrint('Google Sign-In Error: $e');
    return null;
  }
}



  Future<void> _createUserIfNotExists(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    await docRef.set({
      'id': user.uid,
      'displayName': user.displayName ?? 'Anonymous',
      'email': user.email ?? '',
      'photoURL': user.photoURL,
      'currentWeekAura': 0,
      'totalAura': 0,
      'lastRouletteDate': null,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
