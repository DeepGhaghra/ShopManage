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
        
        // Format date specifically as dd/MM/yyyy
        final now = DateTime.now();
        final String dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

        // Font sizes - Optimized for 10.5cm width
        const double shopSize   = 14.0;
        const double titleSize  = 10.0;
        const double headerSize = 9.0;
        const double dataSize   = 8.5;
        const double smallSize  = 7.5;
        
        // Table Rows calculation for 13.5cm height
        const int totalRows = 12;
        final int filledRows = lines.length;
        final int emptyRows = (totalRows - filledRows).clamp(0, totalRows);
        final int totalQty = lines.fold(0, (sum, l) => sum + l.quantity);

        // Column Widths for 10.5cm (approx 297 points)
        const double colSrNo  = 25.0;
        const double colBrand = 65.0;
        const double colLoc   = 65.0;
        const double colQty   = 40.0;
        
        // Margins & Borders
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
            child: pw.Text(text, style: cellStyle(f: f ?? (isBold ? fontBold : font), size: dataSize)),
          );
        }

        pw.TableRow buildEmptyRow() {
          return pw.TableRow(
            children: List.generate(5, (index) => pw.Container(
              constraints: const pw.BoxConstraints(minHeight: 20),
            )),
          );
        }

        // ── Page Build ──
        pdf.addPage(
          pw.Page(
            pageFormat: challanFormat,
            margin: margin,
            build: (context) {
              return pw.Container(
                decoration: heavyBorder,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [

                    // 1. Header Block
                    pw.Container(
                      padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
                      child: pw.Column(
                        children: [
                          pw.Text((shop.shopShortName ?? shop.shopName).toUpperCase(),
                              style: cellStyle(f: fontBold, size: shopSize)
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text('ESTIMATE',
                              style: cellStyle(f: fontBold, size: titleSize)
                          ),
                        ],
                      ),
                    ),

                    // 2. Details Block
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Expanded(
                                child: pw.Text('M/s: ${party.partyName.toUpperCase()}', 
                                  style: cellStyle(f: fontBold, size: headerSize),
                                  maxLines: 1,
                                  overflow: pw.TextOverflow.clip
                                )
                              ),
                              pw.SizedBox(width: 5),
                              pw.Text('Date: $dateStr', style: cellStyle(f: fontBold, size: headerSize)),
                            ],
                          ),
                          pw.SizedBox(height: 1),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Mobile: ${party.mobile ?? ''}', style: cellStyle(size: smallSize)),
                              pw.Text('City: ${party.city ?? ''}', style: cellStyle(size: smallSize)),
                            ],
                          ),
                        ]
                      )
                    ),
                    
                    pw.SizedBox(height: 2),

                    // 3. Main Data Table
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
                      },
                      children: [
                        // Header row
                        pw.TableRow(
                          children: [
                            pw.Container(decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: borderWidth))), padding: const pw.EdgeInsets.symmetric(vertical: 3), alignment: pw.Alignment.center, child: pw.Text('Sr No', style: cellStyle(f: fontBold, size: headerSize))),
                            pw.Container(decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: borderWidth))), padding: const pw.EdgeInsets.symmetric(vertical: 3), alignment: pw.Alignment.center, child: pw.Text('Brand', style: cellStyle(f: fontBold, size: headerSize))),
                            pw.Container(decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: borderWidth))), padding: const pw.EdgeInsets.symmetric(vertical: 3), alignment: pw.Alignment.center, child: pw.Text('Location', style: cellStyle(f: fontBold, size: headerSize))),
                            pw.Container(decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: borderWidth))), padding: const pw.EdgeInsets.symmetric(vertical: 3), alignment: pw.Alignment.center, child: pw.Text('Design No.', style: cellStyle(f: fontBold, size: headerSize))),
                            pw.Container(decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: borderWidth))), padding: const pw.EdgeInsets.symmetric(vertical: 3), alignment: pw.Alignment.center, child: pw.Text('Qty', style: cellStyle(f: fontBold, size: headerSize))),
                          ],
                        ),
                        
                        // Data rows
                        for (int i = 0; i < filledRows; i++)
                          pw.TableRow(
                            children: [
                              buildDataCell('${i + 1}', align: pw.Alignment.center),
                              buildDataCell(lines[i].brandName, align: pw.Alignment.center),
                              buildDataCell(lines[i].locationName, align: pw.Alignment.center),
                              buildDataCell(lines[i].designNo, align: pw.Alignment.center),
                              buildDataCell(lines[i].quantity.toString(), align: pw.Alignment.center),
                            ]
                          ),

                        for (int i = 0; i < emptyRows; i++) buildEmptyRow(),
                      ],
                    ),

                    // 4. Total Row
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border(
                          top: pw.BorderSide(width: borderWidth, color: PdfColors.black),
                          bottom: pw.BorderSide(width: borderWidth, color: PdfColors.black),
                        ),
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
                        ]
                      )
                    ),

                    // 5. Footer
                    pw.Container(
                      height: 35,
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('Delivery By:', style: cellStyle(size: smallSize)),
                        ]
                      )
                    )

                  ],
                ),
              );
            },
          ),
        );
        return pdf.save();
      }
    );
  }
}

final printServiceProvider = Provider<PrintService>((ref) => PrintService());
