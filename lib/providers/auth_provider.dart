import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class SavedAccount {
  final String email;
  final String displayName;
  final String? photoUrl;
  final String uid;
  final UserRole role;
  final bool isGoogle;
  SavedAccount({
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.uid,
    required this.role,
    this.isGoogle = false,
  });
  Map<String, dynamic> toJson() => {
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'uid': uid,
    'role': role.name,
    'isGoogle': isGoogle,
  };
  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    photoUrl: json['photoUrl'] as String?,
    uid: json['uid'] as String,
    role: UserRole.values.firstWhere((r) => r.name == json['role']),
    isGoogle: json['isGoogle'] as bool? ?? false,
  );
}

final currentUserProvider = ChangeNotifierProvider<CurrentUserNotifier>((ref) {
  return CurrentUserNotifier(ref);
});

class LoginResult {
  final bool success;
  final String? error;
  final UserRole? role;
  LoginResult({required this.success, this.error, this.role});
}

class CurrentUserNotifier extends ChangeNotifier {
  final Ref ref;
  User? _user;
  bool _isRecognized = false;
  bool _isLoading = false;
  bool _resolveInProgress = false;
  Completer<void>? _resolveCompleter;
  bool _biometricRequired = false;
  bool _biometricChecked = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  String? _deactivationReason;
  StreamSubscription<DocumentSnapshot>? _memberDocSub;
  StreamSubscription<firebase_auth.User?>? _authSub;
  StreamSubscription<String>? _tokenSub;
  final NotificationWatcher _notificationWatcher = NotificationWatcher();
  final AllPaidWatcher _allPaidWatcher = AllPaidWatcher();
  static const _savedAccountsKey = 'saved_accounts';
  List<SavedAccount> _savedAccounts = [];
  bool _accountsLoaded = false;
  bool _disposed = false;

  static const _hardcodedAdminEmails = [
    'daymrens@gmail.com',
  ];

  void _recomputeRecognized() {
    _isRecognized = _user?.role == UserRole.admin ||
        (_user?.memberId != null && _user?.role == UserRole.member) ||
        (_user?.role == UserRole.member && _user!.isTreasurer && _user!.memberId == null);
  }

  List<SavedAccount> get savedAccounts => _accountsLoaded ? List.unmodifiable(_savedAccounts) : [];

  bool get hasSavedAccounts => _accountsLoaded && _savedAccounts.isNotEmpty;

