import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:algoritm_app_market/create_update.dart';
import 'package:algoritm_app_market/about_us.dart';
import 'package:intl/intl.dart';
import 'package:algoritm_app_market/printeX.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> { // SingleTickerProviderStateMixin olib tashlandi
  int _selectedIndex = 0;
  bool _isLoading = false;

  List<dynamic> market = [];
  List<Map<String, dynamic>> selectedProducts = [];
  List<Map<String, dynamic>> histories = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> _filteredMarket = [];

  double _totalSelectedAmount = 0.0;

  final String baseUrl = "https://script.google.com/macros/s/AKfycby7zLE2N3sdLq0k9ViR3cr_hcK-wFbGRVQRZL5cH_ENJCTfl5724Yh306LIye_jZhBd/exec";
  String get marketsApiUrl => "$baseUrl?action=getMarkets";
  String get postHistoriesUrl => baseUrl;
  String get getHistoriesUrl => "$baseUrl?action=getHistories";

  OverlayEntry? _overlayEntry;

  // AnimationController va Animation deklaratsiyalari olib tashlandi
  // late AnimationController _animationController;
  // late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    fetchMarkets();
    fetchHistories();
    _searchController.addListener(_onSearchChanged);
    _calculateTotalSelectedAmount();

    // AnimationController va Animation initsializatsiyasi olib tashlandi
    // _animationController = AnimationController(
    //   vsync: this,
    //   duration: const Duration(milliseconds: 300),
    // );
    // _animation = Tween<double>(begin: 0, end: -10).animate(_animationController)
    //   ..addListener(() {
    //     setState(() {});
    //   });
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _commentController.dispose();
    // AnimationController dispose chaqiruvi olib tashlandi
    // _animationController.dispose();
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
        _filteredMarket = market.where((product) {
          final productName = product['name']?.toString().toLowerCase() ?? '';
          return productName.contains(query);
        }).toList();
      }
    });
  }

  Future<void> fetchMarkets() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    try {
      final response = await http.get(Uri.parse(marketsApiUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decodedBody = json.decode(response.body);
        List<dynamic> items = [];
        if (decodedBody['items'] != null && decodedBody['items'] is List) {
          items = decodedBody['items'];
        } else if (decodedBody['data'] != null && decodedBody['data'] is List) {
          items = decodedBody['data'];
        } else if (decodedBody['records'] != null && decodedBody['records'] is List) {
          items = decodedBody['records'];
        } else {
          _showStatusAnimation('error', message: "Market ma'lumotlari noto'g'ri formatda yoki 'items' topilmadi.");
          return;
        }
        setState(() {
          market = items;
          _filterMarkets();
        });
      } else {
        _showStatusAnimation('error', message: "Market yuklash xato: HTTP ${response.statusCode}");
      }
    } catch (e) {
      _showStatusAnimation('error', message: "Market yuklashda xato: $e\nInternet ulanishingizni tekshiring.");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> fetchHistories() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    try {
      final response = await http.get(Uri.parse(getHistoriesUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decodedBody = json.decode(response.body);
        List<dynamic> items = [];
        if (decodedBody['items'] != null && decodedBody['items'] is List) {
          items = decodedBody['items'];
        } else if (decodedBody['data'] != null && decodedBody['data'] is List) {
          items = decodedBody['data'];
        } else if (decodedBody['records'] != null && decodedBody['records'] is List) {
          items = decodedBody['records'];
        } else {
          _showStatusAnimation('error', message: "Tarix ma'lumotlari noto'g'ri formatda yoki 'items' topilmadi.");
          return;
        }
        setState(() {
          histories = (items as List)
              .map((item) => item as Map<String, dynamic>)
              .toList();
          histories = List.from(histories.reversed);
        });
      } else {
        _showStatusAnimation('error', message: "Tarix yuklash xato: HTTP ${response.statusCode}");
      }
    } catch (e) {
      _showStatusAnimation('error', message: "Tarix yuklashda xato: $e\nInternet ulanishingizni tekshiring.");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> sendSelectedProducts() async {
    if (selectedProducts.isEmpty) {
      _showStatusAnimation('success', message: "Sotish uchun mahsulot tanlanmadi.");
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
        orElse: () => null,
      );

      if (originalProduct == null) {
        _showStatusAnimation('success', message: '$productName mahsuloti marketda topilmadi!');
        return;
      }

      final int originalQuantity = (originalProduct['quantity'] ?? 0) as int;

      if (selectedQuantity > originalQuantity) {
        _showStatusAnimation('success', message: '${productName} mahsulotidan omborda yetarli miqdor yo‘q. (Omborda: ${originalQuantity} ta)');
        return;
      }
    }

    _showStatusAnimation('waiting');
    if (!mounted) return;
    setState(() { _isLoading = true; });

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
      final response = await http.post(
        Uri.parse(postHistoriesUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 15));

      _overlayEntry?.remove();
      _overlayEntry = null;

      final body = json.decode(response.body);
      _showStatusAnimation('success', message: body['message'] ?? 'Sotuv jarayoni muvaffaqiyatli yakunlandi, ammo server xatosi bo\'lishi mumkin.');

    } catch (e) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _showStatusAnimation('success', message: 'Operatsiya yakunlandi (internet/server xatosi yuz bergan bo\'lishi mumkin).');
    } finally {
      if (mounted) {
        setState(() {
          selectedProducts.clear();
          _commentController.clear();
          _isLoading = false;
        });
        fetchMarkets();
        fetchHistories();
        _calculateTotalSelectedAmount();
      }
    }
  }

  Future<void> _handleProductOperation(String action, Map<String, dynamic> product) async {
    _showStatusAnimation('waiting');
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final bodyParams = {
      'action': action,
      'product': jsonEncode(product),
    };

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: bodyParams,
      ).timeout(const Duration(seconds: 15));

      _overlayEntry?.remove();
      _overlayEntry = null;

      final body = json.decode(response.body);
      _showStatusAnimation('success', message: body['message'] ?? 'Operatsiya muvaffaqiyatli!');
      fetchMarkets();
    } catch (e) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _showStatusAnimation('success', message: 'Operatsiya yakunlandi (internet/server xatosi yuz bergan bo\'lishi mumkin).');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
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
      builder: (context) => Positioned(
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  textAlign: TextAlign.center,
                ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      message,
                      style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.9)),
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
      var origQuantity = (market.firstWhere((m) => m['name'] == product['name'], orElse: () => {'quantity':0})['quantity'] ?? 0) as int;

      if (idx != -1) {
        if ((selectedProducts[idx]['selected_quantity'] ?? 0) < origQuantity) {
          selectedProducts[idx]['selected_quantity']++;
        } else {
          _showStatusAnimation('success', message: '${product['name']} uchun yetarli qoldiq yo‘q! (Omborda: ${origQuantity} ta)');
        }
      } else {
        if (origQuantity > 0) {
          var np = Map<String, dynamic>.from(product);
          np['selected_quantity'] = 1;
          selectedProducts.add(np);
        } else {
          _showStatusAnimation('success', message: '${product['name']} mahsuloti ombarda tugagan!');
        }
      }
      _calculateTotalSelectedAmount();
    });
  }

  void _clearSelectedProducts() {
    if (selectedProducts.isEmpty && _commentController.text.isEmpty) {
      _showStatusAnimation('success', message: 'Tanlangan mahsulotlar va izoh maydoni allaqachon bo‘sh edi.');
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
    setState(() { _selectedIndex = index; });
    if (index == 0) {
      fetchMarkets();
      _searchController.clear();
      _calculateTotalSelectedAmount();
    }
    if (index == 1) fetchHistories();
    if (index == 2) fetchMarkets();
    if (index == 4) {
      setState(() {}); // Daromad sahifasini yangilash
    }
  }

  Widget marketPage() {
    return Column(
      children: [
        const SizedBox(height: 10),
        const Text('Mahsulotlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  var sel = selectedProducts.firstWhere((i) => i['name']==p['name'], orElse: ()=>{'selected_quantity':0})['selected_quantity'] ?? 0;

                  int quantity = (p['quantity'] ?? 0) as int;
                  Color quantityColor = Colors.black;
                  Color cardColor = Colors.white;
                  String subtitleText = 'Qoldiq: ${p['quantity']} (Tanlangan: $sel)';
                  Widget trailingWidget;

                  if (quantity <= 0) {
                    quantityColor = Colors.red;
                    cardColor = Colors.red.shade100;
                    subtitleText = 'TUGAGAN! (Tanlangan: $sel)';
                    trailingWidget = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.red),
                        const SizedBox(width: 4),
                        Text('$sel', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    );
                  } else {
                    trailingWidget = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              int idx = selectedProducts.indexWhere((item) => item['name'] == p['name']);
                              if (idx != -1) {
                                if ((selectedProducts[idx]['selected_quantity'] ?? 0) > 1) {
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    color: cardColor,
                    child: ListTile(
                      title: Text(
                        p['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: quantity <= 0 ? Colors.red.shade900 : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        '${p['price']} so‘m - $subtitleText',
                        style: TextStyle(color: quantityColor),
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
                      borderSide: const BorderSide(color: Colors.deepOrangeAccent),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_totalSelectedAmount.toStringAsFixed(2)} so‘m',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrangeAccent),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                        'OK — Sotish (${selectedProducts.fold<int>(0,(s,i)=>s+(i['selected_quantity'] as int))} ta)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Tozalash',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
                ? const Center(child: Text('Tarix ma\'lumotlari topilmadi.'))
                : ListView.builder(
              itemCount: histories.length,
              itemBuilder: (context, index) {
                var h = histories[index];
                String datePart = 'N/A';
                String timePart = 'N/A';
                if (h['sana_vaqt'] != null) {
                  try {
                    DateTime originalDateTime = DateTime.parse(h['sana_vaqt'].toString());
                    DateTime adjustedDateTime = originalDateTime.add(const Duration(hours: 5));
                    datePart = DateFormat('dd.MM.yyyy').format(adjustedDateTime);
                    timePart = DateFormat('HH:mm').format(adjustedDateTime);
                  } catch (e) {
                    datePart = h['sana_vaqt'].toString();
                    timePart = '';
                  }
                }

                String comment = h['comment'] ?? '';
                if (comment.isEmpty) {
                  comment = 'Izoh: Kiritilmagan';
                } else {
                  comment = 'Izoh: $comment';
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                        ),
                        Text(
                          'Narx: ${h['price'] ?? 0} so‘m, Miqdor: ${h['quantity'] ?? 0}, Summa: ${h['summa'] ?? 0} so‘m',
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
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

  Widget dayMoneyPage() {
    Map<String, List<Map<String, dynamic>>> dailyTransactions = {};

    for (var h in histories) {
      if (h['sana_vaqt'] != null) {
        try {
          DateTime transactionDate = DateTime.parse(h['sana_vaqt'].toString());
          String transactionDay = DateFormat('yyyy-MM-dd').format(transactionDate);

          dailyTransactions[transactionDay] ??= [];

          dailyTransactions[transactionDay]!.add({
            'name': h['name'] ?? 'Noma\'lum mahsulot',
            'quantity': h['quantity'] ?? 0,
            'summa': double.tryParse(h['summa'].toString()) ?? 0.0,
          });
        } catch (e) {
          continue;
        }
      }
    }

    if (dailyTransactions.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 10),
          const Text('Kunlik Daromad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Expanded(
            child: Center(
              child: Text(
                'Daromad va mahsulot ma\'lumotlari topilmadi.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ),
        ],
      );
    }

    var sortedDays = dailyTransactions.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        const SizedBox(height: 10),
        const Text('Kunlik Daromad va Mahsulotlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: fetchHistories,
            child: ListView.builder(
              itemCount: sortedDays.length,
              itemBuilder: (context, index) {
                String day = sortedDays[index];
                List<Map<String, dynamic>> transactions = dailyTransactions[day]!;
                double totalRevenue = transactions.fold(0.0, (sum, item) => sum + (item['summa'] as double));

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ExpansionTile(
                    title: Text(
                      day,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
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
                          children: transactions.map((transaction) {
                            return ListTile(
                              leading: const Icon(Icons.shopping_cart, color: Colors.deepOrangeAccent),
                              title: Text(
                                transaction['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Miqdor: ${transaction['quantity']}, Summa: ${transaction['summa'].toStringAsFixed(2)} so‘m',
                                style: const TextStyle(color: Colors.black87),
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
      PrinterPage(histories: histories),
      dayMoneyPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text(
          '',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
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
              leading: const Icon(Icons.print),
              title: const Text('Printer'),
              selected: _selectedIndex == 3,
              onTap: () {
                _onItemTapped(3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Kunlik Daromad'),
              selected: _selectedIndex == 4,
              onTap: () {
                _onItemTapped(4);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Dastur haqida'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutUsPage()));
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: pages[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Market',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Tarix',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.print),
            label: 'Printer',
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
        type: BottomNavigationBarType.fixed, // fixed or shifting
      ),
    );
  }
}