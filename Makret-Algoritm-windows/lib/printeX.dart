import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' as esc_pos;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';

class PrinterPage extends StatefulWidget {
  final List<Map<String, dynamic>> histories;

  const PrinterPage({super.key, required this.histories});

  @override
  _PrinterPageState createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  String _printStatus = 'Idle';
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<bool> _selectedItems = [];
  List<Map<String, dynamic>> _filteredHistories = [];
  bool _isPrinterAvailable = false;
  static const platform = MethodChannel('com.example.app/printer');
  int checkNumber = 3881;

  @override
  void initState() {
    super.initState();
    _filteredHistories = List.from(widget.histories);
    _selectedItems = List<bool>.filled(widget.histories.length, false);
    _checkPrinterAvailability();
    _searchController.addListener(_filterHistories);
  }

  @override
  void dispose() {
    _textController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterHistories() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredHistories = widget.histories.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
      _selectedItems = List<bool>.filled(_filteredHistories.length, false);
    });
  }

  Future<void> _checkPrinterAvailability() async {
    try {
      final bool isAvailable = await platform.invokeMethod('checkPrinterAvailability');
      setState(() {
        _isPrinterAvailable = isAvailable;
        _printStatus = _isPrinterAvailable ? 'Printer mavjud' : 'Printer topilmadi';
      });
    } catch (e) {
      setState(() {
        _printStatus = 'Printerni tekshirishda xato: $e';
      });
      print('Printer mavjudligini tekshirishda xato: $e');
    }
  }

  Future<void> _printSelectedHistories() async {
    if (!_isPrinterAvailable) {
      setState(() {
        _printStatus = 'Printer mavjud emas. Avval printerni ulanishini tekshiring.';
      });
      return;
    }

    List<Map<String, dynamic>> selectedHistories = [];
    for (int i = 0; i < _selectedItems.length; i++) {
      if (_selectedItems[i]) {
        selectedHistories.add(_filteredHistories[i]);
      }
    }

    if (selectedHistories.isEmpty) {
      setState(() {
        _printStatus = 'Iltimos, kamida bitta tarixiy elementni tanlang.';
      });
      return;
    }

    if (_textController.text.isEmpty) {
      setState(() {
        _printStatus = 'Iltimos, chop etish uchun izoh kiriting. Izoh majburiy.';
      });
      return;
    }

    try {
      final profile = await esc_pos.CapabilityProfile.load();
      final generator = esc_pos.Generator(esc_pos.PaperSize.mm58, profile);

      for (var item in selectedHistories) {
        List<int> bytes = [];
        String formattedDateTime = 'N/A';
        if (item['sana_vaqt'] != null) {
          DateTime? originalDateTime = DateTime.tryParse(item['sana_vaqt'].toString());
          if (originalDateTime != null) {
            DateTime adjustedDateTime = originalDateTime.add(const Duration(hours: 5));
            formattedDateTime = DateFormat('dd.MM.yyyy HH:mm').format(adjustedDateTime);
          } else {
            formattedDateTime = item['sana_vaqt'].toString();
          }
        }

        bytes += generator.text('ALGORITM',
            styles: const esc_pos.PosStyles(
              align: esc_pos.PosAlign.center,
              height: esc_pos.PosTextSize.size2,
              width: esc_pos.PosTextSize.size2,
              fontType: esc_pos.PosFontType.fontB,
              bold: true,
            ));
        bytes += generator.text('-----------------------------',
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center));
        bytes += generator.text('Чек рақами: No.${checkNumber}',
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('Компания: Algoritm Group',
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('Маҳсулот: ${item['name'] ?? 'N/A'}',
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('Нарх: ${item['price'] ?? 0} som',
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('Тўлов суммаси: ${item['summa'] ?? 0} som',
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('Кассир: Rajabova Asem',
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('Вақт: $formattedDateTime',
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('телефон рақами: +998905908445',
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('Изоҳ: ${_textController.text}',
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('-----------------------------',
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center));
        bytes += generator.text('Квитанцияни сақланг',
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.feed(2);
        bytes += generator.cut();

        await platform.invokeMethod('printData', {'data': bytes});
        checkNumber++;
      }

      setState(() {
        _printStatus = 'Chop etish muvaffakiyatli amalga oshirildi!';
        _selectedItems = List<bool>.filled(_filteredHistories.length, false);
        _filterHistories();
      });
    } catch (e) {
      setState(() {
        _printStatus = 'Chop etish muwaffakiyatsiz tugadi: $e';
      });
      print('Chop etishda xato: $e');
    }
  }

  Future<void> _printCustomText() async {
    if (!_isPrinterAvailable) {
      setState(() {
        _printStatus = 'Printer mavjud emas. Avval printerni ulanishini ta\'minlash.';
      });
      return;
    }

    if (_textController.text.isEmpty) {
      setState(() {
        _printStatus = 'Iltimos, chop etish uchun matn kiriting.';
      });
      return;
    }

    try {
      final profile = await esc_pos.CapabilityProfile.load();
      final generator = esc_pos.Generator(esc_pos.PaperSize.mm58, profile);

      List<int> bytes = [];
      bytes += generator.text(_textController.text,
          styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, fontType: esc_pos.PosFontType.fontB));
      bytes += generator.feed(2);
      bytes += generator.cut();

      await platform.invokeMethod('printData', {'data': bytes});

      setState(() {
        _printStatus = 'Maxsus matn muvaffakiyatli chop etildi!';
        _textController.clear();
      });
    } catch (e) {
      setState(() {
        _printStatus = 'Maxsus matni chop etish muvaffakiyatsiz tugadi: $e';
      });
    }
  }

  Future<void> _generateAndSavePdf(List<Map<String, dynamic>> dataToPrint) async {
    if (dataToPrint.isEmpty) {
      setState(() {
        _printStatus = 'Iltimos, PDF uchun kamida bitta tarixiy elementni tanlash.';
      });
      return;
    }

    if (_textController.text.isEmpty) {
      setState(() {
        _printStatus = 'Iltimos, PDF yaratish uchun izoh kiriting. Izoh majburiy.';
      });
      return;
    }

    final pdf = pw.Document();
    const double mmToPoint = 2.83465;
    const double pageWidthMm = 58.0;
    const double pageHeightMm = 150.0;

    pw.Font ttf;
    try {
      final fontData = await DefaultAssetBundle.of(context).load('assets/fonts/CharisSILB.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (e) {
      setState(() {
        _printStatus = 'PDF uchun shrift yuklashda xato: $e. Shrift tugri joylashganligini va pubspec.yamlni tekshiring.';
      });
      print('PDF font loading error: $e');
      return;
    }

    for (var item in dataToPrint) {
      String formattedDateTime = 'N/A';
      if (item['sana_vaqt'] != null) {
        DateTime? originalDateTime = DateTime.tryParse(item['sana_vaqt'].toString());
        if (originalDateTime != null) {
          DateTime adjustedDateTime = originalDateTime.add(const Duration(hours: 5));
          formattedDateTime = DateFormat('dd.MM.yyyy HH:mm').format(adjustedDateTime);
        } else {
          formattedDateTime = item['sana_vaqt'].toString();
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageWidthMm * mmToPoint, pageHeightMm * mmToPoint),
          margin: const pw.EdgeInsets.all(5 * mmToPoint),
          build: (pw.Context context) {
            pw.Widget commentSection = pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Divider(),
                pw.Text(
                  'Изоҳ: ${_textController.text}',
                  style: pw.TextStyle(font: ttf, fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ],
            );

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'ALGORITM',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: ttf),
                  ),
                ),
                pw.Divider(),
                pw.SizedBox(height: 5),
                _buildPdfRow('Чек рақами:', 'No.${checkNumber}', ttf),
                _buildPdfRow('Компания:', 'Algoritm Group', ttf),
                _buildPdfRow('Маҳсулот:', item['name'] ?? 'N/A', ttf),
                _buildPdfRow('Нарх:', '${item['price'] ?? 0} som', ttf),
                _buildPdfRow('Тўлов суммасi:', '${item['summa'] ?? 0} som', ttf),
                _buildPdfRow('Кассир:', 'Rajabova Asem', ttf),
                _buildPdfRow('Вақт:', formattedDateTime, ttf),
                _buildPdfRow('телефон рақами:', '+998905908445', ttf),
                commentSection,
                pw.Divider(),
                pw.Center(
                  child: pw.Text(
                    'Квитанцияни сақланг',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttf, fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 10),
              ],
            );
          },
        ),
      );
      checkNumber++;
    }

    final output = await getTemporaryDirectory();
    final fileName = "chek_raport_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final file = File("${output.path}/$fileName");
    await file.writeAsBytes(await pdf.save());

    setState(() {
      _printStatus = 'PDF muwaffaqiyatli saqlandi: $fileName';
      _selectedItems = List<bool>.filled(_filteredHistories.length, false);
      _filterHistories();
    });

    await OpenFilex.open(file.path);
  }

  pw.Widget _buildPdfRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 25 * 2.83465,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font, fontSize: 9),
              textAlign: pw.TextAlign.left,
            ),
          ),
          pw.SizedBox(width: 2 * 2.83465),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: font, fontSize: 9),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): const PrintIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          PrintIntent: CallbackAction<PrintIntent>(
            onInvoke: (intent) => _printSelectedHistories(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(

            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          const Text(
                            'Chop uchun tarixiy mahsulotlarni tanlash (Ctrl + P bilan yozishlarni chop etish)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _printStatus,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: _printStatus.contains('muvaffaqiyatli')
                                  ? Colors.green
                                  : _printStatus.contains('xato') || _printStatus.contains('topilmadi') || _printStatus.contains('majburiy')
                                  ? Colors.red
                                  : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Mahsulot nomini qidirish',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredHistories.length,
                      itemBuilder: (context, index) {
                        final item = _filteredHistories[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
                          elevation: 2,
                          color: _selectedItems[index] ? Colors.blueAccent.withOpacity(0.1) : null,
                          child: CheckboxListTile(
                            title: Text(
                              '${item['name'] ?? 'N/A'} - ${item['summa'] ?? 0} so‘m',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              'Миқдор: ${item['quantity'] ?? 0}, Нарх: ${item['price'] ?? 0} so‘m',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            value: _selectedItems[index],
                            onChanged: (bool? value) {
                              setState(() {
                                _selectedItems[index] = value ?? false;
                              });
                            },
                            activeColor: Colors.blueAccent,
                            checkColor: Colors.white,
                            tileColor: _selectedItems[index] ? Colors.blueAccent.withOpacity(0.1) : null,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      labelText: 'Chop etish uchun izoh kiriting (Majburiy)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _printCustomText,
                          icon: const Icon(Icons.print),
                          label: const Text('Mahsus matni chop etish'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _printSelectedHistories,
                          icon: const Icon(Icons.receipt),
                          label: const Text('Tanlanganlarni chop etish'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      List<Map<String, dynamic>> selectedHistories = [];
                      for (int i = 0; i < _selectedItems.length; i++) {
                        if (_selectedItems[i]) {
                          selectedHistories.add(_filteredHistories[i]);
                        }
                      }
                      await _generateAndSavePdf(selectedHistories);
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Tanlanganlarni PDF qilib saqlang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PrintIntent extends Intent {
  const PrintIntent();
}