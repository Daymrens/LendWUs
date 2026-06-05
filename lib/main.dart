import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'core/firebase/firebase_service.dart';
import 'core/services/notification_service.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _BootstrapApp()));
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  String? _status;
  bool _hasError = false;
  String _errorMessage = '';
  bool _ready = false;
  final DateTime _startTime = DateTime.now();
  static const Duration _minSplashDuration = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _status = 'Initializing...');

    try {
      setState(() => _status = 'Connecting...');
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 15));
      }
    } catch (e) {
      try {
        await Firebase.initializeApp().timeout(const Duration(seconds: 10));
      } catch (finalError) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Could not connect to Firebase.\n\n$finalError';
          });
        }
        return;
      }
    }

    try {
      setState(() => _status = 'Setting up notifications...');
      await NotificationService.init().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }

    try {
      setState(() => _status = 'Loading...');
      await FirebaseService.seedDefaults().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('seedDefaults failed: $e');
    }

    if (mounted) {
      final elapsed = DateTime.now().difference(_startTime);
      final remaining = _minSplashDuration - elapsed;
      if (remaining > Duration.zero) {
        setState(() => _status = 'Welcome');
        await Future.delayed(remaining);
      }
      if (mounted) {
        setState(() {
          _ready = true;
          _hasError = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return const SinkingFundApp();
    }

    if (_hasError) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Connection Failed',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF8B949E), fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _status = 'Retrying...';
                      });
                      _initialize();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(statusText: _status),
    );
  }
}
