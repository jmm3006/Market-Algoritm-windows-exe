import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' as esc_pos;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

// Asosiy sahifa vidjeti
class PrinterPage extends StatefulWidget {
  final List<Map<String, dynamic>> histories;

  const PrinterPage({super.key, required this.histories});

  @override
  _PrinterPageState createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  // Holat o'zgaruvchilari
  String _printStatus = 'Тайёр'; // O'zbek kirillcha
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<bool> _selectedItems = [];
  List<Map<String, dynamic>> _filteredHistories = [];
  bool _isPrinterAvailable = false;
  static const platform = MethodChannel('com.example.app/printer');

  // Modified line: Changed initial value to 338
  int _checkNumber = 338;
  static const String _kCheckNumberKey = 'newCheak';

  String _previewText = 'Олдиндан кўриш учун маҳсулот танланг...'; // O'zbek kirillcha

  @override
  void initState() {
    super.initState();
    _filteredHistories = List.from(widget.histories);
    _selectedItems = List<bool>.filled(widget.histories.length, false, growable: true);
    _loadCheckNumber();
    _checkPrinterAvailability();
    _searchController.addListener(_filterHistories);
    _textController.addListener(_previewSelectedItems);
  }

  @override
  void dispose() {
    _textController.removeListener(_previewSelectedItems);
    _textController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Modified line: Default value when loading from SharedPreferences is now 338
      _checkNumber = prefs.getInt(_kCheckNumberKey) ?? 338;
    });
    _previewSelectedItems();
  }

  Future<void> _saveCheckNumber(int number) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCheckNumberKey, number);
  }


  void _filterHistories() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredHistories = widget.histories.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
      _selectedItems = List<bool>.filled(_filteredHistories.length, false, growable: true);
    });
    _previewSelectedItems();
  }

  Future<void> _checkPrinterAvailability() async {
    try {
      final bool isAvailable = await platform.invokeMethod('checkPrinterAvailability');
      setState(() {
        _isPrinterAvailable = isAvailable;
        _printStatus = _isPrinterAvailable ? 'Принтер уланган' : 'Принтер топилмади'; // O'zbek kirillcha
      });
    } catch (e) {
      _updateStatus('Принтер текширишда хатолик: $e', isError: true); // O'zbek kirillcha
    }
  }

  List<Map<String, dynamic>> _getSelectedHistories() {
    List<Map<String, dynamic>> selected = [];
    for (int i = 0; i < _filteredHistories.length; i++) {
      if (_selectedItems.length > i && _selectedItems[i]) {
        selected.add(_filteredHistories[i]);
      }
    }
    return selected;
  }

  Future<void> _printSelectedHistories() async {
    if (!_isPrinterAvailable) {
      _updateStatus('Принтер уланмаган. Илтимос, уланишни текширинг.', isError: true); // O'zbek kirillcha
      return;
    }

    final selectedHistories = _getSelectedHistories();

    if (selectedHistories.isEmpty) {
      _updateStatus('Чоп этиш учун маҳсулот танланмаган.', isError: true); // O'zbek kirillcha
      return;
    }

    if (_textController.text.isEmpty) {
      _updateStatus('Илтимос, изоҳ киритинг. Бу майдон мажбурий.', isError: true); // O'zbek kirillcha
      return;
    }

    try {
      final profile = await esc_pos.CapabilityProfile.load();
      final generator = esc_pos.Generator(esc_pos.PaperSize.mm58, profile);
      final bytes = _generateReceiptData(generator, selectedHistories);

      await platform.invokeMethod('printData', {'data': Uint8List.fromList(bytes)});

      _updateStatus('Муваффақиятли чоп этилди!', isSuccess: true); // O'zbek kirillcha
      _postActionCleanup();
    } catch (e) {
      _updateStatus('Чоп этишда хатолик: $e', isError: true); // O'zbek kirillcha
    }
  }

  Future<void> _generateAndSavePdf() async {
    final selectedHistories = _getSelectedHistories();

    if (selectedHistories.isEmpty) {
      _updateStatus('PDF яратиш учун маҳсулот танланмаган.', isError: true); // O'zbek kirillcha
      return;
    }
    if (_textController.text.isEmpty) {
      _updateStatus('Илтимос, PDF учун изоҳ киритинг. Бу мажбурий.', isError:true); // O'zbek kirillcha
      return;
    }

    final pdf = pw.Document();
    pw.Font? ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/CharisSILB.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (e) {
      _updateStatus('Шрифтни юклашда хато: $e', isError: true); // O'zbek kirillcha
      return;
    }

    final String currentDateTime = _formatCurrentDateTime();
    final int totalSum = _calculateTotalSum(selectedHistories);

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
                  "ALGORITM", // O'zbek kirillcha
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.SizedBox(
                width: double.infinity,
                child: pw.Text(
                    'Чек №${_checkNumber}', // O'zbek kirillcha
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)
                ),
              ),
              pw.Divider(height: 10, thickness: 1),
              ...selectedHistories.map((item) => _buildPdfRow('${item['name'] ?? 'N/A'}', '${item['price'] ?? 0} сўм', ttf!)), // "so'm" -> "сўм"
              pw.Divider(height: 10, thickness: 1),
              _buildPdfRow('ЖАМИ:', '$totalSum сўм', ttf!, isTotal: true), // "UMUMIY:" -> "ЖАМИ:", "so'm" -> "сўм"
              pw.SizedBox(height: 15),
              pw.Text('Вақт: $currentDateTime', style: pw.TextStyle(font: ttf, fontSize: 8)), // "Vaqt:" -> "Вақт:"
              pw.Text('Изоҳ: ${_textController.text}', style: pw.TextStyle(font: ttf, fontSize: 8)), // "Izoh:" -> "Изоҳ:"
              pw.SizedBox(height: 10),
              pw.Center(
                  child: pw.Text("Харидингиз учун раҳмат!", style: pw.TextStyle(font: ttf, fontSize: 8, fontStyle: pw.FontStyle.italic)) // O'zbek kirillcha
              )
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

      _updateStatus('PDF файл муваффақиятли сақланди!', isSuccess: true); // O'zbek kirillcha
      _postActionCleanup();
      await OpenFilex.open(file.path);
    } catch (e) {
      _updateStatus('PDF файлини сақлашда ёки очишда хатолик: $e', isError: true); // O'zbek kirillcha
    }
  }

  void _postActionCleanup() {
    setState(() {
      _checkNumber++;
      _saveCheckNumber(_checkNumber);
      _selectedItems = List<bool>.filled(_filteredHistories.length, false, growable: true);
      _textController.clear();
      _previewText = 'Олдиндан кўриш учун маҳсулот танланг...'; // O'zbek kirillcha
    });
  }

  void _updateStatus(String message, {bool isError = false, bool isSuccess = false}) {
    setState(() {
      _printStatus = message;
    });
    if (isError) {
      _showErrorDialog(message);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Хатолик!'), // O'zbek kirillcha
            ],
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('ОК'), // O'zbek kirillcha
            ),
          ],
        );
      },
    );
  }

  String _generatePreviewText(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return 'Ҳеч нарса танланмаган.'; // O'zbek kirillcha
    }
    final buffer = StringBuffer();
    final currentDateTime = _formatCurrentDateTime();
    final totalSum = _calculateTotalSum(items);

    buffer.writeln('ALGORITM'.padLeft(15)); // O'zbek kirillcha
    buffer.writeln('ЧЕК №${_checkNumber + 1}'.padLeft(15)); // O'zbek kirillcha
    buffer.writeln('--------------------------------');
    for (final item in items) {
      final name = item['name'] ?? 'N/A';
      final price = item['price'] ?? 0;
      buffer.writeln('${name.toString().padRight(18)} ${price.toString().padLeft(8)} сўм'); // "so'm" -> "сўм"
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('ЖАМИ СУММА: $totalSum сўм'.padLeft(15)); // O'zbek kirillcha, "so'm" -> "сўм"
    buffer.writeln('Вақт: $currentDateTime'); // O'zbek kirillcha
    if(_textController.text.isNotEmpty) {
      buffer.writeln('Изоҳ: ${_textController.text}'); // O'zbek kirillcha
    }
    buffer.writeln('\nХаридингиз учун раҳмат!'.padLeft(15)); // O'zbek kirillcha
    return buffer.toString();
  }

  void _previewSelectedItems() {
    final selected = _getSelectedHistories();
    setState(() {
      _previewText = _generatePreviewText(selected);
    });
  }

  int _calculateTotalSum(List<Map<String, dynamic>> items) {
    return items.fold(0, (sum, item) => sum + (int.tryParse(item['price'].toString()) ?? 0));
  }

  String _formatCurrentDateTime() {
    return DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
  }

  List<int> _generateReceiptData(esc_pos.Generator generator, List<Map<String, dynamic>> selectedHistories) {
    List<int> bytes = [];
    final String currentDateTime = _formatCurrentDateTime();
    final int totalSum = _calculateTotalSum(selectedHistories);

    bytes += generator.text('ALGORITM', styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center, bold: true, height: esc_pos.PosTextSize.size2, width: esc_pos.PosTextSize.size2)); // O'zbek kirillcha
    bytes += generator.text('Чек №${_checkNumber}', styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center, bold: true)); // O'zbek kirillcha
    bytes += generator.hr();
    for (var item in selectedHistories) {
      bytes += generator.row([
        esc_pos.PosColumn(
          text: '${item['name'] ?? 'N/A'}',
          width: 8,
          styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left),
        ),
        esc_pos.PosColumn(
          text: '${item['price'] ?? 0} сўм', // "so'm" -> "сўм"
          width: 4,
          styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.right),
        ),
      ]);
    }
    bytes += generator.hr();
    bytes += generator.text('Жами: $totalSum сўм', styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.right, bold: true, height: esc_pos.PosTextSize.size2, width: esc_pos.PosTextSize.size2)); // "Umumiy:" -> "Жами:", "so'm" -> "сўм"
    bytes += generator.text('Вақт: $currentDateTime', styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left, height: esc_pos.PosTextSize.size1, width: esc_pos.PosTextSize.size1)); // O'zbek kirillcha
    if(_textController.text.isNotEmpty) {
      bytes += generator.text('Изоҳ: ${_textController.text}', styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left)); // O'zbek kirillcha
    }
    bytes += generator.feed(1);
    bytes += generator.text('Харидингиз учун раҳмат!', styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center)); // O'zbek kirillcha
    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
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
                    fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal
                ),
              )
          ),
          pw.Text(
              value,
              style: pw.TextStyle(
                  font: font,
                  fontSize: isTotal ? 9 : 8,
                  fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal
              )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Row(
        children: [
          _buildPreviewPanel(),
          Expanded(
            child: Shortcuts(
              shortcuts: <ShortcutActivator, Intent>{
                const SingleActivator(LogicalKeyboardKey.keyP, control: true): const PrintIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  PrintIntent: CallbackAction<PrintIntent>(onInvoke: (intent) => _printSelectedHistories()),
                },
                child: Focus(
                  autofocus: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: _buildControlsPanel(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusCard(),
        const SizedBox(height: 16),
        _buildSearchField(),
        const SizedBox(height: 16),
        _buildHistoryList(),
        const SizedBox(height: 16),
        _buildCommentField(),
        const SizedBox(height: 16),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildStatusCard() {
    bool isSuccess = _printStatus.contains('муваффақиятли') || _printStatus.contains('уланган'); // O'zbek kirillcha
    bool isError = _printStatus.contains('хато') || _printStatus.contains('топилмади') || _printStatus.contains('мажбурий'); // O'zbek kirillcha

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Босиб чиқариш панели', // O'zbek kirillcha
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_outline : isError ? Icons.error_outline : Icons.info_outline,
                  color: isSuccess ? Colors.green.shade600 : isError ? Colors.red.shade600 : Colors.blue.shade600,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _printStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSuccess ? Colors.green.shade700 : isError ? Colors.red.shade700 : Colors.blue.shade700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Маҳсулотларни қидириш', // O'zbek kirillcha
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    );
  }

  Widget _buildHistoryList() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1.0)
        ),
        child: _filteredHistories.isEmpty
            ? Center(
            child: Text(
              "Маҳсулотлар топилмади", // O'zbek kirillcha
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ))
            : ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          itemCount: _filteredHistories.length,
          itemBuilder: (context, index) {
            final item = _filteredHistories[index];
            final isSelected = _selectedItems.length > index && _selectedItems[index];
            return Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                title: Text(
                  item['name'] ?? 'N/A',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                  ),
                ),
                subtitle: Text('Миқдор: ${item['quantity'] ?? 0}, Нарх: ${item['price'] ?? 0} сўм'), // O'zbek kirillcha, "so'm" -> "сўм"
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if(_selectedItems.length > index) {
                      _selectedItems[index] = value ?? false;
                    }
                  });
                  _previewSelectedItems();
                },
                activeColor: Theme.of(context).primaryColor,
                tileColor: isSelected ? Theme.of(context).primaryColor.withOpacity(0.08) : null,
                controlAffinity: ListTileControlAffinity.leading,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCommentField() {
    return TextField(
      controller: _textController,
      decoration: InputDecoration(
        labelText: 'Изоҳ (Мажбурий)', // O'zbek kirillcha
        hintText: 'Чоп этиш ёки PDF учун изоҳ киритинг', // O'zbek kirillcha
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      maxLines: 2,
      minLines: 1,
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _printSelectedHistories,
                icon: const Icon(Icons.print_outlined, size: 20),
                label: const Text('Чоп этиш', style: TextStyle(fontSize: 16)), // O'zbek kirillcha
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _generateAndSavePdf,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                label: const Text('PDF сақлаш', style: TextStyle(fontSize: 16)), // O'zbek kirillcha
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewPanel() {
    return Container(
      width: 320,
      margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.grey.shade300)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  "Чекни кўриш", // O'zbek kirillcha
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800]
                  ),
                )
              ],
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _previewText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrintIntent extends Intent {
  const PrintIntent();
}