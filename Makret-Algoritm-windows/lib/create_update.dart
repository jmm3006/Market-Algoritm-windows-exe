import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminPage extends StatefulWidget {
  final Function(String action, Map<String, dynamic> productData) onProductOperation;
  final bool isLoading;
  final List<dynamic> marketData;
  final VoidCallback onRefreshMarkets;
  final Function(String status, {String? message}) onShowStatusAnimation;

  const AdminPage({
    super.key,
    required this.onProductOperation,
    required this.isLoading,
    required this.marketData,
    required this.onRefreshMarkets,
    required this.onShowStatusAnimation,
  });

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _createFormKey = GlobalKey<FormState>();
  final TextEditingController _createNameController = TextEditingController();
  final TextEditingController _createPriceController = TextEditingController();
  final TextEditingController _createMuchController = TextEditingController();
  final Map<String, TextEditingController> _muchControllers = {};
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredMarketData = [];

  @override
  void initState() {
    super.initState();
    _updateMuchControllers();
    _filteredMarketData = List.from(widget.marketData);
    _searchController.addListener(_onSearchChanged);
  }

  void _updateMuchControllers() {
    _muchControllers.forEach((key, controller) => controller.dispose());
    _muchControllers.clear();
    for (var product in widget.marketData) {
      final productName = product['name'].toString();
      _muchControllers[productName] = TextEditingController(text: '0');
    }
  }

  @override
  void didUpdateWidget(covariant AdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.marketData.length != oldWidget.marketData.length ||
        !_listEquals(widget.marketData, oldWidget.marketData)) {
      _updateMuchControllers();
      _filterMarketData();
    }
  }

  bool _listEquals(List<dynamic> list1, List<dynamic> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i]['name'] != list2[i]['name']) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _createNameController.dispose();
    _createPriceController.dispose();
    _createMuchController.dispose();
    _muchControllers.forEach((key, controller) => controller.dispose());
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterMarketData();
  }

  void _filterMarketData() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMarketData = List.from(widget.marketData);
      } else {
        _filteredMarketData = widget.marketData.where((product) {
          final productName = product['name']?.toString().toLowerCase() ?? '';
          return productName.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _showUpdatePriceDialog(String productName, double currentPrice) async {
    final TextEditingController priceController = TextEditingController(text: currentPrice.toString());
    final _dialogFormKey = GlobalKey<FormState>();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // Dialog burchaklarini yumaloqlash
          title: Text(
            'Narxni yangilash: $productName',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrangeAccent),
          ),
          content: Form(
            key: _dialogFormKey,
            child: TextFormField(
              controller: priceController,
              decoration: InputDecoration(
                labelText: 'Yangi narx',
                hintText: 'Misol: 12500.50',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Narx kiritilishi shart';
                final double? parsed = double.tryParse(value);
                if (parsed == null || parsed <= 0) return 'Musbat raqam kiriting';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_dialogFormKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrangeAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Yangilash'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      widget.onProductOperation('updateProductPrice', {
        'name': productName,
        'price': priceController.text,
      });
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _createProduct() {
    if (_createFormKey.currentState!.validate()) {
      widget.onProductOperation('createProduct', {
        'name': _createNameController.text.trim(),
        'price': _createPriceController.text.trim(),
        'quantity': _createMuchController.text.trim(),
      });
      _createNameController.clear();
      _createPriceController.clear();
      _createMuchController.clear();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _subtractProductQuantity(String name, TextEditingController controller, int currentMuch) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value <= 0) {
      widget.onShowStatusAnimation('success', message: 'To‘g‘ri miqdor kiriting');
      return;
    }
    if (value > currentMuch) {
      widget.onShowStatusAnimation('success', message: 'Yetarli miqdor mavjud emas');
      return;
    }

    widget.onProductOperation('subtractProductQuantity', {
      'name': name,
      'quantity': value,
    });
    controller.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _addProductQuantity(String name, TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value <= 0) {
      widget.onShowStatusAnimation('success', message: 'To‘g‘ri miqdor kiriting');
      return;
    }

    widget.onProductOperation('addProductQuantity', {
      'name': name,
      'quantity': value,
    });
    controller.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Yangi mahsulot yaratish qismi
          const Text(
            'Yangi mahsulot qo‘shish',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange, // Rangni o'zgartirdik
            ),
          ),
          const SizedBox(height: 20), // Bo'sh joyni oshirdik
          Form(
            key: _createFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _createNameController,
                  decoration: InputDecoration(
                    labelText: 'Mahsulot nomi',
                    hintText: 'Misol: Olma',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), // Chegarani yumaloqlash
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.deepOrangeAccent, width: 2), // Fokuslanganda rang va qalinlik
                    ),
                    prefixIcon: const Icon(Icons.shopping_bag_outlined, color: Colors.grey), // Icon qo'shdik
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Nom kiritilsin' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _createPriceController,
                  decoration: InputDecoration(
                    labelText: 'Narxi (so‘m)',
                    hintText: 'Misol: 15000.50',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.deepOrangeAccent, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.attach_money, color: Colors.grey), // Icon qo'shdik
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  validator: (value) {
                    final double? parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) return 'To‘g‘ri narx kiriting';
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _createMuchController,
                  decoration: InputDecoration(
                    labelText: 'Miqdori',
                    hintText: 'Misol: 100',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.deepOrangeAccent, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.production_quantity_limits, color: Colors.grey), // Icon qo'shdik
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    final int? parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed < 0) return 'Miqdor musbat bo‘lsin';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon( // Iconli tugma
                  onPressed: widget.isLoading ? null : _createProduct,
                  icon: const Icon(Icons.add_shopping_cart), // Icon
                  label: widget.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Mahsulot qo‘shish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrangeAccent, // Rangni o'zgartirdik
                    foregroundColor: Colors.white, // Matn rangini oq qildik
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // Burchaklarni yumaloqlash
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), // Matn stilini o'zgartirdik
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Divider(thickness: 1.5, color: Colors.deepOrangeAccent), // Ajratuvchi chiziq
          const SizedBox(height: 20),

          // Mahsulotlarni boshqarish qismi
          const Text(
            'Mavjud mahsulotlar',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Mahsulot nomini qidirish',
                hintText: 'Misol: qalam',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _filterMarketData();
                    FocusScope.of(context).unfocus();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100], // Fon rangini o'zgartirdik
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (widget.isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: Colors.deepOrangeAccent),
            ))
          else if (_filteredMarketData.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Hech qanday mahsulot topilmadi.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredMarketData.length,
              itemBuilder: (context, index) {
                final product = _filteredMarketData[index];
                final String name = product['name'];
                final double price = product['price'].toDouble();
                final int much = product['quantity'].toInt();
                final controller = _muchControllers[name]!;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 6, // Card balandligini oshirdik
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // Burchaklarni yumaloqlash
                  child: Padding(
                    padding: const EdgeInsets.all(15), // Paddingni oshirdik
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange, // Mahsulot nomi rangini o'zgartirdik
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Narxi: ${price.toStringAsFixed(2)} so‘m',
                              style: const TextStyle(fontSize: 15, color: Colors.black87),
                            ),
                            OutlinedButton.icon( // Narx yangilash tugmasini o'zgartirdik
                              onPressed: () => _showUpdatePriceDialog(name, price),
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Narxni o‘zgartirish'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue.shade700, // Matn va icon rangini o'zgartirdik
                                side: BorderSide(color: Colors.blue.shade300), // Chegarani rangini o'zgartirdik
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(color: Colors.grey.shade300, thickness: 1), // Kichik ajratuvchi chiziq
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Omborda: ${much} dona',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green), // Miqdor rangini yashil qildik
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10), // Paddingni oshirdik
                                child: TextFormField(
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    hintText: 'Miqdor',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Colors.deepOrangeAccent, width: 1.5),
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 28), // Rang va o'lcham
                                  onPressed: () => _subtractProductQuantity(name, controller, much),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: Colors.greenAccent, size: 28), // Rang va o'lcham
                                  onPressed: () => _addProductQuantity(name, controller),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 50), // Pastki qismda bo'sh joy
        ],
      ),
    );
  }
}