import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/user.dart';
import '../data/models/member.dart';
import '../core/firebase/firebase_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/notification_watcher.dart';
import '../core/services/all_paid_watcher.dart';
import '../core/services/security_service.dart';
import '../core/utils/member_id_generator.dart';
import 'members_provider.dart';
import 'settings_provider.dart';

final currentUserProvider = ChangeNotifierProvider<CurrentUserNotifier>((ref) {
  return CurrentUserNotifier(ref);
});

class CurrentUserNotifier extends ChangeNotifier {
  final Ref ref;
  User? _user;
  bool _isRecognized = false;
  bool _needsSetup = false;
  bool _isLoading = false;
  bool _resolveInProgress = false;
  bool _biometricRequired = false;
  bool _biometricChecked = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  String? _deactivationReason;
  StreamSubscription<DocumentSnapshot>? _memberDocSub;
  StreamSubscription<firebase_auth.User?>? _authSub;
  StreamSubscription<String>? _tokenSub;
  final NotificationWatcher _notificationWatcher = NotificationWatcher();
  final AllPaidWatcher _allPaidWatcher = AllPaidWatcher();
  bool _disposed = false;

  User? get state => _user;
  bool get isRecognized => _isRecognized;
  bool get needsSetup => _needsSetup;
  bool get isLoading => _isLoading;
  bool get isFirebaseUser => FirebaseService.auth.currentUser != null;
  bool get isBiometricRequired => _biometricRequired;
  String? get deactivationReason => _deactivationReason;

  CurrentUserNotifier(this.ref) {
    _initAuthListener();
  }

  List<String> get _adminEmails {
    final settings = ref.read(settingsProvider);
    return settings.asData?.value.adminEmails ?? [];
  }

  List<String> get _treasurerEmails {
    final settings = ref.read(settingsProvider);
    return settings.asData?.value.treasurerEmails ?? [];
  }

  void _initAuthListener() {
    _authSub = FirebaseService.auth.authStateChanges().listen(
      _onAuthChanged,
      onError: (Object e, StackTrace st) {
        debugPrint('authStateChanges error: $e');
      },
    );
  }

