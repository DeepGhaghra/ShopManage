import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/sales_entry.dart';
import '../models/shop.dart';
import '../models/party.dart';

class PrintService {
  Future<void> printSalesInvoice({
    required Shop shop,
    required Party party,
    required String invoiceNo,
    required List<SalesEntry> entries,
  }) async {
    final pdf = pw.Document();

    final robotoData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final font = pw.Font.ttf(robotoData);
    final robotoBoldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final fontBold = pw.Font.ttf(robotoBoldData);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shop.shopName, style: pw.TextStyle(font: fontBold, fontSize: 24)),
                      pw.Text('INVOICE / CHALLAN', style: pw.TextStyle(font: font, fontSize: 16)),
                    ]
                  ),
                  pw.Column(
                     crossAxisAlignment: pw.CrossAxisAlignment.end,
                     children: [
                       pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}', style: pw.TextStyle(font: font)),
                       pw.Text('Invoice No: $invoiceNo', style: pw.TextStyle(font: fontBold)),
                     ]
                  )
                ],
              ),
              
              pw.SizedBox(height: 24),
              pw.Divider(),
              pw.SizedBox(height: 24),
              
              // Party Customer info
              pw.Text('Billed To:', style: pw.TextStyle(font: fontBold, fontSize: 14)),
              pw.SizedBox(height: 4),
              pw.Text(party.partyName, style: pw.TextStyle(font: font, fontSize: 16)),
              
              pw.SizedBox(height: 32),
              
              // Table
              pw.TableHelper.fromTextArray(
                headers: ['SL', 'Description / Design', 'Qty', 'Rate', 'Amount'],
                data: List.generate(entries.length, (index) {
                  final e = entries[index];
                  return [
                    (index + 1).toString(),
                    'Product: ${e.productId} - Design: ${e.designId}', // Mocks until joined fields mapped
                    e.quantity.toString(),
                    e.rate.toString(),
                    e.amount.toString(),
                  ];
                }),
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(font: fontBold),
                cellStyle: pw.TextStyle(font: font),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                }
              ),
              
              pw.SizedBox(height: 16),
              
              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                   pw.Expanded(child: pw.Container()),
                   pw.Container(
                     padding: const pw.EdgeInsets.all(8),
                     decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide())),
                     child: pw.Row(
                       mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                       children: [
                          pw.Text('Grand Total: ', style: pw.TextStyle(font: fontBold, fontSize: 16)),
                          pw.SizedBox(width: 32),
                          pw.Text('Rs. ${entries.fold<int>(0, (sum, item) => sum + item.amount)}', style: pw.TextStyle(font: fontBold, fontSize: 16)),
                       ],
                     )
                   )
                ]
              ),
              
              pw.SizedBox(height: 64),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text('Thank you for your business!', style: pw.TextStyle(font: font, fontStyle: pw.FontStyle.italic))
              )
            ],
          );
        },
      ),
    );

    // This launches a native print UI or creates a PDF preview depending on platform
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice-$invoiceNo',
    );
  }
}

final printServiceProvider = Provider<PrintService>((ref) => PrintService());
