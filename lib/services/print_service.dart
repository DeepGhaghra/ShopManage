import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/shop.dart';
import '../models/party.dart';

// ─── Data class for a single challan line ─────────────────────────────────────
class ChallanLine {
  final String brandName;
  final String locationName;
  final String designNo;
  final int quantity;

  const ChallanLine({
    required this.brandName,
    required this.locationName,
    required this.designNo,
    required this.quantity,
  });
}

// ─── Service ──────────────────────────────────────────────────────────────────
class PrintService {
  Future<void> printSalesInvoice({
    required Shop shop,
    required Party party,
    required String invoiceNo,
    required List<ChallanLine> lines,
    DateTime? date,
  }) async {
    // Load Unicode-supporting font (Roboto) to handle special characters and regional symbols
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    await Printing.layoutPdf(
      name: 'Challan-$invoiceNo',
      onLayout: (PdfPageFormat format) async {
        final pdf = pw.Document();

        // ── Custom Challan Size: 10.5cm x 13.5cm ──
        const double cm = PdfPageFormat.cm;
        const challanFormat = PdfPageFormat(10.5 * cm, 13.5 * cm, marginAll: 0.0);
        
        // Format date specifically as dd/MM/yyyy — use actual invoice date, fallback to today
        final d = date ?? DateTime.now();
        final String dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

        // Font sizes - Optimized for 10.5cm width
        const double shopSize   = 14.0;
        const double titleSize  = 10.0;
        const double headerSize = 9.0;
        const double dataSize   = 8.5;
        const double smallSize  = 7.5;
        
        // Column Widths for 10.5cm
        const double colSrNo  = 22.0;
        const double colBrand = 60.0;
        const double colLoc   = 45.0;
        const double colQty   = 35.0;
        const double colNotes = 35.0;
        
        const margin = pw.EdgeInsets.all(10);
        const double borderWidth = 0.8;

        // ── Styles ──
        final heavyBorder = pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: borderWidth));
        final rightLine = pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: borderWidth, color: PdfColors.black)));
        pw.TextStyle cellStyle({pw.Font? f, double? size, PdfColor? color}) =>
            pw.TextStyle(font: f ?? font, fontSize: size ?? dataSize, color: color);

        // ── Builders ──
        pw.Widget buildDataCell(String text, {pw.Font? f, bool isBold = false, pw.Alignment align = pw.Alignment.centerLeft}) {
          return pw.Container(
            constraints: const pw.BoxConstraints(minHeight: 20),
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            alignment: align,
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.4)),
            ),
            child: pw.Text(text, style: cellStyle(f: f ?? (isBold ? fontBold : font), size: dataSize)),
          );
        }

        pw.TableRow buildEmptyRow() {
          return pw.TableRow(
            children: List.generate(6, (index) => pw.Container(constraints: const pw.BoxConstraints(minHeight: 20))),
          );
        }

        // ── CHUNKING LOGIC FOR MULTI-PAGE ──
        const int rowsPerPage = 10;
        final int numPages = (lines.length / rowsPerPage).ceil() == 0 ? 1 : (lines.length / rowsPerPage).ceil();
        final int totalQty = lines.fold(0, (sum, l) => sum + l.quantity);

        for (int p = 0; p < numPages; p++) {
          final bool isLastPage = (p == numPages - 1);
          final int start = p * rowsPerPage;
          final int end = (start + rowsPerPage < lines.length) ? (start + rowsPerPage) : lines.length;
          final pageLines = lines.sublist(start, end);
          final int filledRows = pageLines.length;
          final int emptyRows = rowsPerPage - filledRows;

          pdf.addPage(
            pw.Page(
              pageFormat: challanFormat,
              margin: margin,
              build: (context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      decoration: heavyBorder,
                      child: pw.Column(
                        children: [
                          // 1. Header (Repeat on every page)
                          pw.Container(
                            padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
                            child: pw.Column(
                              children: [
                                pw.Text((shop.shopShortName ?? shop.shopName).toUpperCase(),
                                    style: cellStyle(f: fontBold, size: shopSize)
                                ),
                                pw.SizedBox(height: 1),
                                pw.Text('ESTIMATE ${numPages > 1 ? "(Page ${p + 1}/$numPages)" : ""}', style: cellStyle(f: fontBold, size: 8.0)),
                              ],
                            ),
                          ),

                          // 2. Customer Details (Repeat on every page)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Expanded(
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('M/s: ${party.partyName.toUpperCase()}',
                                        style: cellStyle(f: fontBold, size: headerSize),
                                      ),
                                      pw.SizedBox(height: 2),
                                      pw.Text('Mobile: ${party.mobile ?? ''}', style: cellStyle(size: smallSize)),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(width: 5),
                                pw.SizedBox(
                                  width: 72,
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                                    children: [
                                      pw.Text('Date: $dateStr', style: cellStyle(f: fontBold, size: headerSize)),
                                      pw.SizedBox(height: 2),
                                      pw.Text('City: ${party.city ?? ''}', style: cellStyle(size: smallSize)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // 3. Table (Max 10 rows per page)
                          pw.Table(
                            border: pw.TableBorder(
                              verticalInside: pw.BorderSide(width: borderWidth, color: PdfColors.black),
                              top: pw.BorderSide(width: borderWidth, color: PdfColors.black), 
                            ),
                            columnWidths: {
                              0: pw.FixedColumnWidth(colSrNo),
                              1: pw.FixedColumnWidth(colBrand),
                              2: pw.FixedColumnWidth(colLoc),
                              3: pw.FlexColumnWidth(1),
                              4: pw.FixedColumnWidth(colQty),
                              5: pw.FixedColumnWidth(colNotes),
                            },
                            children: [
                              pw.TableRow(
                                children: [
                                  for (var h in ['Sr', 'Brand', 'Loc', 'Design No.', 'Qty', ' '])
                                    pw.Container(
                                      decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: borderWidth))),
                                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                                      constraints: const pw.BoxConstraints(minHeight: 18),
                                      alignment: pw.Alignment.center,
                                      child: pw.Text(h, style: cellStyle(f: fontBold, size: headerSize)),
                                    ),
                                ],
                              ),
                              for (int i = 0; i < filledRows; i++)
                                pw.TableRow(
                                  children: [
                                    buildDataCell('${start + i + 1}', align: pw.Alignment.center),
                                    buildDataCell(pageLines[i].brandName, align: pw.Alignment.center),
                                    buildDataCell(pageLines[i].locationName, align: pw.Alignment.center),
                                    buildDataCell(pageLines[i].designNo, align: pw.Alignment.center),
                                    buildDataCell(pageLines[i].quantity.toString(), align: pw.Alignment.center),
                                    buildDataCell(''),
                                  ]
                                ),
                              for (int i = 0; i < emptyRows; i++) buildEmptyRow(),
                            ],
                          ),

                          // 4. Total (Only on Last Page)
                          if (isLastPage)
                            pw.Container(
                              decoration: pw.BoxDecoration(
                                border: pw.Border(top: pw.BorderSide(width: borderWidth, color: PdfColors.black)),
                              ),
                              child: pw.Row(
                                children: [
                                  pw.Expanded(
                                    child: pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      alignment: pw.Alignment.centerRight,
                                      decoration: rightLine, 
                                      child: pw.Text('Total', style: cellStyle(f: fontBold, size: headerSize)),
                                    ),
                                  ),
                                  pw.Container(
                                    width: colQty,
                                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                                    alignment: pw.Alignment.center,
                                    child: pw.Text(totalQty.toString(), style: cellStyle(f: fontBold, size: headerSize)),
                                  ),
                                  pw.SizedBox(width: colNotes),
                                ]
                              )
                            )
                          else
                            // Closure line for non-last pages
                            pw.Container(
                              height: 0,
                              decoration: pw.BoxDecoration(
                                border: pw.Border(top: pw.BorderSide(width: borderWidth, color: PdfColors.black)),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 5. Minimal Transporter Line (Only on Last Page)
                    if (isLastPage)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 10, left: 4),
                        child: pw.Row(
                          children: [
                            pw.Text('Transporter Name: ', style: cellStyle(size: smallSize)),
                            pw.Expanded(
                              child: pw.Container(
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.black))
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        }
        return pdf.save();
      }
    );
  }
}

final printServiceProvider = Provider<PrintService>((ref) => PrintService());
