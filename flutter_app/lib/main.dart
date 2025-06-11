import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const SunriseApp());
}

class SunriseApp extends StatelessWidget {
  const SunriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sunrise',
      home: const SunriseHomePage(),
    );
  }
}

class SunriseHomePage extends StatefulWidget {
  const SunriseHomePage({super.key});

  @override
  _SunriseHomePageState createState() => _SunriseHomePageState();
}

class _SunriseHomePageState extends State<SunriseHomePage> {
  String _responseMessage = 'Loading...';

  // Replace this with your actual backend external IP and port
  static const String backendUrl = 'http://<your-vm-external-ip>:8080/';

  @override
  void initState() {
    super.initState();
    _fetchBackendMessage();
  }

  Future<void> _fetchBackendMessage() async {
    try {
      final response = await http.get(Uri.parse(backendUrl));
      if (response.statusCode == 200) {
        setState(() {
          _responseMessage = response.body;
        });
      } else {
        setState(() {
          _responseMessage = 'Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _responseMessage = 'Failed to connect to backend: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sunrise App')),
      body: Center(child: Text(_responseMessage)),
    );
  }
}
