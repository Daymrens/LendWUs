import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'core/firebase/firebase_service.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Longer delay to allow native channels to settle (Xiaomi devices often need more time)
  await Future.delayed(const Duration(milliseconds: 500));
  
  debugPrint('--- APP STARTING (v1.0.1) ---');

  bool initialized = false;
  int retryCount = 0;
  
  while (!initialized && retryCount < 3) {
    try {
      debugPrint('Step 1: Firebase.initializeApp (Attempt ${retryCount + 1})...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 15));
      initialized = true;
      debugPrint('Step 1: Success');
    } catch (e) {
      retryCount++;
      debugPrint('Step 1: Failed attempt $retryCount - $e');
      
      if (retryCount >= 3) {
        // Final fallback: try without options
        try {
          debugPrint('Step 1: Trying default fallback (no options)...');
          await Firebase.initializeApp().timeout(const Duration(seconds: 15));
          initialized = true;
          debugPrint('Step 1: Fallback Success');
        } catch (finalError) {
          debugPrint('Step 1: ALL ATTEMPTS FAILED');
          _showErrorApp('Firebase Initialization Failed', 
            'This usually happens if the native bridge is blocked. \n\nError: $finalError\n\nTry clearing app data or restarting the device.');
          return;
        }
      } else {
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
  }

  // Run subsequent initializations in parallel or sequentially but with isolated catches
  try {
    debugPrint('Step 2: NotificationService.init...');
    await NotificationService.init().timeout(const Duration(seconds: 5));
    debugPrint('Step 2: Success');
  } catch (e) {
    debugPrint('Step 2: WARNING - $e');
    // Don't kill the app for notifications
  }

  try {
    debugPrint('Step 3: FirebaseService.seedDefaults...');
    await FirebaseService.seedDefaults().timeout(const Duration(seconds: 5));
    debugPrint('Step 3: Success');
  } catch (e) {
    debugPrint('Step 3: WARNING - $e');
    // Don't kill the app for seeding
  }

  debugPrint('--- APP INITIALIZED ---');
  runApp(const ProviderScope(child: SinkingFundApp()));
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
