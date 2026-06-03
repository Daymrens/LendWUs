import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../data/models/user.dart';
import '../data/repositories/user_repository.dart';
import '../core/firebase/firebase_service.dart';

final userRepositoryProvider = Provider((ref) => UserRepository());

final currentUserProvider = ChangeNotifierProvider<CurrentUserNotifier>((ref) {
  return CurrentUserNotifier(ref);
});

class CurrentUserNotifier extends ChangeNotifier {
  final Ref ref;
  User? _user;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get state => _user;

  CurrentUserNotifier(this.ref) {
    _initAuthListener();
  }

  void _initAuthListener() {
    FirebaseService.auth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser != null) {
        final repo = ref.read(userRepositoryProvider);
        _user = await repo.getUserById(firebaseUser.uid);
        
        // Failsafe: Create user document if it doesn't exist (e.g. first time Google login)
        if (_user == null && firebaseUser.email != null) {
          final isFirstAdmin = firebaseUser.email == 'act.drapor@gmail.com';
          final newUser = User(
            id: firebaseUser.uid,
            username: firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
            email: firebaseUser.email!,
            role: isFirstAdmin ? UserRole.admin : UserRole.member,
            createdAt: DateTime.now(),
          );
          await repo.createUserDoc(newUser);
          _user = newUser;
        }
      } else {
        _user = null;
      }
      notifyListeners();
    });
  }

  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final firebase_auth.AuthCredential credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseService.auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    final repo = ref.read(userRepositoryProvider);
    final user = await repo.login(email, password);

    if (user != null) {
      _user = user;
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await FirebaseService.auth.signOut();
    _user = null;
    notifyListeners();
  }

  bool get isAdmin => _user?.role == UserRole.admin || _user?.email == 'act.drapor@gmail.com';
  bool get isMember => _user?.role == UserRole.member;
  String? get memberId => _user?.memberId;
}
