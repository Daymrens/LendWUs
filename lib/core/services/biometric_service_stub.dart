import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

final LocalAuthentication _auth = LocalAuthentication();

Future<bool> isAvailable() async {
  try {
    final canCheck = await _auth.canCheckBiometrics;
    final supported = await _auth.isDeviceSupported();
    debugPrint('Biometric: canCheck=$canCheck, supported=$supported');
    return canCheck || supported;
  } catch (e) {
    debugPrint('Biometric isAvailable error: $e');
    return false;
  }
}

Future<String?> getError() async {
  try {
    final canCheck = await _auth.canCheckBiometrics;
    final supported = await _auth.isDeviceSupported();
    return 'canCheck=$canCheck, supported=$supported';
  } catch (e) {
    return 'Error checking: $e';
  }
}

Future<bool> authenticate() async {
  try {
    final result = await _auth.authenticate(
      localizedReason: 'Use fingerprint or device passcode to sign in',
      options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
    );
    return result;
  } catch (e) {
    debugPrint('Biometric auth error: $e');
    rethrow;
  }
}

Future<bool> authenticateWithPasscode() async {
  try {
    return await _auth.authenticate(
      localizedReason: 'Authenticate to continue',
      options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
    );
  } catch (e) {
    debugPrint('Passcode auth error: $e');
    rethrow;
  }
}

Future<void> setEnabled(bool value) async {}

Future<bool> isEnabled() async => false;
