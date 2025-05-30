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
  final TextEditingController _searchController = TextEditingController(); // Controller for search input
  List<bool> _selectedItems = [];
  List<Map<String, dynamic>> _filteredHistories = []; // List to hold filtered histories
  bool _isPrinterAvailable = false;
  static const platform = MethodChannel('com.example.app/printer');
  int checkNumber = 3881; // Initial check number

  @override
  void initState() {
    super.initState();
    _filteredHistories = List.from(widget.histories); // Initialize filtered list with all histories
    _selectedItems = List<bool>.filled(widget.histories.length, false);
    _checkPrinterAvailability();

    // Add listener to search controller to filter histories
    _searchController.addListener(_filterHistories);
  }

  @override
  void dispose() {
    _textController.dispose();
    _searchController.dispose(); // Dispose search controller
    super.dispose();
  }

  void _filterHistories() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredHistories = widget.histories.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
      // Reset selected items for the new filtered list
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
    // Iterate over the original histories to get selected items, as _selectedItems refers to the filtered list's indices
    for (int i = 0; i < _selectedItems.length; i++) {
      if (_selectedItems[i]) {
        // Find the corresponding item in the original histories list
        selectedHistories.add(_filteredHistories[i]);
      }
    }

    if (selectedHistories.isEmpty) {
      setState(() {
        _printStatus = 'Iltimos, kamida bitta tarixiy elementni tanlang.';
      });
      return;
    }

    // --- START: Mandatory comment check for printing ---
    if (_textController.text.isEmpty) {
      setState(() {
        _printStatus = 'Iltimos, chop etish uchun izoh kiriting. Izoh majburiy.'; // Added mandatory message
      });
      return;
    }
    // --- END: Mandatory comment check for printing ---

    try {
      final profile = await esc_pos.CapabilityProfile.load();
      final generator = esc_pos.Generator(esc_pos.PaperSize.mm58, profile);

      // --- Load your logo here (if needed for thermal printer) ---
      // final ByteData logoBytes = await rootBundle.load('assets/logo.png'); // Example path
      // final Uint8List logoPng = logoBytes.buffer.asUint8List();
      // final esc_pos.Image logoBitmap = esc_pos.Image(img.decodeImage(logoPng)!);
      // --- End of logo loading ---

      for (var item in selectedHistories) {
        List<int> bytes = [];

        String formattedDateTime = 'N/A';
        if (item['sana_vaqt'] != null) {
          DateTime? originalDateTime = DateTime.tryParse(item['sana_vaqt'].toString());
          if (originalDateTime != null) {
            // Adjust for +5 hours (Tashkent time) if your data is in UTC or a different timezone
            DateTime adjustedDateTime = originalDateTime.add(const Duration(hours: 5));
            formattedDateTime = DateFormat('dd.MM.yyyy HH:mm').format(adjustedDateTime);
          } else {
            formattedDateTime = item['sana_vaqt'].toString();
          }
        }

        // Add logo (uncomment and use if you have a logo loaded)
        // if (logoBitmap != null) {
        //   bytes += generator.image(logoBitmap);
        //   bytes += generator.feed(1);
        // }

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

        // For thermal printing, you need to manually handle bolding for labels if fontType.fontB isn't enough
        bytes += generator.text('Чек рақами: No.${checkNumber}', // Cyrillic and bold
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('Компания: Algoritm Group', // Cyrillic and bold
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('Маҳсулот: ${item['name'] ?? 'N/A'}', // Cyrillic and bold
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('Нарх: ${item['price'] ?? 0} som', // Cyrillic and bold
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('Тўлов суммаси: ${item['summa'] ?? 0} som', // Cyrillic and bold
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('Кассир: Rajabova Asem', // Cyrillic and bold
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('Вақт: $formattedDateTime', // Cyrillic and bold
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.text('телефон рақами: +998905908445', // Cyrillic and bold
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));

        // Only include user-entered comment from _textController.text for thermal printer
        // Now it's guaranteed to be non-empty due to the check above
        bytes += generator.text('Изоҳ: ${_textController.text}', // Cyrillic and bold comment
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, bold: true, fontType: esc_pos.PosFontType.fontB));

        bytes += generator.text('-----------------------------',
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center));
        bytes += generator.text('Квитанцияни сақланг', // Cyrillic and bold
            styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center, bold: true, fontType: esc_pos.PosFontType.fontB));
        bytes += generator.feed(2);
        bytes += generator.cut();

        await platform.invokeMethod('printData', {'data': bytes});
        checkNumber++; // Increment check number for each printed receipt
      }

      setState(() {
        _printStatus = 'Chop etish muvaffakiyatli amalga oshirildi!'; // Cyrillic
        // After printing, reset selected items and filter
        _selectedItems = List<bool>.filled(_filteredHistories.length, false);
        _filterHistories(); // Re-filter to update the list if search query is active
      });
    } catch (e) {
      setState(() {
        _printStatus = 'Chop etish muwaffakiyatsiz tugadi: $e'; // Cyrillic
      });
      print('Chop etishda xato: $e');
    }
  }

  Future<void> _printCustomText() async {
    if (!_isPrinterAvailable) {
      setState(() {
        _printStatus = 'Printer mavjud emas. Avval printerni ulanishini ta\'minlash.'; // Cyrillic
      });
      return;
    }

    if (_textController.text.isEmpty) {
      setState(() {
        _printStatus = 'Iltimos, chop etish uchun matn kiriting.'; // Cyrillic
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
        _printStatus = 'Maxsus matn muvaffakiyatli chop etildi!'; // Cyrillic
        _textController.clear();
      });
    } catch (e) {
      setState(() {
        _printStatus = 'Maxsus matni chop etish muvaffakiyatsiz tugadi: $e'; // Cyrillic
      });
    }
  }

  Future<void> _generateAndSavePdf(List<Map<String, dynamic>> dataToPrint) async {
    if (dataToPrint.isEmpty) {
      setState(() {
        _printStatus = 'Iltimos, PDF uchun kamida bitta tarixiy elementni tanlash.'; // Cyrillic
      });
      return;
    }

    // --- START: Mandatory comment check for PDF generation ---
    if (_textController.text.isEmpty) {
      setState(() {
        _printStatus = 'Iltimos, PDF yaratish uchun izoh kiriting. Izoh majburiy.'; // Added mandatory message
      });
      return;
    }
    // --- END: Mandatory comment check for PDF generation ---

    final pdf = pw.Document();
    const double mmToPoint = 2.83465;
    const double pageWidthMm = 58.0;
    const double pageHeightMm = 150.0; // Adjust as needed, will expand if content is long

    pw.Font ttf;
    try {
      // Load the font from your assets. Ensure this path is correct and the font supports Cyrillic.
      final fontData = await DefaultAssetBundle.of(context).load('assets/fonts/CharisSILB.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (e) {
      setState(() {
        _printStatus = 'PDF uchun shrift yuklashda xato: $e. Shrift tugri zhoylashganligini va pubspec.yaml yes ku shaxsiyligini.'; // Cyrillic
      });
      print('PDF font loading error: $e');
      return; // Exit if font loading fails
    }


    // --- Load logo for PDF (if needed) ---
    // final ByteData logoBytes = await rootBundle.load('assets/logo.png'); // Example path
    // final Uint8List logoPng = logoBytes.buffer.asUint8List();
    // final pw.MemoryImage pdfLogoImage = pw.MemoryImage(logoPng);
    // --- End of logo loading ---

    for (var item in dataToPrint) {
      String formattedDateTime = 'N/A';
      if (item['sana_vaqt'] != null) {
        DateTime? originalDateTime = DateTime.tryParse(item['sana_vaqt'].toString());
        if (originalDateTime != null) {
          DateTime adjustedDateTime = originalDateTime.add(const Duration(hours: 5)); // Adjust for +5 hours
          formattedDateTime = DateFormat('dd.MM.yyyy HH:mm').format(adjustedDateTime);
        } else {
          formattedDateTime = item['sana_vaqt'].toString();
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            pageWidthMm * mmToPoint,
            pageHeightMm * mmToPoint,
          ),
          margin: const pw.EdgeInsets.all(5 * mmToPoint), // Smaller margins for 58mm
          build: (pw.Context context) {
            // Decide what to show for "Izoh"
            pw.Widget commentSection;
            // Now it's guaranteed to be non-empty due to the check above
            commentSection = pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Divider(), // Add a divider before comment if it exists
                pw.Text(
                  'Изоҳ: ${_textController.text}', // Cyrillic label, bold for text
                  style: pw.TextStyle(font: ttf, fontSize: 9, fontWeight: pw.FontWeight.bold), // Bold comment
                ),
              ],
            );


            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Add logo for PDF (uncomment if you have a logo)
                // pw.Center(
                //   child: pw.Image(pdfLogoImage, width: 200, height: 200),
                // ),
                pw.SizedBox(height: 5), // Smaller spacing
                pw.Center(
                  child: pw.Text(
                    'ALGORITM',
                    style: pw.TextStyle(
                      fontSize: 14, // Slightly smaller main title for neatness
                      fontWeight: pw.FontWeight.bold,
                      font: ttf, // Apply the Cyrillic-supporting font
                    ),
                  ),
                ),
                pw.Divider(),
                pw.SizedBox(height: 5), // Smaller spacing
                _buildPdfRow('Чек рақами:', 'No.${checkNumber}', ttf), // Cyrillic
                _buildPdfRow('Компания:', 'Algoritm Group', ttf), // Cyrillic
                _buildPdfRow('Маҳсулот:', item['name'] ?? 'N/A', ttf), // Cyrillic
                _buildPdfRow('Нарх:', '${item['price'] ?? 0} som', ttf), // Cyrillic
                _buildPdfRow('Тўлов суммаси:', '${item['summa'] ?? 0} som', ttf), // Cyrillic
                _buildPdfRow('Кассир:', 'Rajabova Asem', ttf), // Cyrillic
                _buildPdfRow('Вақт:', formattedDateTime, ttf), // Cyrillic
                _buildPdfRow('телефон рақами:', '+998905908445', ttf), // Cyrillic

                commentSection, // Insert the comment section (will be hidden if empty)

                pw.Divider(),
                pw.Center(
                  child: pw.Text(
                    'Квитанцияни сақланг', // Cyrillic
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: ttf, // Apply the font
                      fontSize: 10, // Smaller font for "Kvitansiyani saqlang"
                    ),
                  ),
                ),
                pw.SizedBox(height: 10), // Smaller spacing at the end
              ],
            );
          },
        ),
      );
      checkNumber++; // Increment check number for each PDF page
    }

    final output = await getTemporaryDirectory();
    final fileName = "chek_raport_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final file = File("${output.path}/$fileName");

    print('Attempting to save PDF to: ${file.path}'); // Debugging line
    await file.writeAsBytes(await pdf.save());
    print('PDF saved successfully to: ${file.path}'); // Debugging line

    setState(() {
      _printStatus = 'PDF muwaffakiyatli saqlandi: $fileName'; // Cyrillic
      // After PDF generation, reset selected items and filter
      _selectedItems = List<bool>.filled(_filteredHistories.length, false);
      _filterHistories(); // Re-filter to update the list if search query is active
    });

    await OpenFilex.open(file.path);
  }

  // Updated _buildPdfRow for better layout and consistent bolding
  pw.Widget _buildPdfRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1), // Reduced vertical padding
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start, // Align top if content wraps
        children: [
          // Left side (label)
          // Adjust width as needed for your 58mm printer.
          // This width is in PDF points. 1mm = 2.83465 points.
          // For example, 25mm * 2.83465 = 70.86 points for the label column.
          pw.SizedBox(
            width: 25 * 2.83465, // Fixed width for label to prevent wrapping of label itself
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                font: font,
                fontSize: 9, // Consistent smaller font size for labels
              ),
              textAlign: pw.TextAlign.left,
            ),
          ),
          pw.SizedBox(width: 2 * 2.83465), // Small gap between label and value (2mm)
          // Right side (value)
          pw.Expanded( // Allows value to take remaining space and wrap
            child: pw.Text(
              value,
              style: pw.TextStyle(font: font, fontSize: 9), // Consistent smaller font size for values
              textAlign: pw.TextAlign.right, // Align value to the right
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
            appBar: AppBar(
              title: const Text('Printer'),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Chop uchun tarixiy mahsulotlarni tanlash (Ctrl + P bilan yozishlarni chop etish)', // Cyrillic
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _printStatus,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: _printStatus.contains('muvaffaqiyatli') // Cyrillic
                                  ? Colors.green
                                  : _printStatus.contains('xato') || _printStatus.contains('topilmadi') || _printStatus.contains('majburiy') // Cyrillic
                                  ? Colors.red
                                  : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Search input field
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Mahsulot nomini qidirish', // Cyrillic
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
                      itemCount: _filteredHistories.length, // Use filtered list
                      itemBuilder: (context, index) {
                        final item = _filteredHistories[index]; // Use item from filtered list
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                          elevation: 2,
                          child: CheckboxListTile(
                            title: Text(
                              '${item['name'] ?? 'N/A'} - ${item['summa'] ?? 0} som',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                                'Миқдор: ${item['quantity'] ?? 0}, Нарх: ${item['price'] ?? 0} som'), // Cyrillic
                            value: _selectedItems[index],
                            onChanged: (bool? value) {
                              setState(() {
                                _selectedItems[index] = value ?? false;
                              });
                            },
                            activeColor: Colors.blueAccent,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      labelText: 'Chop etish uchun izoh kiriting (Majburiy)', // Cyrillic - Updated label
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _printCustomText,
                          icon: const Icon(Icons.print),
                          label: const Text('Mahsus matni chop etish'), // Cyrillic
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                          label: const Text('Tanlanganlarni chop etish'), // Cyrillic
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                          selectedHistories.add(_filteredHistories[i]); // Use item from filtered list
                        }
                      }
                      // The mandatory comment check is now inside _generateAndSavePdf
                      await _generateAndSavePdf(selectedHistories);
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Tanlanganlarni PDF qilib saqlang'), // Cyrillic
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
