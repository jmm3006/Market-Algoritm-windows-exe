import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:algoritm_app_market/main.dart'; // MyHomePage ga o'tish uchun
import 'package:flutter/services.dart'; // Input formatters uchun

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final String baseUrl = "https://script.google.com/macros/s/AKfycby7zLE2N3sdLq0k9ViR3cr_hcK-wFbGRVQRZL5cH_ENJCTfl5724Yh306LIye_jZhBd/exec";

  List<Map<String, String>> _usersData = [];

  @override
  void initState() {
    super.initState();
    _fetchLoginData(); // Sahifa yuklanganda login ma'lumotlarini yuklash
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Serverdan foydalanuvchi login ma'lumotlarini oladi.
  Future<void> _fetchLoginData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=getLoginData'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['items'] != null && responseData['items'] is List) {
          setState(() {
            _usersData = List<Map<String, String>>.from(
              responseData['items'].map((user) => Map<String, String>.from(user)),
            );
            _errorMessage = null;
          });
        } else {
          setState(() {
            _errorMessage = 'Login ma\'lumotlarini olishda xatolik: "items" topilmadi yoki noto‘g‘ri format.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Serverdan noto‘g‘ri javob: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Server bilan bog‘lanishda xato: $e\nInternet ulanishingizni tekshiring.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Foydalanuvchi kiritgan ma'lumotlar bilan tizimga kirishni amalga oshiradi.
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Iltimos, foydalanuvchi nomi va parolni kiriting.';
        _isLoading = false;
      });
      return;
    }

    if (_usersData.isEmpty) {
      setState(() {
        _errorMessage = 'Login ma\'lumotlari hali yuklanmadi yoki serverdan olishda xato yuz berdi. Qayta urinib ko‘ring.';
        _isLoading = false;
      });
      return;
    }

    // Foydalanuvchini tekshirish
    bool isAuthenticated = _usersData.any((user) =>
    user['username'] == username && user['password'] == password);

    if (isAuthenticated) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Algoritm Market')),
        );
      }
    } else {
      setState(() {
        _errorMessage = 'Foydalanuvchi nomi yoki parol noto‘g‘ri.';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kirish',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white, // Matn rangini oq qildik
          ),
        ),
        centerTitle: true,
        // AppBar fon rangini asosiy rang sxemasidan oldik
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0, // AppBar soyasini olib tashladik
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ilova logotipi yoki nomi
              Icon(
                Icons.storefront, // Do'kon ikonkasini qo'shdik
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Algoritm Marketga xush kelibsiz!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              if (_isLoading && _usersData.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: CircularProgressIndicator(color: Colors.deepOrangeAccent), // Rangni o'zgartirdik
                ),

              // Foydalanuvchi nomi maydoni
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Foydalanuvchi nomi',
                  hintText: 'Foydalanuvchi nomini kiriting',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), // Yumaloq burchaklar
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2), // Fokuslanganda rang
                  ),
                  prefixIcon: Icon(Icons.person, color: Theme.of(context).colorScheme.primary), // Icon rangini o'zgartirdik
                  filled: true,
                  fillColor: Colors.grey.shade50, // Fon rangi
                ),
              ),
              const SizedBox(height: 16),
              // Parol maydoni
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Parol',
                  hintText: 'Parolni kiriting',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                  prefixIcon: Icon(Icons.lock, color: Theme.of(context).colorScheme.primary), // Icon rangini o'zgartirdik
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                obscureText: true, // Parolni yashirish
              ),
              // Xato xabari
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.bold, // Qalinroq qildik
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              // Kirish tugmasi
              _isLoading && _usersData.isNotEmpty
                  ? const CircularProgressIndicator(color: Colors.deepOrangeAccent) // Rangni o'zgartirdik
                  : SizedBox(
                width: double.infinity,
                height: 55, // Balandligini oshirdik
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary, // Asosiy rangni ishlatdik
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15), // Yumaloqroq burchaklar
                    ),
                    elevation: 5, // Soya qo'shdik
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // Katta va qalin matn
                  ),
                  child: const Text('Kirish'),
                ),
              ),
              const SizedBox(height: 16),
              // Parolni unutdingizmi? tugmasi
              TextButton(
                onPressed: () {
                  _showForgotPasswordSheet(context);
                },
                child: Text(
                  'Parolni unutdingizmi?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary, // Ikkinchi rangni ishlatdik
                    fontSize: 16,
                    fontWeight: FontWeight.w600, // Sal qalinroq
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Parolni tiklash uchun pastki modal oynani ko'rsatadi.
  void _showForgotPasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Klaviatura chiqsa ham scroll bo'lishi uchun
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)), // Yuqori burchaklarni yumaloqlash
      ),
      builder: (BuildContext bc) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bc).viewInsets.bottom,
            left: 25, // Paddingni oshirdik
            right: 25, // Paddingni oshirdik
            top: 30, // Paddingni oshirdik
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Parolni tiklash',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary, // Rangni o'zgartirdik
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Parolingizni tiklash uchun elektron pochta manzilingizni kiriting. Sizga tiklash havolasi yuboriladi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey), // Rangni o'zgartirdik
                ),
                const SizedBox(height: 30),
                // Elektron pochta maydoni
                TextField(
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Elektron pochta',
                    hintText: 'sizning@email.com',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                    ),
                    prefixIcon: Icon(Icons.email, color: Theme.of(context).colorScheme.primary),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 30),
                // Yuborish tugmasi
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(bc);
                      // SnackBar o'rniga custom dialog yoki _showStatusAnimation ishlatish mumkin,
                      // lekin hozircha SnackBar rangini o'zgartiramiz
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Parolni tiklash havolasi yuborildi (simulyatsiya)'),
                          backgroundColor: Theme.of(context).colorScheme.primary, // Rangni o'zgartirdik
                          behavior: SnackBarBehavior.floating, // Floating SnackBar
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Yumaloq burchaklar
                          margin: const EdgeInsets.all(10), // Chegaradan joy
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Yuborish'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}