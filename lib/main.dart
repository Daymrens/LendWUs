import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'core/firebase/firebase_service.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  // 1. Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPrint('--- APP STARTING (v1.0.3) ---');

  // 2. Longer delay for native bridge stabilization (Xiaomi/MIUI specific fix)
  await Future.delayed(const Duration(milliseconds: 1000));

  bool initialized = false;
  
  // 3. Robust Firebase Initialization
  try {
    debugPrint('Step 1: Firebase.initializeApp...');
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 15));
    }
    initialized = true;
    debugPrint('Step 1: Success');
  } catch (e) {
    debugPrint('Step 1: Failed - $e');
    
    // Attempt fallback if first one fails
    try {
      debugPrint('Step 1: Fallback Attempt...');
      await Firebase.initializeApp().timeout(const Duration(seconds: 10));
      initialized = true;
      debugPrint('Step 1: Fallback Success');
    } catch (finalError) {
      debugPrint('Step 1: FATAL ERROR - $finalError');
      _showErrorApp('Firebase Initialization Failed', 
        'Could not connect to Firebase native bridge.\n\n'
        'Details: $finalError\n\n'
        'Try restarting your phone or clearing the app cache.');
      return;
    }
  }

  if (initialized) {
    try {
      debugPrint('Step 2: NotificationService.init...');
      await NotificationService.init().timeout(const Duration(seconds: 5));
      debugPrint('Step 2: Success');
    } catch (e) {
      debugPrint('Step 2: WARNING - $e');
    }

    try {
      debugPrint('Step 3: FirebaseService.seedDefaults...');
      await FirebaseService.seedDefaults().timeout(const Duration(seconds: 5));
      debugPrint('Step 3: Success');
    } catch (e) {
      debugPrint('Step 3: WARNING - $e');
    }

    debugPrint('--- APP INITIALIZED ---');
    runApp(const ProviderScope(child: SinkingFundApp()));
  }
}

void _showErrorApp(String title, String details) {
  runApp(MaterialApp(
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
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  details,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8B949E), fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => main(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    ),
  ));
}
