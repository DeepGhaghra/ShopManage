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
    // Load default PDF fonts to prevent ANY network or asset fetching crashes
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    const int totalRows = 13; // Fixed rows to match precise receipt aesthetic
    final int filledRows = lines.length;
    final int emptyRows = (totalRows - filledRows).clamp(0, totalRows);

    final int totalQty = lines.fold(0, (sum, l) => sum + l.quantity);
    
    // Format date specifically as dd/MM/yyyy as seen in screenshot
    final now = DateTime.now();
    final String dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    // ── Helpers ───────────────────────────────────────────────────────────────
    pw.TextStyle cellStyle({pw.Font? f, double size = 11, PdfColor? color}) =>
        pw.TextStyle(font: f ?? font, fontSize: size, color: color);

    // ── Column widths mapped proportionally to the screenshot ─────────────────
    const double colSrNo    = 35;
    const double colBrand   = 90;
    const double colLoc     = 65;
    const double colDesign  = 160;
    const double colQty     = 45;

    // ── Border Styles ─────────────────────────────────────────────────────────
    final heavyBorder = pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.5));
    final rightLine = const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 1.5, color: PdfColors.black)));

    // ── Foreground Builders ───────────────────────────────────────────────────
    pw.Widget buildDataCell(String text, {pw.Font? f, bool isBold = false, pw.Alignment align = pw.Alignment.centerLeft}) {
      // Data cell WITHOUT horizontal borders. Minimum height prevents collapse.
      return pw.Container(
        constraints: const pw.BoxConstraints(minHeight: 24),
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        alignment: align,
        child: pw.Text(text, style: cellStyle(f: f ?? (isBold ? fontBold : font), size: 10)),
      );
    }

    pw.TableRow buildEmptyRow() {
      // Empty rows with exact same minimum height.
      // Because the Table will have ONLY verticalInside borders, this perfectly creates continuous vertical columns!
      return pw.TableRow(
        children: List.generate(6, (index) => pw.Container(
          constraints: const pw.BoxConstraints(minHeight: 24),
        )),
      );
    }

    await Printing.layoutPdf(
      name: 'Challan-$invoiceNo',
      onLayout: (PdfPageFormat format) async {
        final pdf = pw.Document();

        // Standard margins
        final isRoll = format.width < 300;
        final margin = isRoll 
            ? const pw.EdgeInsets.all(10)
            : const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 24);

        pdf.addPage(
          pw.Page(
            pageFormat: format,
            margin: margin,
            build: (context) {
              return pw.Container(
                // The master border of the entire receipt document
                decoration: heavyBorder,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  mainAxisSize: pw.MainAxisSize.min, // shrink wrap to prevent infinite height crashes
                  children: [

                    // 1. ── Header Title Block ───────────────────────────────────────
                    // NO bottom border. Background is pure white.
                    pw.Container(
                      padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
                      child: pw.Column(
                        children: [
                          pw.Text((shop.shopShortName ?? shop.shopName).toUpperCase(),
                              style: cellStyle(f: fontBold, size: 20)
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('ESTIMATE',
                              style: cellStyle(f: fontBold, size: 14)
                          ),
                        ],
                      ),
                    ),

                    // 2. ── Party Details Block ──────────────────────────────────────
                    // Notice: Still no separating border!
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('M/s: ${party.partyName.toUpperCase()}', style: cellStyle(f: fontBold, size: 14)),
                              pw.Text('Date: $dateStr', style: cellStyle(f: fontBold, size: 14)),
                            ],
                          ),
                          if (party.mobile != null || party.city != null) ...[
                            pw.SizedBox(height: 4),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Mobile: ${party.mobile ?? ''}', style: cellStyle(size: 12)),
                                pw.Text('City: ${party.city ?? ''}', style: cellStyle(size: 12)),
                              ],
                            ),
                          ],
                        ]
                      )
                    ),
                    
                    pw.SizedBox(height: 8), // Gap before table starts

                    // 3. ── The Mock Stack Component (Table) ───────────────────────
                    // Replaced `pw.Stack` with a strict `pw.Table` because Web Engine crashes on unbounded stacks.
                    // Instead of a Stack, we use a Table with ZERO HORIZONTAL BORDERS. This achieves the EXACT same effect!
                    pw.Table(
                      // ONLY draw vertical lines inside the table. Do not draw horizontal lines!
                      border: const pw.TableBorder(
                        verticalInside: pw.BorderSide(width: 1.5, color: PdfColors.black),
                        top: pw.BorderSide(width: 1.5, color: PdfColors.black), // Upper line under party
                        bottom: pw.BorderSide(width: 1.5, color: PdfColors.black), // Line above total block
                      ),
                      columnWidths: const {
                        0: pw.FixedColumnWidth(colSrNo),
                        1: pw.FixedColumnWidth(colBrand),
                        2: pw.FixedColumnWidth(colLoc),
                        3: pw.FixedColumnWidth(colDesign),
                        4: pw.FixedColumnWidth(colQty),
                        5: pw.FlexColumnWidth(1), 
                      },
                      children: [
                        // 1) Header Row (We manually inject a bottom line specifically for this row using a Custom Container decoration trick)
                        pw.TableRow(
                          children: [
                            pw.Container(decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5))), padding: const pw.EdgeInsets.symmetric(vertical: 6), alignment: pw.Alignment.center, child: pw.Text('Sr No', style: cellStyle(f: fontBold, size: 10))),
                            pw.Container(decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5))), padding: const pw.EdgeInsets.symmetric(vertical: 6), alignment: pw.Alignment.center, child: pw.Text('Brand', style: cellStyle(f: fontBold, size: 10))),
                            pw.Container(decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5))), padding: const pw.EdgeInsets.symmetric(vertical: 6), alignment: pw.Alignment.center, child: pw.Text('Location', style: cellStyle(f: fontBold, size: 10))),
                            pw.Container(decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5))), padding: const pw.EdgeInsets.symmetric(vertical: 6), alignment: pw.Alignment.center, child: pw.Text('Design No.', style: cellStyle(f: fontBold, size: 10))),
                            pw.Container(decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5))), padding: const pw.EdgeInsets.symmetric(vertical: 6), alignment: pw.Alignment.center, child: pw.Text('Qty', style: cellStyle(f: fontBold, size: 10))),
                            pw.Container(decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5))), padding: const pw.EdgeInsets.symmetric(vertical: 6)),
                          ],
                        ),
                        
                        // 2) Data Rows (These have NO bottom border padding. Just vertical lines from the TableBorder!)
                        for (int i = 0; i < filledRows; i++)
                          pw.TableRow(
                            children: [
                              buildDataCell('${i + 1}', align: pw.Alignment.center),
                              buildDataCell(lines[i].brandName, align: pw.Alignment.center),
                              buildDataCell(lines[i].locationName, align: pw.Alignment.center),
                              buildDataCell(lines[i].designNo, align: pw.Alignment.center),
                              buildDataCell(lines[i].quantity.toString(), align: pw.Alignment.center),
                              pw.Container(),
                            ]
                          ),

                        // 3) Empty Filler Rows (These continue the vertical lines flawlessly downwards to the bottom!)
                        for (int i = 0; i < emptyRows; i++) buildEmptyRow(),
                      ],
                    ),

                    // 4. ── Bottom Total Block ───────────────────────────────────────
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.symmetric(horizontal: pw.BorderSide(width: 1.5, color: PdfColors.black)), // Top border connects to table
                      ),
                      child: pw.Row(
                        children: [
                          // Spans the first 4 columns, aligned right
                          pw.Container(
                            width: colSrNo + colBrand + colLoc + colDesign,
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            alignment: pw.Alignment.centerRight,
                            decoration: rightLine,
                            child: pw.Text('Total', style: cellStyle(f: fontBold, size: 12)),
                          ),
                          // The total qty number precisely bound
                          pw.Container(
                            width: colQty,
                            padding: const pw.EdgeInsets.symmetric(vertical: 6),
                            alignment: pw.Alignment.center,
                            decoration: rightLine,
                            child: pw.Text(totalQty.toString(), style: cellStyle(f: fontBold, size: 12)),
                          ),
                          // Empty blank rectangle finishing the edge
                          pw.Expanded(child: pw.Container()),
                        ]
                      )
                    ),

                    // 5. ── Delivery Footer ──────────────────────────────────────────
                    pw.Container(
                      height: 45,
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('Delivery By:', style: cellStyle(size: 10)),
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
