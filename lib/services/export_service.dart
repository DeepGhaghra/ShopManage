import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core_providers.dart';

class ExportService {
  final SupabaseClient _client;

  ExportService(this._client);

  Future<void> exportSalesToExcel(int shopId, String shopName) async {
    final response = await _client
        .from('sales_entries')
        .select('''
          *,
          parties (party_name),
          product_head (product_name),
          products_design (design_no)
        ''')
        .eq('shop_id', shopId)
        .order('date', ascending: false);

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
      final party = row['parties']?['party_name']?.toString() ?? '';
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

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Sales_Export_$shopName.xlsx');
    await file.writeAsBytes(excel.save()!);

    await Share.shareXFiles([XFile(file.path)], text: 'Sales Export for $shopName');
  }

  Future<void> exportStockToExcel(int shopId, String shopName) async {
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
        TextCellValue(row['modified_at']?.toString().split(' ').first ?? ''),
      ]);
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Stock_Export_$shopName.xlsx');
    await file.writeAsBytes(excel.save()!);

    await Share.shareXFiles([XFile(file.path)], text: 'Stock Export for $shopName');
  }

  Future<void> exportPurchaseToExcel(int shopId, String shopName) async {
    final response = await _client
        .from('purchase')
        .select('''
          *,
          parties (party_name),
          products_design (design_no, product_head (product_name))
        ''')
        .eq('shop_id', shopId)
        .order('date', ascending: false);

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
      final party = row['parties']?['party_name']?.toString() ?? '';
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

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Purchase_Export_$shopName.xlsx');
    await file.writeAsBytes(excel.save()!);

    await Share.shareXFiles([XFile(file.path)], text: 'Purchase Export for $shopName');
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

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${title.replaceAll(' ', '_')}_$shopName.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: '$title PDF for $shopName');
  }

  Future<void> exportSalesToPdf(int shopId, String shopName) async {
    final response = await _client
        .from('sales_entries')
        .select('*, parties(party_name), product_head(product_name), products_design(design_no)')
        .eq('shop_id', shopId)
        .order('date', ascending: false);
        
    final headers = ['Date', 'Invoice No', 'Party', 'Product', 'Design', 'Qty', 'Amount'];
    final data = response.map((row) {
      return [
        row['date']?.toString().split(' ').first ?? '',
        row['invoiceno']?.toString() ?? '',
        row['parties']?['party_name']?.toString() ?? '',
        row['product_head']?['product_name']?.toString() ?? '',
        row['products_design']?['design_no']?.toString() ?? '',
        row['quantity']?.toString() ?? '0',
        row['amount']?.toString() ?? '0',
      ];
    }).toList();
    
    await _exportGenericPdf('Sales', shopName, headers, data);
  }

  Future<void> exportPurchaseToPdf(int shopId, String shopName) async {
    final response = await _client
        .from('purchase')
        .select('*, parties(party_name), products_design(design_no, product_head(product_name))')
        .eq('shop_id', shopId)
        .order('date', ascending: false);
        
    final headers = ['Date', 'Party Name', 'Product', 'Design No', 'Quantity'];
    final data = response.map<List<String>>((row) {
      final design = row['products_design'] ?? {};
      return [
        row['date']?.toString().split(' ').first ?? '',
        row['parties']?['party_name']?.toString() ?? '',
        design['product_head']?['product_name']?.toString() ?? '',
        design['design_no']?.toString() ?? '',
        row['quantity']?.toString() ?? '0',
      ];
    }).toList();
    
    await _exportGenericPdf('Purchase', shopName, headers, data);
  }

  Future<void> exportStockToPdf(int shopId, String shopName) async {
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
        row['modified_at']?.toString().split(' ').first ?? '',
      ];
    }).toList();
    
    await _exportGenericPdf('Stock', shopName, headers, data);
  }
}

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(ref.watch(supabaseClientProvider));
});
