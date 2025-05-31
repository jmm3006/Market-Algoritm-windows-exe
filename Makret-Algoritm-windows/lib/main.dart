
import 'package:flutter/material.dart';

import 'package:algoritm_app_market/login.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Algoritm Market',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrangeAccent),
        useMaterial3: true,
      ),
      home: const ConnectivityCheckerPage(),
    );
  }
}

// --- Internet ulanishini tekshiruvchi sahifa ---
class ConnectivityCheckerPage extends StatefulWidget {
  const ConnectivityCheckerPage({super.key});

  @override
  State<ConnectivityCheckerPage> createState() => _ConnectivityCheckerPageState();
}

class _ConnectivityCheckerPageState extends State<ConnectivityCheckerPage> {
  @override
  void initState() {
    super.initState();
    _checkConnectivityAndNavigate();
  }

  Future<void> _checkConnectivityAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3));

    final connectivityResult = await (Connectivity().checkConnectivity());

    if (mounted) {
      if (connectivityResult == ConnectivityResult.none) {
        _showNoInternetDialog();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Internet ulanishi yo‘q'),
          content: const Text(
              'Ilovani ishga tushirish uchun internetga ulanishingiz kerak. Iltimos, ulanishingizni tekshiring.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Qayta urinish'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _checkConnectivityAndNavigate();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.deepOrangeAccent),
            SizedBox(height: 20),
            Text(
              "Yuklanmoqda...",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
