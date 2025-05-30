import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // URL ochish uchun
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Ijtimoiy media ikonkalari uchun

// `pubspec.yaml` faylingizga ushbu qatorni qo'shing:
// dependencies:
//   font_awesome_flutter: ^10.7.0 # Eng so'nggi versiyani tekshiring

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  // Telegramga o'tish funksiyasi
  _launchTelegram(BuildContext context) async {
    const url = 'https://t.me/JMD_300601'; // Jamshidbekning Telegram username'i
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      _showErrorSnackBar(context, 'Telegramni ochib bo\'lmadi. Iltimos, ilovangiz o\'rnatilganligini tekshiring.');
    }
  }

  // Instagramga o'tish funksiyasi
  _launchInstagram(BuildContext context) async {
    const url = 'https://www.instagram.com/jmd.cs2.hub/'; // Jamshidbekning Instagram profili
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      _showErrorSnackBar(context, 'Instagramni ochib bo\'lmadi. Iltimos, ilovangiz o\'rnatilganligini tekshiring.');
    }
  }

  // Xatolik xabarini ko'rsatish uchun Snackbar
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent, // Qizilning yumshoqroq tusi
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Asosiy ranglarni Theme'dan olamiz
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color accentColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Biz Haqimizda',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8, // Harflar orasidagi bo'shliq
          ),
        ),
        backgroundColor: primaryColor, // Asosiy rangdan olamiz
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0), // Vertikal paddingni oshirdik
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Foydalanuvchi rasmi (eng yuqorida va markazda)
            Center(
              child: CircleAvatar(
                radius: 65, // Radiusni yanada qulayroq qildik
                backgroundImage: const AssetImage('assets/jmd.jpg'), // RASMINGIZNI BU YERGA QO\'YING
                backgroundColor: accentColor.withOpacity(0.1), // Yengilroq fon rangi
                child: Container( // Chegara uchun
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withOpacity(0.5), width: 3), // Chiroyli chegara
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),

            // Shaxsiy ism
            Text(
              "Yuldashev Jamshidbek",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30, // Kattaroq shrift
                fontWeight: FontWeight.w900, // Juda qalin
                color: primaryColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            // Kasb yoki lavozim
            Text(
              "Software Engineer | Flutter Developer", // Bu yerga o'z kasbingizni yozing
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 30),

            // Loyiha haqida asosiy matn (Card ichida)
            Card(
              elevation: 4, // Yengil soya
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      "\"Algoritm Market App\" loyihasi",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Ushbu mobil ilova Google Sheets (elektron jadvallar) yordamida kichik biznes yoki shaxsiy do'konlarning mahsulot boshqaruvi va savdo operatsiyalarini avtomatlashtirishga mo'ljallangan. U Google Apps Script orqali Google Sheets bilan bevosita aloqada bo'ladi, bu esa ma'lumotlarni saqlash va boshqarish uchun kuchli va arzon yechimni taqdim etadi.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Ijtimoiy tarmoqlar uchun sarlavha
            Text(
              "Biz bilan bog'laning:",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 20),

            // Ijtimoiy tarmoq tugmalari
            _SocialButton(
              onPressed: () => _launchTelegram(context),
              icon: FontAwesomeIcons.telegram, // Font Awesome ikonka
              label: 'Telegram',
              color: const Color(0xFF0088CC), // Telegram brend rangi
            ),
            const SizedBox(height: 15),
            _SocialButton(
              onPressed: () => _launchInstagram(context),
              icon: FontAwesomeIcons.instagram, // Font Awesome ikonka
              label: 'Instagram',
              color: const Color(0xFFC13584), // Instagramga mos rang
            ),
            const SizedBox(height: 15),
            _SocialButton(
              onPressed: () {
                // Qo'shimcha aloqa, masalan email
                final Uri emailLaunchUri = Uri(
                  scheme: 'mailto',
                  path: 'your.email@example.com', // <-- O'zingizning emailingizni qo'ying
                  queryParameters: {
                    'subject': 'Algoritm Market App bo\'yicha savol',
                  },
                );
                launchUrl(emailLaunchUri);
              },
              icon: Icons.email,
              label: 'Email yuborish',
              color: Colors.redAccent, // Email uchun qizil rang
            ),
            const SizedBox(height: 40),

            // Yakuniy matn
            Text(
              'Loyihaga bo\'lgan qiziqishingiz uchun tashakkur! Har qanday savollar yoki hamkorlik takliflari bo\'lsa, bizga murojaat qilishdan tortinmang.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Ijtimoiy tarmoq tugmalari uchun alohida vidjet
class _SocialButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;

  const _SocialButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 22), // Katta ikonka
      label: Text(
        label,
        style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold), // Katta va qalin matn
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), // Kattaroq padding
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 8, // Katta soya
        minimumSize: const Size(double.infinity, 60), // Katta tugma
      ),
    );
  }
}