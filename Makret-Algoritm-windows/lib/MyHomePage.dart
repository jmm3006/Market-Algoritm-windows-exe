import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:algoritm_app_market/about_us.dart';
import 'package:algoritm_app_market/create_update.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  bool _isLoading = false;

  int _checkNumber = 338;
  static const String _kCheckNumberKey = 'newCheak';
  final String _companyPhone = "+998905908445";
  String _companyName = "Algoritm Group";
  String _cashierName = "Rajabova Asem";

  List<Map<String, dynamic>> market = [];
  List<Map<String, dynamic>> selectedProducts = [];
  List<Map<String, dynamic>> histories = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> _filteredMarket = [];

  double _totalSelectedAmount = 0.0;

  final String baseUrl =
      "https://script.google.com/macros/s/AKfycbz2g5F_bq09I9p053_uL0o9DCD6E96dc3dB8e-37YLL6C3zfL0XkxewaDddgCFsHyfo/exec";

  String get marketsApiUrl => "$baseUrl?action=getMarkets";

  String get postHistoriesUrl => baseUrl;

  String get getHistoriesUrl => "$baseUrl?action=getHistories";

  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    fetchMarkets();
    fetchHistories();
    _searchController.addListener(_onSearchChanged);
    _calculateTotalSelectedAmount();
    _loadCheckNumber();
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _calculateTotalSelectedAmount() {
    double total = 0.0;
    for (var product in selectedProducts) {
      double price = double.tryParse(product['price'].toString()) ?? 0.0;
      int quantity = (product['selected_quantity'] ?? 0) as int;
      total += (price * quantity);
    }
    setState(() {
      _totalSelectedAmount = total;
    });
  }

  void _onSearchChanged() {
    _filterMarkets();
  }

  void _filterMarkets() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMarket = List.from(market);
      } else {
        _filteredMarket =
            market.where((product) {
              final productName =
                  product['name']?.toString().toLowerCase() ?? '';
              return productName.contains(query);
            }).toList();
      }
    });
  }
  Future<void> _loadCheckNumber() async {

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _checkNumber = prefs.getInt(_kCheckNumberKey) ?? 338;
    });
  }

  Future<void> _saveCheckNumber(int number) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCheckNumberKey, number);
  }

  Future<void> _generateAndSavePdf() async {
    if (selectedProducts.isEmpty) {
      _showStatusAnimation('error', message: "PDF yaratish uchun mahsulot tanlanmagan.");
    }
    if (_commentController.text.isEmpty) {
      _showStatusAnimation('error', message: "Iltimos, PDF uchun izoh kiritilishi kerak.");
    }

    final pdf = pw.Document();
    pw.Font? ttf;
    try {
      final fontData = await DefaultAssetBundle.of(context).load('assets/fonts/CharisSILB.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (e) {
      throw Exception('Shriftni yuklashda xato: $e');
    }

    final String currentDateTime = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
    final int totalSum = selectedProducts.fold(
      0,
          (sum, item) =>
      sum +
          ((double.tryParse(item['price'].toString()) ?? 0.0) * (item['selected_quantity'] ?? 0)).toInt(),
    );

    const PdfPageFormat pageFormat = PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 6 * PdfPageFormat.mm);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: double.infinity,
                child: pw.Text(
                  "ALGORITM",
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Divider(height: 10, thickness: 1),
              _buildPdfDetailRow('Чек рақами:', '№$_checkNumber', ttf!),
              _buildPdfDetailRow('Компания:', _companyName, ttf!),
              for (var item in selectedProducts) ...[
                _buildPdfDetailRow('Махсулот:', item['name'] ?? 'N/A', ttf!),
                _buildPdfDetailRow('Нарх:', '${item['price'] ?? 0} сўм', ttf!),
                _buildPdfDetailRow('Миқдор:', '${item['selected_quantity'] ?? 0}', ttf!),
                _buildPdfDetailRow('Тўлов суммаси:', '${(double.tryParse(item['price'].toString()) ?? 0.0) * (item['selected_quantity'] ?? 0)} сўм', ttf!),
              ],
              _buildPdfDetailRow('Кассир:', _cashierName, ttf!),
              _buildPdfDetailRow('Вақт:', currentDateTime, ttf!),
              _buildPdfDetailRow('Компания рақами:', _companyPhone, ttf!),
              _buildPdfDetailRow('Изоҳ:', _commentController.text, ttf!),
              pw.Divider(height: 10, thickness: 1),
              _buildPdfRow('ЖАМИ:', '$totalSum сўм', ttf!, isTotal: true),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  "Харидингиз учун раҳмат!",
                  style: pw.TextStyle(font: ttf, fontSize: 8, fontStyle: pw.FontStyle.italic),
                ),
              ),
            ],
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final fileName = "chek_raport_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File("${output.path}/$fileName");
      await file.writeAsBytes(await pdf.save());
      _showStatusAnimation(
        'success',
        message: 'PDF fayl muvaffaqiyatli saqlandi!',
      );
      await OpenFilex.open(file.path);
    } catch (e) {
      throw Exception('PDF faylini saqlashda yoki ochishda xatolik: $e');
    }
  }

  pw.Widget _buildPdfRow(String label, String value, pw.Font font, {bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: font,
                fontSize: isTotal ? 9 : 8,
                fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: isTotal ? 9 : 8,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfDetailRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
      child: pw.Row(
        children: [
          pw.Text(
            label.isEmpty ? '' : '$label ',
            style: pw.TextStyle(font: font, fontSize: 8),
          ),
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.topRight,
              child: pw.Text(
                value,
                style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> fetchMarkets() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http
          .get(Uri.parse(marketsApiUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decodedBody = json.decode(response.body);
        List<dynamic> items = [];
        if (decodedBody['items'] != null && decodedBody['items'] is List) {
          items = decodedBody['items'];
        } else if (decodedBody['data'] != null && decodedBody['data'] is List) {
          items = decodedBody['data'];
        } else if (decodedBody['records'] != null &&
            decodedBody['records'] is List) {
          items = decodedBody['records'];
        } else {
          _showStatusAnimation(
            'error',
            message:
            "Market ma'lumotlari noto'g'ri formatda yoki 'items' topilmadi.",
          );
          return;
        }
        setState(() {
          market =
              items
                  .whereType<Map<String, dynamic>>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
          _filterMarkets();
        });
      } else {
        _showStatusAnimation(
          'error',
          message: "Market yuklash xato: HTTP ${response.statusCode}",
        );
      }
    } catch (e) {
      _showStatusAnimation(
        'error',
        message:
        "Market yuklashda xato: $e\nInternet ulanishingizni tekshiring.",
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> fetchHistories() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http
          .get(Uri.parse(getHistoriesUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decodedBody = json.decode(response.body);
        List<dynamic> items = [];
        if (decodedBody['items'] != null && decodedBody['items'] is List) {
          items = decodedBody['items'];
        } else if (decodedBody['data'] != null && decodedBody['data'] is List) {
          items = decodedBody['data'];
        } else if (decodedBody['records'] != null &&
            decodedBody['records'] is List) {
          items = decodedBody['records'];
        } else {
          _showStatusAnimation(
            'error',
            message:
            "Tarix ma'lumotlari noto'g'ri formatda yoki 'items' topilmadi.",
          );
          return;
        }
        setState(() {
          histories =
              items
                  .whereType<Map<String, dynamic>>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
          histories = List.from(histories.reversed);
        });
      } else {
        _showStatusAnimation(
          'error',
          message: "Tarix yuklash xato: HTTP ${response.statusCode}",
        );
      }
    } catch (e) {
      _showStatusAnimation(
        'error',
        message:
        "Tarix yuklashda xato: $e\nInternet ulanishingizni tekshiring.",
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> sendSelectedProducts() async {
    if (selectedProducts.isEmpty) {
      _showStatusAnimation('error', message: "Sotish uchun mahsulot tanlanmadi.");
      return;
    }

    final String generalComment = _commentController.text.trim();
    if (generalComment.isEmpty) {
      _showStatusAnimation('error', message: "Iltimos, izoh maydonini to'ldiring. Izoh yozish shart!");
      return;
    }

    for (var selectedP in selectedProducts) {
      final String productName = selectedP['name'].toString();
      final int selectedQuantity = (selectedP['selected_quantity'] ?? 0) as int;

      final originalProduct = market.firstWhere(
            (m) => m['name'] == productName,
        orElse: () => <String, dynamic>{},
      );

      if (originalProduct.isEmpty) {
        _showStatusAnimation(
          'error',
          message: '$productName mahsuloti marketda topilmadi!',
        );
        return;
      }

      final int originalQuantity = (originalProduct['quantity'] ?? 0) as int;

      if (selectedQuantity > originalQuantity) {
        _showStatusAnimation(
          'error',
          message:
          '${productName} mahsulotidan omborda yetarli miqdor yo‘q. (Omborda: ${originalQuantity} ta)',
        );
        return;
      }
    }

    _showStatusAnimation('waiting');
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    // YANGI: PDF yaratish va saqlash
    try {
      await _generateAndSavePdf();
    } catch (e) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _showStatusAnimation(
        'error',
        message: 'PDF faylini yaratishda xatolik: $e',
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final now = DateTime.now();
    final String formattedDateTime = DateFormat('yyyy-MM-dd HH:mm').format(now);

    final productsToFormat = selectedProducts.map((p) {
      double price = double.tryParse(p['price'].toString()) ?? 0.0;
      int quantity = (p['selected_quantity'] ?? 0) as int;
      double summa = price * quantity;

      return {
        'sana_vaqt': formattedDateTime,
        'name': p['name'].toString(),
        'price': price.toStringAsFixed(2),
        'quantity': quantity,
        'summa': summa.toStringAsFixed(2),
        'comment': generalComment,
      };
    }).toList();

    final Map<String, dynamic> requestData = {
      'action': 'postHistories',
      'items': productsToFormat,
    };

    try {
      final response = await http
          .post(
        Uri.parse(postHistoriesUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      )
          .timeout(const Duration(seconds: 15));

      _overlayEntry?.remove();
      _overlayEntry = null;

      final body = json.decode(response.body);
      _showStatusAnimation(
        'success',
        message: body['message'] ?? 'Sotuv muvaffaqiyatli yakunlandi!',
      );
    } catch (e) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _showStatusAnimation(
        'success',
        message:
        'Sotuv jarayoni muvaffaqiyatli yakunlandi, lekin internet/server xatosi yuz bergan bo‘lishi mumkin.',
      );
    } finally {
      if (mounted) {
        setState(() {
          selectedProducts.clear();
          _commentController.clear();
          _isLoading = false;
          _checkNumber++;
          _saveCheckNumber(_checkNumber);
        });
        fetchMarkets();
        fetchHistories();
        _calculateTotalSelectedAmount();
      }
    }
  }
  Future<void> _handleProductOperation(
      String action,
      Map<String, dynamic> product,
      ) async {
    _showStatusAnimation('waiting');
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final bodyParams = {'action': action, 'product': jsonEncode(product)};

    try {
      final response = await http
          .post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: bodyParams,
      )
          .timeout(const Duration(seconds: 15));

      _overlayEntry?.remove();
      _overlayEntry = null;

      final body = json.decode(response.body);
      if (response.statusCode == 200 && body['status'] == 'success') {
        _showStatusAnimation(
          'success',
          message: body['message'] ?? 'Operatsiya muvaffaqiyatli!',
        );
      } else {
        _showStatusAnimation(
          'success',
          message: body['message'] ?? 'Operatsiya muvaffaqiyatli!',
        );
      }
      fetchMarkets();
    } catch (e) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _showStatusAnimation(
        'success',
        message: 'Operatsiya muvaffaqiyatli!',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showStatusAnimation(String status, {String? message}) {
    _overlayEntry?.remove();
    _overlayEntry = null;

    String gifPath;
    String title;
    Duration duration = const Duration(seconds: 2);
    Color backgroundColor;
    Color textColor = Colors.white;

    switch (status) {
      case 'waiting':
        gifPath = 'assets/waiting.gif';
        title = 'Yuklanmoqda...';
        duration = const Duration(minutes: 1);
        backgroundColor = Colors.blueGrey;
        break;
      case 'success':
        gifPath = 'assets/success.gif';
        title = 'Muvaffaqiyatli!';
        backgroundColor = Colors.green;
        break;
      case 'error':
        gifPath = 'assets/error.gif';
        title = 'Xatolik!';
        backgroundColor = Colors.red;
        break;
      default:
        gifPath = 'assets/waiting.gif';
        title = 'Noma\'lum holat';
        backgroundColor = Colors.grey;
    }

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.1,
        left: MediaQuery.of(context).size.width * 0.1,
        right: MediaQuery.of(context).size.width * 0.1,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (gifPath.isNotEmpty)
                  Image.asset(gifPath, height: 80, width: 80),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    if (status != 'waiting') {
      Future.delayed(duration, () {
        _overlayEntry?.remove();
        _overlayEntry = null;
      });
    }
  }

  void selectProduct(Map<String, dynamic> product) {
    setState(() {
      int idx = selectedProducts.indexWhere((item) => item['name'] == product['name']);
      var origQuantity = (market.firstWhere((m) => m['name'] == product['name'], orElse: () => {'quantity': 0})['quantity'] ?? 0) as int;

      if (idx != -1) {
        if ((selectedProducts[idx]['selected_quantity'] ?? 0) < origQuantity) {
          selectedProducts[idx]['selected_quantity']++;
        } else {
          _showStatusAnimation('error', message: '${product['name']} uchun yetarli qoldiq yo‘q! (Omborda: ${origQuantity} ta)');
        }
      } else {
        if (origQuantity > 0) {
          var np = Map<String, dynamic>.from(product);
          np['selected_quantity'] = 1;
          selectedProducts.add(np);
        } else {
          _showStatusAnimation('error', message: '${product['name']} mahsuloti ombarda tugagan!');
        }
      }
      _calculateTotalSelectedAmount();
    });
  }

  void _clearSelectedProducts() {
    if (selectedProducts.isEmpty && _commentController.text.isEmpty) {
      _showStatusAnimation('info', message: 'Tanlangan mahsulotlar va izoh maydoni allaqachon bo‘sh edi.');
      return;
    }
    setState(() {
      selectedProducts.clear();
      _commentController.clear();
      _calculateTotalSelectedAmount();
    });
    _showStatusAnimation('success', message: 'Tanlangan mahsulotlar va izoh maydoni tozalandi.');
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      fetchMarkets();
      _searchController.clear();
      _calculateTotalSelectedAmount();
    } else if (index == 1) {
      fetchHistories();
    } else if (index == 2) {
      fetchMarkets();
    } else if (index == 3) {
      setState(() {});
    } else {
      _showStatusAnimation('error', message: 'Noma’lum sahifa tanlandi: $index');
    }
  }

  Widget marketPage() {
    List<Widget> _buildCheckPreviewWidgets() {
      List<Widget> widgets = [];
      final currentDateTime = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
      final double totalSum = _totalSelectedAmount;

      widgets.add(
        const Center(
          child: Text(
            "ALGORITM",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
      widgets.add(const Divider(thickness: 1, height: 16));

      Widget _buildInfoRow(String label, String value, {bool isBoldValue = true, double fontSize = 12.0}) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              Text(
                '$label: ',
                style: TextStyle(fontSize: fontSize),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isBoldValue ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }

      widgets.add(_buildInfoRow('Чек рақами', '№444'));
      widgets.add(_buildInfoRow('Компания', 'Algoritm Group'));
      widgets.add(const Divider(thickness: 1, height: 16));

      if (selectedProducts.isEmpty) {
        widgets.add(
          const Center(
            child: Text(
              'Mahsulot tanlanmagan',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        );
      } else {
        for (final item in selectedProducts) {
          final name = item['name'] ?? 'N/A';
          final price = item['price'] ?? 0;
          final quantity = item['selected_quantity'] ?? 0;
          final total = (double.tryParse(price.toString()) ?? 0.0) * quantity;
          widgets.add(_buildInfoRow('Маҳсулот', name));
          widgets.add(_buildInfoRow('Нарх', '$price сўм'));
          widgets.add(_buildInfoRow('Миқдор', '$quantity'));
          widgets.add(_buildInfoRow('Тўлов суммаси', '$total сўм'));
          widgets.add(const SizedBox(height: 8));
        }
      }
      widgets.add(const Divider(thickness: 1, height: 16));

      widgets.add(_buildInfoRow('Кассир', 'Rajabova Asem'));
      widgets.add(_buildInfoRow('Вақт', currentDateTime));
      widgets.add(_buildInfoRow('Компания рақами', '+998905908445'));
      widgets.add(_buildInfoRow('Изоҳ', _commentController.text.isEmpty ? 'Kiritilmagan' : _commentController.text, isBoldValue: false));

      widgets.add(const Divider(thickness: 1, height: 16));

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              const Text(
                'ЖАМИ:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '$totalSum сўм',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );

      widgets.add(const SizedBox(height: 16));
      widgets.add(
        const Center(
          child: Text(
            "Харидингиз учун раҳмат!",
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      );

      return widgets;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Expanded(
          flex: 3,
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text(
                'Mahsulotlar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Mahsulot nomini qidirish',
                    hintText: 'Misol: Olma',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterMarkets();
                        FocusScope.of(context).unfocus();
                      },
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: fetchMarkets,
                  child: _filteredMarket.isEmpty && _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredMarket.isEmpty && !_isLoading
                      ? const Center(child: Text('Qidiruv natijalari topilmadi.'))
                      : ListView.builder(
                      itemCount: _filteredMarket.length,
                      itemBuilder: (context, index) {
                        var p = _filteredMarket[index];
                        var sel = selectedProducts
                            .firstWhere(
                              (i) => i['name'] == p['name'],
                          orElse: () => {'selected_quantity': 0},
                        )['selected_quantity'] ??
                            0;

                        int quantity = (p['quantity'] ?? 0) as int;
                        Color quantityColor = Colors.black;
                        Color cardColor = Colors.white;
                        String subtitleText = '';
                        Widget trailingWidget;

                        Color outOfStockTextColor = Colors.red.shade900;

                        if (quantity <= 0) {
                          quantityColor = outOfStockTextColor;
                          cardColor = Colors.red.shade100;
                          subtitleText = 'TUGAGAN! (Tanlangan: $sel)';
                          trailingWidget = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline, color: Colors.red),
                              const SizedBox(width: 4),
                              Text('$sel',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, color: Colors.red)),
                            ],
                          );
                        } else if (quantity > 0 && quantity < 5) {
                          quantityColor = Colors.black;
                          cardColor = Colors.amber.shade200;
                          subtitleText =
                          'Narxi: ${p['price']} so‘m, Qoldiq: ${p['quantity']} (Tanlangan: $sel)';
                          trailingWidget = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    int idx = selectedProducts
                                        .indexWhere((item) => item['name'] == p['name']);
                                    if (idx != -1) {
                                      if ((selectedProducts[idx]['selected_quantity'] ?? 0) >
                                          1) {
                                        selectedProducts[idx]['selected_quantity']--;
                                      } else {
                                        selectedProducts.removeAt(idx);
                                      }
                                    }
                                    _calculateTotalSelectedAmount();
                                  });
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Text(
                                  '$sel',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.green),
                                onPressed: () => selectProduct(p),
                              ),
                            ],
                          );
                        } else {
                          quantityColor = Colors.black;
                          cardColor = Colors.white;
                          subtitleText =
                          'Narxi: ${p['price']} so‘m, Qoldiq: ${p['quantity']} (Tanlangan: $sel)';
                          trailingWidget = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    int idx = selectedProducts
                                        .indexWhere((item) => item['name'] == p['name']);
                                    if (idx != -1) {
                                      if ((selectedProducts[idx]['selected_quantity'] ?? 0) >
                                          1) {
                                        selectedProducts[idx]['selected_quantity']--;
                                      } else {
                                        selectedProducts.removeAt(idx);
                                      }
                                    }
                                    _calculateTotalSelectedAmount();
                                  });
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Text(
                                  '$sel',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.green),
                                onPressed: () => selectProduct(p),
                              ),
                            ],
                          );
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          color: cardColor,
                          child: ListTile(
                            title: Text(
                              p['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: quantity <= 0
                                    ? outOfStockTextColor
                                    : (quantity > 0 && quantity < 5
                                    ? Colors.black
                                    : Colors.black),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subtitleText,
                                  style: TextStyle(color: quantityColor, fontSize: 13),
                                ),
                                if (quantity > 0 && quantity >= 5)
                                  Text(
                                    'Sotib olingan narxi: ${p['price_bought']} so‘m',
                                    style: TextStyle(
                                        color: Colors.grey.shade600, fontSize: 12),
                                  ),
                              ],
                            ),
                            trailing: trailingWidget,
                            onTap: () => selectProduct(p),
                          ),
                        );
                      }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          labelText: 'Izoh (Majburiy)',
                          hintText: 'Misol: Mijoz talabiga binoan, chegirma bilan',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.deepOrangeAccent,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.deepOrange,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Jami summa:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_totalSelectedAmount.toStringAsFixed(2)} so‘m',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrangeAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: !_isLoading ? sendSelectedProducts : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrangeAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                                : Text(
                              'OK — Sotish (${selectedProducts.fold<int>(0, (s, i) => s + (i['selected_quantity'] as int))} ta)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: !_isLoading ? _clearSelectedProducts : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Tozalash',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Чекни олдиндан кўриш',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const Divider(thickness: 1, height: 20),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildCheckPreviewWidgets(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget historyPage() {
    return Column(
      children: [
        const SizedBox(height: 10),
        const Text(
          'Sotuv Tarixi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: fetchHistories,
            child: histories.isEmpty && _isLoading
                ? const Center(child: CircularProgressIndicator())
                : histories.isEmpty && !_isLoading
                ? const Center(
              child: Text('Tarix ma\'lumotlari topilmadi.'),
            )
                : ListView.builder(
              itemCount: histories.length,
              itemBuilder: (context, index) {
                var h = histories[index];
                String datePart = 'N/A';
                String timePart = 'N/A';
                if (h['sana_vaqt'] != null) {
                  try {
                    DateTime originalDateTime =
                    DateTime.parse(h['sana_vaqt'].toString());
                    DateTime adjustedDateTime =
                    originalDateTime.add(const Duration(hours: 5));
                    datePart =
                        DateFormat('dd.MM.yyyy').format(adjustedDateTime);
                    timePart = DateFormat('HH:mm').format(adjustedDateTime);
                  } catch (e) {
                    datePart = h['sana_vaqt'].toString();
                    timePart = '';
                  }
                }

                String comment = h['comment']?.toString() ?? '';
                if (comment.isEmpty) {
                  comment = 'Izoh: Kiritilmagan';
                } else {
                  comment = 'Izoh: $comment';
                }

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    title: Text(
                      h['name'] ?? 'Noma\'lum mahsulot',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sana: $datePart, Vaqt: $timePart',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Narx: ${h['price'] ?? 0} so‘m, Miqdor: ${h['quantity'] ?? 0}, Summa: ${h['summa'] ?? 0} so‘m',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            comment,
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget adminPage() {
    return Column(
      children: [
        const SizedBox(height: 10),
        const Text(
          'Admin Panel',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Center(
            child:
            _isLoading
                ? const CircularProgressIndicator()
                : Text(
              'Admin paneli uchun mahsulotlarni boshqarish (market: ${market.length} ta).',
            ),
          ),
        ),
      ],
    );
  }

  Widget printerPage() {
    return Column(
      children: [
        const SizedBox(height: 10),
        const Text(
          'Printer',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Center(
            child:
            _isLoading
                ? const CircularProgressIndicator()
                : Text(
              'Printer uchun tarixlar: ${histories.length} ta yozuv.',
            ),
          ),
        ),
      ],
    );
  }

  Widget dayMoneyPage() {
    Map<String, List<Map<String, dynamic>>> dailyTransactions = {};

    double overallTotalBoughtPriceHistory = 0.0;
    double overallTotalPriceHistory = 0.0;
    double overallProfitHistory = 0.0;

    for (var h in histories) {
      double itemBoughtPrice = double.tryParse(h['price_bought']?.toString() ?? '0.0') ?? 0.0;
      double itemSellingPrice = double.tryParse(h['summa']?.toString() ?? '0.0') ?? 0.0;

      overallTotalBoughtPriceHistory += itemBoughtPrice;
      overallTotalPriceHistory += itemSellingPrice;

      if (h['sana_vaqt'] != null) {
        try {
          DateTime transactionDate = DateTime.parse(h['sana_vaqt'].toString());
          String transactionDay = DateFormat(
            'yyyy-MM-dd',
          ).format(transactionDate);

          dailyTransactions[transactionDay] ??= [];

          dailyTransactions[transactionDay]!.add({
            'name': h['name'] ?? 'Noma\'lum mahsulot',
            'quantity': h['quantity'] ?? 0,
            'summa': itemSellingPrice,
          });
        } catch (e) {
          debugPrint("Sana formatida xato: $e - ${h['sana_vaqt']}");
          continue;
        }
      }
    }

    overallProfitHistory = overallTotalPriceHistory - overallTotalBoughtPriceHistory;

    double overallMarketValueBought = 0.0;
    double overallMarketValueSelling = 0.0;
    double overallMarketPotentialProfit = 0.0;

    for (var item in market) {
      double itemPriceBought = double.tryParse(item['price_bought']?.toString() ?? '0.0') ?? 0.0;
      double itemPriceSelling = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;

      overallMarketValueBought += itemPriceBought;
      overallMarketValueSelling += itemPriceSelling;
    }
    overallMarketPotentialProfit = overallMarketValueSelling - overallMarketValueBought;


    var sortedDays =
    dailyTransactions.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        const SizedBox(height: 10),
        const Text(
          'Umumiy Statistikalar',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
        ),
        const SizedBox(height: 8),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Mavjud Mahsulotlar Bo\'yicha (Inventar Qiymati):',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
                const SizedBox(height: 8),
                _buildStatRow(
                  label: 'Inventar Xarid Narxi:',
                  value: overallMarketValueBought,
                  color: Colors.orange.shade700,
                  icon: Icons.attach_money,
                ),
                const Divider(height: 16, thickness: 1),
                _buildStatRow(
                  label: 'Inventar Sotish Narxi:',
                  value: overallMarketValueSelling,
                  color: Colors.purple.shade700,
                  icon: Icons.sell,
                ),
                const Divider(height: 16, thickness: 1),
                _buildStatRow(
                  label: 'Potensial Foyda (Inventar):',
                  value: overallMarketPotentialProfit,
                  color: Colors.teal.shade700,
                  icon: Icons.insights,
                  isProfit: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (dailyTransactions.isEmpty)
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Kunlik Daromad',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Daromad va mahsulot ma\'lumotlari topilmadi.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Kunlik Daromad va Mahsulotlar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: fetchHistories,
                    child: ListView.builder(
                      itemCount: sortedDays.length,
                      itemBuilder: (context, index) {
                        String day = sortedDays[index];
                        List<Map<String, dynamic>> transactions = dailyTransactions[day]!;
                        double totalRevenue = transactions.fold(
                          0.0,
                              (sum, item) => sum + (item['summa'] as double),
                        );

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ExpansionTile(
                            title: Text(
                              day,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            subtitle: Text(
                              'Jami daromad: ${totalRevenue.toStringAsFixed(2)} so‘m',
                              style: const TextStyle(color: Colors.black87),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children:
                                  transactions.map((transaction) {
                                    return ListTile(
                                      leading: const Icon(
                                        Icons.shopping_cart,
                                        color: Colors.deepOrangeAccent,
                                      ),
                                      title: Text(
                                        transaction['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Miqdor: ${transaction['quantity']}, Summa: ${transaction['summa'].toStringAsFixed(2)} so‘m',
                                        style: const TextStyle(
                                          color: Colors.black87,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  Widget _buildStatRow({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
    bool isProfit = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Text(
          '${value.toStringAsFixed(2)} so‘m',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isProfit && value < 0 ? Colors.red : color,
          ),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    var pages = [
      marketPage(),
      historyPage(),
      AdminPage(
        onProductOperation: _handleProductOperation,
        isLoading: _isLoading,
        marketData: market,
        onRefreshMarkets: fetchMarkets,
        onShowStatusAnimation: _showStatusAnimation,
      ),
      dayMoneyPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text('', style: TextStyle(color: Colors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              widget.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Text(
                'Navigatsiya',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Market'),
              selected: _selectedIndex == 0,
              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Sotuv Tarixi'),
              selected: _selectedIndex == 1,
              onTap: () {
                _onItemTapped(1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Admin Panel'),
              selected: _selectedIndex == 2,
              onTap: () {
                _onItemTapped(2);
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Kunlik Daromad'),
              selected: _selectedIndex == 3,
              onTap: () {
                _onItemTapped(3);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Dastur haqida'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutUsPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: Center(child: pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Market'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Tarix'),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Daromad',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepOrangeAccent,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
