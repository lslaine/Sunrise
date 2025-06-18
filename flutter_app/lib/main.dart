import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyApp',
      home: const SunriseHomePage(),
    );
  }
}

class SunriseHomePage extends StatefulWidget {
  const SunriseHomePage({super.key});

  @override
  State<SunriseHomePage> createState() => _SunriseHomePageState();
}

class _SunriseHomePageState extends State<SunriseHomePage> {
  String _responseMessage = 'Not signed in';
  bool _loading = false;

  static const String backendUrl = '<CLOUD_RUN_URL>'; // Replace with your actual URL

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _responseMessage = 'Signing in...';
    });

    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // Web Sign-In using Popup
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');

        try {
          userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-closed-by-user') {
            setState(() => _responseMessage = 'Sign-in cancelled (popup closed)');
            return;
          } else {
            rethrow;
          }
        }
      } else {
        // Mobile Sign-In
        final googleUser = await GoogleSignIn().signIn();

        if (googleUser == null) {
          setState(() => _responseMessage = 'Sign-in cancelled');
          return;
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);

      final response = await http.get(
        Uri.parse(backendUrl),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (response.statusCode == 200) {
        setState(() => _responseMessage = response.body);
      } else {
        setState(() => _responseMessage = 'Backend error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _responseMessage = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sunrise App')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_responseMessage, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _signInWithGoogle,
                    child: const Text('Sign In with Google'),
                  ),
                ],
              ),
      ),
    );
  }
}
