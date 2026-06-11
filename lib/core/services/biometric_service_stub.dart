import 'dart:io';

Future<bool> isAvailable() async {
  if (Platform.isAndroid || Platform.isIOS) {
    return true;
  }
  return false;
}

Future<bool> authenticate() async {
  if (Platform.isAndroid || Platform.isIOS) {
    return true;
  }
  return false;
}

Future<bool> authenticateWithPasscode() async {
  if (Platform.isAndroid || Platform.isIOS) {
    return true;
  }
  return false;
}

Future<void> setEnabled(bool value) async {}

Future<bool> isEnabled() async => false;