  Future<void> loadSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedAccountsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _savedAccounts = list.map((e) => SavedAccount.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      _savedAccounts = [];
    }
    _accountsLoaded = true;
    if (!_disposed) notifyListeners();
  }

  Future<void> _saveCurrentAccount() async {
    if (_user == null || !_isRecognized) return;
    final firebaseUser = FirebaseService.auth.currentUser;
    if (firebaseUser == null) return;
    final existingIndex = _savedAccounts.indexWhere((a) => a.email == _user!.email);
    final account = SavedAccount(
      email: _user!.email,
      displayName: _user!.username.isNotEmpty ? _user!.username : _user!.email,
      photoUrl: _user!.photoUrl ?? firebaseUser.photoURL,
      uid: _user!.id!,
      role: _user!.role,
      isGoogle: firebaseUser.providerData.any((p) => p.providerId == 'google.com'),
    );
    if (existingIndex >= 0) {
      _savedAccounts[existingIndex] = account;
    } else {
      _savedAccounts.insert(0, account);
    }
    await _persistSavedAccounts();
  }

  Future<void> _persistSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_savedAccounts.map((a) => a.toJson()).toList());
      await prefs.setString(_savedAccountsKey, raw);
    } catch (_) {}
  }

  Future<void> removeSavedAccount(String email) async {
    _savedAccounts.removeWhere((a) => a.email == email);
    await _persistSavedAccounts();
    if (!_disposed) notifyListeners();
  }

  Future<LoginResult> signInWithSavedAccount(SavedAccount account) async {
    if (!account.isGoogle) {
      return LoginResult(success: false, error: 'Please enter your password');
    }
    _isLoading = true;
    if (!_disposed) notifyListeners();
    try {
      // Try silent sign-in first (seamless, no UI)
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null && googleUser.email == account.email) {
        return await _finishGoogleSignIn(googleUser);
      }
    } catch (_) {}

    // Cached Google account didn't match — try with picker
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        return await _finishGoogleSignIn(googleUser);
      }
    } catch (e) {
      debugPrint('signInWithSavedAccount picker error: $e');
    }
    _isLoading = false;
    if (!_disposed) notifyListeners();
    return LoginResult(success: false, error: 'Could not auto sign in');
  }

  Future<LoginResult> _finishGoogleSignIn(GoogleSignInAccount googleUser) async {
    try {
      final googleAuth = await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseService.auth.signInWithCredential(credential);
      final fbUser = FirebaseService.auth.currentUser;
      if (fbUser != null) {
        await resolve(fbUser);
        _recomputeRecognized();
        await _saveCurrentAccount();
      }
      if (_user != null) return LoginResult(success: true, role: _user!.role);
    } catch (e) {
      debugPrint('_finishGoogleSignIn error: $e');
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
    return LoginResult(success: false, error: 'Account not recognized');
  }

  User? get state => _user;
  bool get isRecognized => _isRecognized;
  bool get needsSetup => false;
  bool get isLoading => _isLoading;
  bool get isFirebaseUser => FirebaseService.auth.currentUser != null;
  bool get isBiometricRequired => _biometricRequired;
  String? get deactivationReason => _deactivationReason;

  CurrentUserNotifier(this.ref) {
    _initAuthListener();
    Future.microtask(() => loadSavedAccounts());
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

  /// Matches web resolveUser() exactly.
  Future<LoginResult> resolve(firebase_auth.User firebaseUser) async {
    // Idempotent: if already resolved for this user, skip
    if (_user != null && _user!.id == firebaseUser.uid) {
      return LoginResult(success: true, role: _user!.role);
    }
    try {
      final repo = ref.read(userRepositoryProvider);
      _user = await repo.getUserById(firebaseUser.uid);
      final email = firebaseUser.email ?? '';

      // ── No existing user doc → create one ──
      if (_user == null) {
        final isAdmin = _adminEmails.contains(email) || _hardcodedAdminEmails.contains(email);
        if (isAdmin) {
          final newUser = User(
            id: firebaseUser.uid,
            username: firebaseUser.displayName ?? email.split('@')[0],
            email: email,
            role: UserRole.admin,
            photoUrl: firebaseUser.photoURL,
            createdAt: DateTime.now(),
          );
          await repo.createUserDoc(newUser);
          _user = newUser;
          return LoginResult(success: true, role: UserRole.admin);
        }

        final isTreasurerEmail = _treasurerEmails.contains(email);
        final memberRepo = ref.read(memberRepositoryProvider);
        final linkedMember = await memberRepo.findMemberByLinkedEmail(email);
        if (linkedMember != null && linkedMember.isActive) {
          final newUser = User(
            id: firebaseUser.uid,
            username: firebaseUser.displayName ?? email.split('@')[0],
            email: email,
            role: UserRole.member,
            memberId: linkedMember.id,
            isTreasurer: isTreasurerEmail,
            photoUrl: firebaseUser.photoURL,
            createdAt: DateTime.now(),
          );
          await repo.createUserDoc(newUser);
          _user = newUser;
          return LoginResult(success: true, role: UserRole.member);
        }

        if (isTreasurerEmail) {
          final newUser = User(
            id: firebaseUser.uid,
            username: firebaseUser.displayName ?? email.split('@')[0],
            email: email,
            role: UserRole.member,
            isTreasurer: true,
            photoUrl: firebaseUser.photoURL,
            createdAt: DateTime.now(),
          );
          await repo.createUserDoc(newUser);
          _user = newUser;
          return LoginResult(success: true, role: UserRole.member);
        }

        // No user doc, not admin, no linked member → unrecognized
        _user = User(
          id: firebaseUser.uid,
          username: firebaseUser.displayName ?? email.split('@')[0],
          email: email,
          role: UserRole.member,
          photoUrl: firebaseUser.photoURL,
          createdAt: DateTime.now(),
        );
        return LoginResult(success: true, role: UserRole.member);
      }

      // ── Existing user doc ──
      final data = _user!;

      // Admin email upgrade: if email is in adminEmails but doc says otherwise
      if (data.role != UserRole.admin && (_adminEmails.contains(email) || _hardcodedAdminEmails.contains(email))) {
        data.role = UserRole.admin;
        data.memberId = null;
        await repo.updateUserDoc(data);
        return LoginResult(success: true, role: UserRole.admin);
      }

      // Treasurer flag upgrade
      if (data.role == UserRole.member && !data.isTreasurer) {
        final isTreasurerEmail = _treasurerEmails.contains(email);
        if (isTreasurerEmail) {
          data.isTreasurer = true;
          await repo.updateUserDoc(data);
          return LoginResult(success: true, role: UserRole.member);
        }
      }

      // Admin downgrade: role is admin but email not in any admin list → revert to member
      if (data.role == UserRole.admin) {
        final isAdminEmail = _adminEmails.contains(email) || _hardcodedAdminEmails.contains(email);
        if (isAdminEmail) {
          return LoginResult(success: true, role: UserRole.admin);
        }
        data.role = UserRole.member;
        final linked = await ref.read(memberRepositoryProvider).findMemberByLinkedEmail(email);
        if (linked != null && linked.isActive) {
          data.memberId = linked.id;
          data.displayId = linked.memberId;
        }
        await repo.updateUserDoc(data);
      }

      if (data.role != UserRole.member) {
        return LoginResult(success: false, error: 'Unknown account role.');
      }

      // ── Member user: validate/repair memberId ──
      String? resolvedMemberId = data.memberId;
      Member? resolvedMember;

      if (data.memberId == null) {
        // No stored memberId — try linkedEmail repair
        final linked = await ref.read(memberRepositoryProvider).findMemberByLinkedEmail(email);
        if (linked != null && linked.isActive) {
          resolvedMemberId = linked.id;
        }
      } else {
        // Has stored memberId — validate it
        final member = await ref.read(memberRepositoryProvider).getMemberById(data.memberId!);
        if (member != null && member.isActive) {
          resolvedMember = member;
        }
        if (resolvedMember == null) {
          // Stale memberId — try linkedEmail repair
          final linked = await ref.read(memberRepositoryProvider).findMemberByLinkedEmail(email);
          if (linked != null && linked.isActive) {
            resolvedMemberId = linked.id;
            // Fix the user doc so future logins work without the fallback
            await repo.updateUserMemberId(firebaseUser.uid, linked.id!);
          }
        }
      }

      if (resolvedMember != null || resolvedMemberId != null) {
        if (resolvedMember != null) {
          _user!.displayId = resolvedMember.memberId;
          return LoginResult(success: true, role: UserRole.member);
        }
        // resolvedMemberId was repaired from linkedEmail
        final member = await ref.read(memberRepositoryProvider).getMemberById(resolvedMemberId!);
        if (member != null && member.isActive) {
          _user!.displayId = member.memberId;
          _user!.memberId = member.id;
          return LoginResult(success: true, role: UserRole.member);
        }
        if (member != null && !member.isActive) {
          return LoginResult(success: false, error: 'Your account has been deactivated. Contact admin.');
        }
      }

      // Fallback: check if a member doc exists with this auth UID as its doc ID
      try {
        final uidMemberSnap = await FirebaseService.firestore.collection('members').doc(firebaseUser.uid).get();
        if (uidMemberSnap.exists) {
          final mData = uidMemberSnap.data()!;
          final isActive = (mData['active'] ?? mData['isActive']) != false;
          if (isActive) {
            // Create user doc linking to this member
            final newUser = User(
              id: firebaseUser.uid,
              username: firebaseUser.displayName ?? email.split('@')[0],
              email: email,
              role: UserRole.member,
              memberId: uidMemberSnap.id,
              photoUrl: firebaseUser.photoURL,
              createdAt: DateTime.now(),
            );
            await repo.createUserDoc(newUser);
            _user = newUser;
            return LoginResult(success: true, role: UserRole.member);
          }
        }
      } catch (e) {
        debugPrint('member-by-uid fallback error: $e');
      }

      // No valid member linkage found
      return LoginResult(success: false, error: 'No member profile linked. Contact admin.');
    } catch (e) {
      debugPrint('resolve error: $e');
      return LoginResult(success: false, error: 'Failed to load user data');
    }
  }

  Future<void> _onAuthChanged(firebase_auth.User? firebaseUser) async {
    if (_disposed) return;

    // Mutex: wait for any ongoing resolve to finish (web parity)
    while (_resolveInProgress) {
      final completer = _resolveCompleter;
      if (completer != null) {
        await completer.future;
      } else {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    _stopMemberWatcher();
    _resolveInProgress = true;
    _resolveCompleter = Completer<void>();

    try {
      if (firebaseUser != null) {
        await ref.read(settingsProvider.future);

        if (!firebaseUser.emailVerified && _user == null) {
          _user = null;
          _isRecognized = false;
          return;
        }

        final alreadyResolved = _user != null && _user!.id == firebaseUser.uid;

        if (!alreadyResolved) {
          // Only show loading when we actually need to resolve
          _isLoading = true;
          if (!_disposed) notifyListeners();

          final result = await resolve(firebaseUser);

          if (result.success) {
            final repo = ref.read(userRepositoryProvider);
            final freshUser = await repo.getUserById(firebaseUser.uid);
            if (freshUser != null) {
              _user = freshUser;
            }

            _recomputeRecognized();

            if (_isRecognized && _user!.memberId != null && _user!.role == UserRole.member) {
              final member = await ref.read(memberRepositoryProvider).getMemberById(_user!.memberId!);
              if (member == null || !member.isActive) {
                _user = null;
                _isRecognized = false;
              } else {
                _user!.displayId = member.memberId;
                _startMemberWatcher(_user!.memberId!);
              }
            }
          } else {
            _user = null;
            _isRecognized = false;
          }
        } else {
          _recomputeRecognized();
          if (_isRecognized && _user!.memberId != null && _user!.role == UserRole.member) {
            _startMemberWatcher(_user!.memberId!);
          }
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
        _biometricChecked = false;
        _biometricRequired = false;
      }
    } catch (e) {
      debugPrint('_onAuthChanged error: $e');
      debugPrintStack(label: '_onAuthChanged');
    } finally {
      _resolveInProgress = false;
      if (_isLoading) {
        _isLoading = false;
        if (!_disposed) notifyListeners();
      }
      _resolveCompleter?.complete();
      _resolveCompleter = null;
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

  Future<LoginResult> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        if (!_disposed) notifyListeners();
        return LoginResult(success: false, error: 'Google sign-in cancelled');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final firebase_auth.AuthCredential credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseService.auth.signInWithCredential(credential);

      // Resolve directly (web parity) instead of waiting for auth listener
      final fbUser = FirebaseService.auth.currentUser;
      if (fbUser != null) {
        await resolve(fbUser);
      } else {
        // Fallback: wait for auth listener
        while (_resolveInProgress) {
          final completer = _resolveCompleter;
          if (completer != null) {
            await completer.future;
          } else {
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }
      }

      _recomputeRecognized();
      await _saveCurrentAccount();
      _isLoading = false;
      if (!_disposed) notifyListeners();

      if (_user != null) {
        return LoginResult(success: true, role: _user!.role);
      }
      return LoginResult(success: false, error: 'Account not recognized. Contact admin.');
    } catch (e) {
      _isLoading = false;
      if (!_disposed) notifyListeners();
      debugPrint('Google Sign-In Error: $e');
      return LoginResult(success: false, error: e.toString());
    }
  }

  Future<LoginResult> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final repo = ref.read(userRepositoryProvider);
      final appUser = await repo.login(email, password);
      if (appUser != null) {
        _deactivationReason = null;
        final fbUser = FirebaseService.auth.currentUser;
        if (fbUser != null) {
          await resolve(fbUser);
          _recomputeRecognized();
          await _saveCurrentAccount();
        }
      }
      _isLoading = false;
      if (!_disposed) notifyListeners();

      if (_user != null) {
        return LoginResult(success: true, role: _user!.role);
      }
      return LoginResult(success: false, error: appUser != null ? 'Account not recognized. Contact admin.' : 'Invalid email or password');
    } catch (e) {
      _isLoading = false;
      if (!_disposed) notifyListeners();
      debugPrint('Login error: $e');
      return LoginResult(success: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    _stopMemberWatcher();
    _deactivationReason = null;
    _isLoading = true;
    notifyListeners();
    await FirebaseService.auth.signOut();
    // Keep Google session alive so signInSilently() works for saved accounts
    _user = null;
    _isRecognized = false;
    _isLoading = false;
    _biometricChecked = false;
    _biometricRequired = false;
    if (!_disposed) notifyListeners();
  }

  Future<LoginResult> joinWithGroupCode(String code, {String? displayName, int headsCount = 1, String? contactNumber}) async {
    final settings = ref.read(settingsProvider);
    final expectedCode = settings.asData?.value.groupCode ?? 'LENDWUS';
    if (code.toUpperCase() != expectedCode.toUpperCase()) {
      return LoginResult(success: false, error: 'Invalid group code.');
    }

    final firebaseUser = FirebaseService.auth.currentUser;
    if (firebaseUser == null || firebaseUser.email == null) {
      return LoginResult(success: false, error: 'You must be signed in first.');
    }

    try {
      final firestore = FirebaseService.firestore;

      final name = displayName ?? firebaseUser.displayName ?? firebaseUser.email!.split('@')[0];
      final amountPerHead = settings.asData?.value.defaultAmountPerHead ?? 500.0;
      final totalRequired = headsCount * amountPerHead;

      String? memberDocId;
      String? customMemberId;
      await firestore.runTransaction((tx) async {
        customMemberId = await MemberIdGenerator.generateNextMemberId(firestore);

        final member = Member(
          name: name,
          linkedEmail: firebaseUser.email,
          headsCount: headsCount,
          amountPerHead: amountPerHead,
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
        return LoginResult(success: true, role: UserRole.member);
      }
      return LoginResult(success: false, error: 'Failed to create member record.');
    } catch (e) {
      debugPrint('Join Group Code Error: $e');
      return LoginResult(success: false, error: e.toString());
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
    return _adminEmails.contains(user.email) || _hardcodedAdminEmails.contains(user.email);
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