  Future<void> _onAuthChanged(firebase_auth.User? firebaseUser) async {
    if (_disposed) return;

    // Guard against concurrent calls (e.g. auth listener + explicit call after sign-in)
    if (_resolveInProgress) return;
    _resolveInProgress = true;

    _stopMemberWatcher();

    _isLoading = true;
    if (!_disposed) notifyListeners();

    try {
      if (firebaseUser != null) {
        await ref.read(settingsProvider.future);

        final repo = ref.read(userRepositoryProvider);
        _user = await repo.getUserById(firebaseUser.uid);

        if (!firebaseUser.emailVerified && _user == null) {
          _user = null;
          _isRecognized = false;
          return;
        }

        if (_user != null && _treasurerEmails.contains(firebaseUser.email)) {
          if (!_user!.isTreasurer) {
            _user!.isTreasurer = true;
            await repo.updateUserDoc(_user!);
          }
        }

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
            final memberRepo = ref.read(memberRepositoryProvider);
            final linkedMember = await memberRepo.findMemberByLinkedEmail(firebaseUser.email!);
            final isTreasurer = _treasurerEmails.contains(firebaseUser.email);
            if (linkedMember != null) {
              final newUser = User(
                id: firebaseUser.uid,
                username: firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
                email: firebaseUser.email!,
                role: UserRole.member,
                memberId: linkedMember.id,
                isTreasurer: isTreasurer,
                photoUrl: firebaseUser.photoURL,
                createdAt: DateTime.now(),
              );
              await repo.createUserDoc(newUser);
              _user = newUser;
            } else if (isTreasurer) {
              final newUser = User(
                id: firebaseUser.uid,
                username: firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
                email: firebaseUser.email!,
                role: UserRole.member,
                isTreasurer: true,
                photoUrl: firebaseUser.photoURL,
                createdAt: DateTime.now(),
              );
              await repo.createUserDoc(newUser);
              _user = newUser;
            }
          }
        }

        if (_user != null && _user!.memberId != null && _user!.role == UserRole.member) {
          final member = await ref.read(memberRepositoryProvider).getMemberById(_user!.memberId!);
          if (member == null || !member.isActive) {
            _user = null;
            _isRecognized = false;
            _needsSetup = false;
          } else {
            _isRecognized = true;
            final missingName = member.name.isEmpty;
            final missingPhone = member.contactNumber == null || member.contactNumber!.isEmpty;
            _needsSetup = missingName || missingPhone;
            _user!.displayId = member.memberId;
            _startMemberWatcher(_user!.memberId!);
          }
        } else if (_user != null) {
          // Admin or treasurer-only → recognized.
          // Member without memberId and not treasurer → NOT recognized
          // (matches web resolveUser: a user doc with role==member but no
          // valid memberId returns recognized: false).
          final isAdminUser = _user!.role == UserRole.admin || _adminEmails.contains(_user!.email);
          final isTreasurerOnly = _user!.role == UserRole.member &&
              _user!.isTreasurer &&
              _user!.memberId == null;
          _isRecognized = isAdminUser || isTreasurerOnly;
          if (_isRecognized) _needsSetup = false;
        } else {
          _isRecognized = false;
        }

        if (_user != null) {
          await _registerFcmToken();
          _notificationWatcher.start(_user!.id!);
          _allPaidWatcher.start();
          if (!_biometricChecked) {
            _biometricChecked = true;
            try {
              _biometricRequired = await SecurityService.isBiometricEnabled();
            } catch (_) {
              _biometricRequired = false;
            }
          }
        } else {
          _notificationWatcher.dispose();
          _allPaidWatcher.dispose();
        }
      } else {
        _user = null;
        _isRecognized = false;
        _needsSetup = false;
        _biometricChecked = false;
        _biometricRequired = false;
      }
    } catch (e) {
      debugPrint('_onAuthChanged error: $e');
      debugPrintStack(label: '_onAuthChanged');
      // Don't null out _user/_isRecognized on transient errors —
      // they may hold a valid session from a prior auth state change.
      // A subsequent auth state change will retry the resolve.
    } finally {
      _resolveInProgress = false;
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _startMemberWatcher(String memberId) {
    _stopMemberWatcher();
    _memberDocSub = FirebaseService.firestore
        .collection('members')
        .doc(memberId)
        .snapshots()
        .listen((snapshot) {
      if (_disposed) return;
      if (!snapshot.exists) {
        _handleDeactivation('Your account has been removed. Contact an admin.');
      } else {
        final data = snapshot.data() as Map<String, dynamic>;
        final isActive = data['isActive'] == true || data['isActive'] == 1;
        if (!isActive) {
          _handleDeactivation('Your account has been deactivated. Contact an admin.');
        } else {
          // Re-check needsSetup whenever member doc changes
          final member = Member.fromMap({...data, 'id': snapshot.id});
          final missingName = member.name.isEmpty;
          final missingPhone = member.contactNumber == null || member.contactNumber!.isEmpty;
          _needsSetup = missingName || missingPhone;
          if (!_disposed) notifyListeners();
        }
      }
    }, onError: (Object e, StackTrace st) {
      debugPrint('member watcher error: $e');
    });
  }

  void _handleDeactivation(String reason) {
    if (_disposed) return;
    _stopMemberWatcher();
    _deactivationReason = reason;
    _user = null;
    _isRecognized = false;
    notifyListeners();
  }

  void _stopMemberWatcher() {
    _memberDocSub?.cancel();
    _memberDocSub = null;
  }

  void clearDeactivationReason() {
    _deactivationReason = null;
  }

  void clearBiometricRequirement() {
    _biometricRequired = false;
    if (!_disposed) notifyListeners();
  }

  void resetBiometricCheck() {
    _biometricChecked = false;
    _biometricRequired = false;
  }

  Future<void> _registerFcmToken() async {
    if (_user?.id == null) return;
    final repo = ref.read(userRepositoryProvider);
    final token = await NotificationService.getFcmToken();
    if (token != null) {
      await repo.updateFcmToken(_user!.id!, token);
    }
    await _tokenSub?.cancel();
    _tokenSub = NotificationService.onTokenRefresh.listen((newToken) {
      if (_disposed) return;
      repo.updateFcmToken(_user!.id!, newToken);
    }, onError: (Object e, StackTrace st) {
      debugPrint('onTokenRefresh error: $e');
    });
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        if (!_disposed) notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final firebase_auth.AuthCredential credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseService.auth.signInWithCredential(credential);

      // Kick off auth resolution synchronously so routing is ready immediately.
      // The _resolveInProgress guard prevents a concurrent call from the
      // authStateChanges listener (queued as a microtask).
      if (FirebaseService.auth.currentUser != null) {
        await _onAuthChanged(FirebaseService.auth.currentUser);
      }

      _isLoading = false;
      if (!_disposed) notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      if (!_disposed) notifyListeners();
      debugPrint('Google Sign-In Error: $e');
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    final repo = ref.read(userRepositoryProvider);
    try {
      final user = await repo.login(email, password);
      if (user != null) {
        _deactivationReason = null;
        // The auth state listener will set _user and _isRecognized.
        // Force a refresh in case the auth state already matched the cached user.
        if (FirebaseService.auth.currentUser != null) {
          await _onAuthChanged(FirebaseService.auth.currentUser);
        }
        _isLoading = false;
        if (!_disposed) notifyListeners();
        return true;
      }
      _isLoading = false;
      if (!_disposed) notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      if (!_disposed) notifyListeners();
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _stopMemberWatcher();
    _deactivationReason = null;
    _isLoading = true;
    notifyListeners();
    await _googleSignIn.signOut();
    await FirebaseService.auth.signOut();
    _user = null;
    _isRecognized = false;
    _isLoading = false;
    _biometricChecked = false;
    _biometricRequired = false;
    if (!_disposed) notifyListeners();
  }

  Future<bool> joinWithGroupCode(String code, {String? displayName, int headsCount = 1, String? contactNumber}) async {
    final settings = ref.read(settingsProvider);
    final expectedCode = settings.asData?.value.groupCode ?? 'LENDWUS';
    if (code.toUpperCase() != expectedCode.toUpperCase()) return false;

    final firebaseUser = FirebaseService.auth.currentUser;
    if (firebaseUser == null || firebaseUser.email == null) return false;

    try {
      final firestore = FirebaseService.firestore;

      final name = displayName ?? firebaseUser.displayName ?? firebaseUser.email!.split('@')[0];
      final totalRequired = headsCount * 500.0;

      String? memberDocId;
      String? customMemberId;
      await firestore.runTransaction((tx) async {
        customMemberId = await MemberIdGenerator.generateNextMemberId(firestore);
        
        final member = Member(
          name: name,
          linkedEmail: firebaseUser.email,
          headsCount: headsCount,
          amountPerHead: 500.0,
          totalRequired: totalRequired,
          joinedAt: DateTime.now(),
          isActive: true,
          memberId: customMemberId,
          contactNumber: contactNumber,
        );
        final memberDocRef = firestore.collection('members').doc();
        memberDocId = memberDocRef.id;
        
        tx.set(memberDocRef, member.toMap());

        final newUser = User(
          id: firebaseUser.uid,
          username: name,
          email: firebaseUser.email!,
          role: UserRole.member,
          memberId: memberDocId,
          displayId: customMemberId,
          photoUrl: firebaseUser.photoURL,
          createdAt: DateTime.now(),
        );
        tx.set(firestore.collection('users').doc(firebaseUser.uid), newUser.toMap());
      });

      if (memberDocId != null && customMemberId != null) {
        _deactivationReason = null;
        _user = User(
          id: firebaseUser.uid,
          username: name,
          email: firebaseUser.email!,
          role: UserRole.member,
          memberId: memberDocId,
          displayId: customMemberId,
          photoUrl: firebaseUser.photoURL,
          createdAt: DateTime.now(),
        );
        _isRecognized = true;
        _startMemberWatcher(memberDocId!);
        if (!_disposed) notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Join Group Code Error: $e');
      return false;
    }
  }

  Future<bool> completeProfile({required String name, String? contactNumber}) async {
    if (_user?.memberId == null) return false;
    try {
      final member = await ref.read(memberRepositoryProvider).getMemberById(_user!.memberId!);
      if (member == null) return false;

      member.name = name;
      member.contactNumber = contactNumber;
      await ref.read(memberRepositoryProvider).updateMember(member);

      _user!.username = name;
      _needsSetup = false;
      if (!_disposed) notifyListeners();
      return true;
    } catch (e) {
      debugPrint('completeProfile error: $e');
      return false;
    }
  }

  bool get isAdmin {
    final user = _user;
    if (user == null) return false;
    if (user.role == UserRole.admin) return true;
    return _adminEmails.contains(user.email);
  }

  bool get isMember => _user?.role == UserRole.member;
  bool get isTreasurer {
    final user = _user;
    if (user == null) return false;
    if (user.isTreasurer) return true;
    return _treasurerEmails.contains(user.email);
  }
  String? get memberId => _user?.memberId;

  @override
  void dispose() {
    _disposed = true;
    _stopMemberWatcher();
    _notificationWatcher.dispose();
    _allPaidWatcher.dispose();
    _tokenSub?.cancel();
    _tokenSub = null;
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
  }
}
