import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'core_providers.dart';
import 'log_service.dart';

class ExportService {
  final SupabaseClient _client;
  final LogService? _logger;

  ExportService(this._client, [this._logger]);

  /// Sanitizes a string to be safe for use in file names.
  /// Removes path separators, directory traversal sequences, and
  /// any characters that aren't alphanumeric, underscore, or hyphen.
  String _sanitizeFilename(String input) {
    // Remove path separators and traversal sequences
    String safe = input
        .replaceAll(RegExp(r'[\\/]'), '_')  // Replace slashes
        .replaceAll(RegExp(r'\.{2,}'), '_') // Replace .. sequences
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_'); // Only safe chars
    // Prevent empty filenames
    if (safe.trim().isEmpty) safe = 'export';
    return safe;
  }

  /// Formats a timestamp to local IST string.
  String _formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      return DateFormat('dd-MM-yyyy HH:mm:ss').format(dt);
    } catch (e) {
      return timestamp.split('T').first; // Fallback to date part
    }
  }

  /// Delivers the file to the user based on the platform.
  /// On Web and Desktop, it uses FilePicker for direct download/save.
  /// On Mobile, it uses Share for the native sharing menu.
  Future<void> _deliverFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String shareTitle,
  }) async {
    final bool isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS);

    if (kIsWeb || isDesktop) {
      // Direct Download / Save As for Web and Desktop
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save Export',
        fileName: fileName,
        bytes: bytes,
      );
    } else {
      // Share Menu for Mobile
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
        text: shareTitle,
      );
    }
  }

  Future<void> exportSalesToExcel(int shopId, String shopName, {DateTime? startDate, DateTime? endDate}) async {
    var query = _client
        .from('sales_entries')
        .select('''
          *,
          parties (partyname),
          product_head (product_name),
          products_design (design_no)
        ''')
        .eq('shop_id', shopId);

    if (startDate != null) {
      query = query.gte('date', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('date', endDate.toIso8601String());
    }

    try {
      final response = await query.order('date', ascending: false);

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sales'];
      excel.setDefaultSheet('Sales');

      // Headers
      sheetObject.appendRow([
        TextCellValue('Date'),
        TextCellValue('Invoice No'),
        TextCellValue('Party Name'),
        TextCellValue('Product'),
        TextCellValue('Design No'),
        TextCellValue('Quantity'),
        TextCellValue('Rate'),
        TextCellValue('Amount')
      ]);

      for (var row in response) {
        final date = row['date']?.toString().split(' ').first ?? '';
        final invoice = row['invoiceno']?.toString() ?? '';
        final party = row['parties']?['partyname']?.toString() ?? '';
        final product = row['product_head']?['product_name']?.toString() ?? '';
        final design = row['products_design']?['design_no']?.toString() ?? '';
        final qty = row['quantity']?.toString() ?? '0';
        final rate = row['rate']?.toString() ?? '0';
        final amount = row['amount']?.toString() ?? '0';

        sheetObject.appendRow([
          TextCellValue(date),
          TextCellValue(invoice),
          TextCellValue(party),
          TextCellValue(product),
          TextCellValue(design),
          TextCellValue(qty),
          TextCellValue(rate),
          TextCellValue(amount),
        ]);
      }

      final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final safeName = _sanitizeFilename(shopName);
      final fileName = '${safeName}_Sales_$dateStr.xlsx';
      final byteData = Uint8List.fromList(excel.encode()!);

      await _deliverFile(
        bytes: byteData,
        fileName: fileName,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        shareTitle: 'Sales Export for $shopName',
      );

      _logger?.success('Export', 'Successfully exported Sales to Excel');
    } catch (e, stack) {
       _logger?.error('Export', 'Failed to export Sales to Excel', e, stack);
       rethrow;
    }
  }

  Future<void> exportSalesMiracleFormat(int shopId, String shopName, {DateTime? startDate, DateTime? endDate}) async {
    var query = _client
        .from('sales_entries')
        .select('''
          *,
          parties (partyname),
          product_head (product_name)
        ''')
        .eq('shop_id', shopId);

    if (startDate != null) {
      query = query.gte('date', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('date', endDate.toIso8601String());
    }

    try {
      final response = await query.order('date', ascending: false);

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['MiracleSales'];
      excel.setDefaultSheet('MiracleSales');

      // --- ROW 1: Shop Name (Centered) ---
      var shopStyle = CellStyle(
        fontSize: 18,
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#0F4C81'),
        horizontalAlign: HorizontalAlign.Center,
      );
      
      // Merge all 11 columns for centering
      sheetObject.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 0),
      );
      
      var shopCell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      shopCell.value = TextCellValue(shopName.toUpperCase());
      shopCell.cellStyle = shopStyle;

      // --- ROW 2: Period Header (Centered) ---
      var periodStyle = CellStyle(
        fontSize: 12, 
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );
      
      sheetObject.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
        CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 1),
      );

      final periodText = startDate != null && endDate != null
          ? 'REPORT PERIOD: ${DateFormat('dd-MM-yyyy').format(startDate)} TO ${DateFormat('dd-MM-yyyy').format(endDate)}'
          : 'REPORT DATE: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}';
      
      var periodCell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
      periodCell.value = TextCellValue(periodText);
      periodCell.cellStyle = periodStyle;

      // --- ROW 3-7: Empty Space ---
      // (Explicitly doing nothing here keeps them empty)

      // --- ROW 8: Headers ---
      final headers = [
        'Date', 'Inv No', 'Party Name', 'Product Name', 'Qty', 'Rate', 'Amount', 
        'Party Type', 'Type', 'Place Of Supply', 'Party Type'
      ];
      
      var headerStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#EEEEEE'),
        bold: true,
      );

      for (int i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 7));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // --- ROW 9+: Data ---
      int currentRow = 8;
      for (var row in response) {
        String dateStr = '';
        if (row['date'] != null) {
          try {
            dateStr = DateFormat('dd-MM-yyyy').format(DateTime.parse(row['date'].toString()));
          } catch (_) {
            dateStr = row['date'].toString().split(' ').first;
          }
        }
        
        final invNo = row['invoiceno']?.toString() ?? '';
        final partyName = row['parties']?['partyname']?.toString() ?? '';
        final productName = row['product_head']?['product_name']?.toString() ?? '';
        final qty = row['quantity']?.toString() ?? '0';
        final rate = row['rate']?.toString() ?? '0';
        final amount = row['amount']?.toString() ?? '0';

        final rowData = [
          dateStr, invNo, partyName, productName, qty, rate, amount,
          'Sundry Debtors', 'Debit', 'Maharashtra', 'Consumer'
        ];

        for (int i = 0; i < rowData.length; i++) {
          sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow))
              .value = TextCellValue(rowData[i]);
        }
        currentRow++;
      }

      final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final safeName = _sanitizeFilename(shopName);
      final fileName = '${safeName}_MiracleSales_$dateStr.xlsx';
      final byteData = Uint8List.fromList(excel.encode()!);

      await _deliverFile(
        bytes: byteData,
        fileName: fileName,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        shareTitle: 'Sales Miracle Export for $shopName',
      );
      _logger?.success('Export', 'Successfully exported Sales in Miracle format');
    } catch (e, stack) {
       _logger?.error('Export', 'Failed to export Sales in Miracle format', e, stack);
       rethrow;
    }
  }

  Future<void> exportStockToExcel(int shopId, String shopName) async {
    try {
      final response = await _client
          .from('stock')
          .select('''
            *,
            products_design (design_no, product_head (product_name)),
            locations (name)
          ''')
          .eq('shop_id', shopId)
          .order('quantity', ascending: true);

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Stock'];
      excel.setDefaultSheet('Stock');

      sheetObject.appendRow([
        TextCellValue('Product'),
        TextCellValue('Design No'),
        TextCellValue('Location'),
        TextCellValue('Quantity'),
        TextCellValue('Last Updated')
      ]);

      for (var row in response) {
        final design = row['products_design'] ?? {};
        final productHead = design['product_head'] ?? {};
        final location = row['locations'] ?? {};

        sheetObject.appendRow([
          TextCellValue(productHead['product_name']?.toString() ?? ''),
          TextCellValue(design['design_no']?.toString() ?? ''),
          TextCellValue(location['name']?.toString() ?? ''),
          TextCellValue(row['quantity']?.toString() ?? '0'),
          TextCellValue(_formatTimestamp(row['modified_at']?.toString())),
        ]);
      }

      final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final safeName = _sanitizeFilename(shopName);
      final fileName = '${safeName}_Stock_$dateStr.xlsx';
      final byteData = Uint8List.fromList(excel.encode()!);

      await _deliverFile(
        bytes: byteData,
        fileName: fileName,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        shareTitle: 'Stock Export for $shopName',
      );

      _logger?.success('Export', 'Successfully exported Stock to Excel');
    } catch (e, stack) {
      _logger?.error('Export', 'Failed to export Stock to Excel', e, stack);
      rethrow;
    }
  }

  Future<void> exportPurchaseToExcel(int shopId, String shopName, {DateTime? startDate, DateTime? endDate}) async {
    var query = _client
        .from('purchase')
        .select('''
          *,
          parties (partyname),
          products_design (design_no, product_head (product_name))
        ''')
        .eq('shop_id', shopId);

    if (startDate != null) {
      query = query.gte('date', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('date', endDate.toIso8601String());
    }

    try {
      final response = await query.order('date', ascending: false);

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Purchase'];
      excel.setDefaultSheet('Purchase');

      sheetObject.appendRow([
        TextCellValue('Date'),
        TextCellValue('Party Name'),
        TextCellValue('Product'),
        TextCellValue('Design No'),
        TextCellValue('Quantity'),
      ]);

      for (var row in response) {
        final date = row['date']?.toString().split(' ').first ?? '';
        final party = row['parties']?['partyname']?.toString() ?? '';
        final design = row['products_design'] ?? {};
        final product = design['product_head']?['product_name']?.toString() ?? '';
        final designNo = design['design_no']?.toString() ?? '';
        final qty = row['quantity']?.toString() ?? '0';

        sheetObject.appendRow([
          TextCellValue(date),
          TextCellValue(party),
          TextCellValue(product),
          TextCellValue(designNo),
          TextCellValue(qty),
        ]);
      }

      final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final safeName = _sanitizeFilename(shopName);
      final fileName = '${safeName}_Purchase_$dateStr.xlsx';
      final byteData = Uint8List.fromList(excel.encode()!);

      await _deliverFile(
        bytes: byteData,
        fileName: fileName,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        shareTitle: 'Purchase Export for $shopName',
      );

      _logger?.success('Export', 'Successfully exported Purchase to Excel');
    } catch (e, stack) {
      _logger?.error('Export', 'Failed to export Purchase to Excel', e, stack);
      rethrow;
    }
  }

  // --- PDF Exports ---
  
  Future<void> _exportGenericPdf(String title, String shopName, List<String> headers, List<List<String>> data) async {
    final pdf = pw.Document();
    
    // Using default font for brevity in exports, but ideally load custom fonts
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            pw.Header(level: 0, child: pw.Text('$shopName - $title Report')),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              border: pw.TableBorder.all(),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellHeight: 25,
              cellAlignments: { for (var i in List.generate(headers.length, (i) => i)) i : pw.Alignment.centerLeft },
            )
          ];
        }
      )
    );

    final uint8List = Uint8List.fromList(await pdf.save());
    final safeTitle = _sanitizeFilename(title);
    final safeName = _sanitizeFilename(shopName);
    final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final fileName = '${safeName}_${safeTitle}_$dateStr.pdf';
    
    await _deliverFile(
      bytes: uint8List,
      fileName: fileName,
      mimeType: 'application/pdf',
      shareTitle: '$title PDF for $shopName',
    );
  }

  Future<void> exportSalesToPdf(int shopId, String shopName, {DateTime? startDate, DateTime? endDate}) async {
    try {
      var query = _client
          .from('sales_entries')
          .select('*, parties(partyname), product_head(product_name), products_design(design_no)')
          .eq('shop_id', shopId);

      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('date', endDate.toIso8601String());
      }

      final response = await query.order('date', ascending: false);
          
      final headers = ['Date', 'Invoice No', 'Party', 'Product', 'Design', 'Qty', 'Amount'];
      final data = response.map((row) {
        return [
          row['date']?.toString().split(' ').first ?? '',
          row['invoiceno']?.toString() ?? '',
          row['parties']?['partyname']?.toString() ?? '',
          row['product_head']?['product_name']?.toString() ?? '',
          row['products_design']?['design_no']?.toString() ?? '',
          row['quantity']?.toString() ?? '0',
          row['amount']?.toString() ?? '0',
        ];
      }).toList();
      
      await _exportGenericPdf('Sales', shopName, headers, data);
      _logger?.success('Export', 'Successfully exported Sales to PDF');
    } catch (e, stack) {
      _logger?.error('Export', 'Failed to export Sales to PDF', e, stack);
      rethrow;
    }
  }

  Future<void> exportPurchaseToPdf(int shopId, String shopName, {DateTime? startDate, DateTime? endDate}) async {
    try {
      var query = _client
          .from('purchase')
          .select('*, parties(partyname), products_design(design_no, product_head(product_name))')
          .eq('shop_id', shopId);

      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('date', endDate.toIso8601String());
      }

      final response = await query.order('date', ascending: false);
          
      final headers = ['Date', 'Party Name', 'Product', 'Design No', 'Quantity'];
      final data = response.map<List<String>>((row) {
        final design = row['products_design'] ?? {};
        return [
          row['date']?.toString().split(' ').first ?? '',
          row['parties']?['partyname']?.toString() ?? '',
          design['product_head']?['product_name']?.toString() ?? '',
          design['design_no']?.toString() ?? '',
          row['quantity']?.toString() ?? '0',
        ];
      }).toList();
      
      await _exportGenericPdf('Purchase', shopName, headers, data);
      _logger?.success('Export', 'Successfully exported Purchase to PDF');
    } catch (e, stack) {
      _logger?.error('Export', 'Failed to export Purchase to PDF', e, stack);
      rethrow;
    }
  }

  Future<void> exportStockToPdf(int shopId, String shopName) async {
    try {
      final response = await _client
          .from('stock')
          .select('*, products_design(design_no, product_head(product_name)), locations(name)')
          .eq('shop_id', shopId)
          .order('quantity', ascending: true);
          
      final headers = ['Product', 'Design No', 'Location', 'Quantity', 'Last Updated'];
      final data = response.map<List<String>>((row) {
        final design = row['products_design'] ?? {};
        return [
          design['product_head']?['product_name']?.toString() ?? '',
          design['design_no']?.toString() ?? '',
          row['locations']?['name']?.toString() ?? '',
          row['quantity']?.toString() ?? '0',
          _formatTimestamp(row['modified_at']?.toString()),
        ];
      }).toList();
      
      await _exportGenericPdf('Stock', shopName, headers, data);
      _logger?.success('Export', 'Successfully exported Stock to PDF');
    } catch (e, stack) {
      _logger?.error('Export', 'Failed to export Stock to PDF', e, stack);
      rethrow;
    }
  }
}

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    ref.watch(supabaseClientProvider),
    ref.read(logServiceProvider),
  );
});
