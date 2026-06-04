import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../data/models/user.dart';
import '../data/models/member.dart';
import '../data/repositories/member_repository.dart';
import '../core/firebase/firebase_service.dart';
import '../core/services/notification_service.dart';
import 'members_provider.dart';

final currentUserProvider = ChangeNotifierProvider<CurrentUserNotifier>((ref) {
  return CurrentUserNotifier(ref);
});

class CurrentUserNotifier extends ChangeNotifier {
  final Ref ref;
  User? _user;
  bool _isRecognized = false;
  bool _isLoading = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get state => _user;
  bool get isRecognized => _isRecognized;
  bool get isLoading => _isLoading;
  bool get isFirebaseUser => FirebaseService.auth.currentUser != null;

  CurrentUserNotifier(this.ref) {
    _initAuthListener();
  }

  static const _adminEmails = ['act.drapor@gmail.com', 'daymrens@gmail.com'];

  void _initAuthListener() {
    FirebaseService.auth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser != null) {
        final repo = ref.read(userRepositoryProvider);
        _user = await repo.getUserById(firebaseUser.uid);

        if (_user == null && firebaseUser.email != null) {
          if (_adminEmails.contains(firebaseUser.email)) {
            final newUser = User(
              id: firebaseUser.uid,
              username: firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
              email: firebaseUser.email!,
              role: UserRole.admin,
              photoUrl: firebaseUser.photoURL,
              createdAt: DateTime.now(),
            );
            await repo.createUserDoc(newUser);
            _user = newUser;
          } else {
            final memberRepo = MemberRepository();
            final linkedMember = await memberRepo.findMemberByLinkedEmail(firebaseUser.email!);
            if (linkedMember != null) {
              final newUser = User(
                id: firebaseUser.uid,
                username: firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
                email: firebaseUser.email!,
                role: UserRole.member,
                memberId: linkedMember.id,
                photoUrl: firebaseUser.photoURL,
                createdAt: DateTime.now(),
              );
              await repo.createUserDoc(newUser);
              _user = newUser;
            }
          }
        }

        if (_user != null) {
          _isRecognized = true;
          _registerFcmToken();
        } else {
          _isRecognized = false;
          _user = null;
        }
      } else {
        _user = null;
        _isRecognized = false;
      }
      notifyListeners();
    });
  }

  Future<void> _registerFcmToken() async {
    if (_user?.id == null) return;
    final repo = ref.read(userRepositoryProvider);
    final token = await NotificationService.getFcmToken();
    if (token != null) {
      await repo.updateFcmToken(_user!.id!, token);
    }
    NotificationService.onTokenRefresh.listen((newToken) {
      repo.updateFcmToken(_user!.id!, newToken);
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
    _isLoading = true;
    notifyListeners();

    final repo = ref.read(userRepositoryProvider);
    final user = await repo.login(email, password);

    if (user != null) {
      await Future.delayed(const Duration(milliseconds: 800));
      _user = user;
      _isRecognized = true;
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));
    await _googleSignIn.signOut();
    await FirebaseService.auth.signOut();
    _user = null;
    _isRecognized = false;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> joinWithGroupCode(String code) async {
    if (code.toUpperCase() != 'LENDWUS') return false;

    final firebaseUser = FirebaseService.auth.currentUser;
    if (firebaseUser == null || firebaseUser.email == null) return false;

    try {
      final memberRepo = MemberRepository();
      final userRepo = ref.read(userRepositoryProvider);

      final memberId = await memberRepo.addMember(Member(
        name: firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
        linkedEmail: firebaseUser.email,
        headsCount: 1,
        amountPerHead: 150.0,
        totalRequired: 150.0,
        joinedAt: DateTime.now(),
        isActive: true,
      ));

      final newUser = User(
        id: firebaseUser.uid,
        username: firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
        email: firebaseUser.email!,
        role: UserRole.member,
        memberId: memberId,
        photoUrl: firebaseUser.photoURL,
        createdAt: DateTime.now(),
      );
      
      await userRepo.createUserDoc(newUser);
      
      _user = newUser;
      _isRecognized = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Join Group Code Error: $e');
      return false;
    }
  }

  bool get isAdmin => _user?.role == UserRole.admin || (_user?.email != null && _adminEmails.contains(_user!.email));
  bool get isMember => _user?.role == UserRole.member;
  String? get memberId => _user?.memberId;
}
