import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForexReceiptPdfPage extends StatefulWidget {
  final Map<String, dynamic> transactionData;
  final String docId;

  const ForexReceiptPdfPage({super.key, required this.transactionData, required this.docId});

  @override
  State<ForexReceiptPdfPage> createState() => _ForexReceiptPdfPageState();
}

class _ForexReceiptPdfPageState extends State<ForexReceiptPdfPage> {
  final _companyNameCtrl = TextEditingController(text: "journeytale Money Changer");
  final _addressCtrl = TextEditingController(text: "123 Financial District, Jakarta");
  final _phoneCtrl = TextEditingController(text: "+62 812 3456 7890");
  final _noteCtrl = TextEditingController(text: "Thank you for your business!");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Generate Receipt"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: Row(
        children: [
          // Sidebar Settings
          Container(
            width: 350,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Receipt Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: _companyNameCtrl, decoration: const InputDecoration(labelText: "Company Name"), onChanged: (_) => setState((){})),
                const SizedBox(height: 12),
                TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: "Address"), onChanged: (_) => setState((){})),
                const SizedBox(height: 12),
                TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: "Contact Phone"), onChanged: (_) => setState((){})),
                const SizedBox(height: 12),
                TextField(controller: _noteCtrl, decoration: const InputDecoration(labelText: "Footer Note"), maxLines: 2, onChanged: (_) => setState((){})),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final bytes = await _generatePdf();
                      await Printing.layoutPdf(onLayout: (_) async => bytes);
                    },
                    icon: const Icon(Icons.print),
                    label: const Text("Print / Save PDF"),
                    style: ElevatedButton.styleFrom(),
                  ),
                )
              ],
            ),
          ),
          
          // PDF Preview
          Expanded(
            child: Container(
              color: Colors.grey.shade200,
              child: PdfPreview(
                build: (format) => _generatePdf(),
                canChangeOrientation: false,
                canChangePageFormat: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    // Using standard fonts to ensure compatibility
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    
    final t = widget.transactionData;
    final date = (t['date'] as Timestamp).toDate();
    
    // Logic extraction
    final String type = t['txn_type'] ?? 'SELL';
    final bool isWeSelling = type == 'SELL'; // Client Gives IDR, Gets Foreign
    
    // Determine Rate and Total based on Type
    // If We Sell: Use sell_rate. If We Buy: Use buy_rate.
    final double rate = isWeSelling ? (t['sell_rate'] as num).toDouble() : (t['buy_rate'] as num).toDouble();
    final double amountForeign = (t['amount_foreign'] as num).toDouble();
    final double totalIdr = amountForeign * rate;

    final fmtIdr = NumberFormat.simpleCurrency(name: 'Rp ', decimalDigits: 0);
    final fmtForeign = NumberFormat.simpleCurrency(name: t['target_currency'] ?? '', decimalDigits: 0);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5, // A5 is standard for receipts
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      build: (pw.Context context) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // 1. Header
              pw.Text(_companyNameCtrl.text.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(_addressCtrl.text, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Text(_phoneCtrl.text, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Divider(thickness: 0.5),
              
              // 2. Title & Date
              pw.SizedBox(height: 10),
              pw.Text(isWeSelling ? "OFFICIAL RECEIPT" : "PAYMENT VOUCHER", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text(isWeSelling ? "(Foreign Currency Sale)" : "(Foreign Currency Purchase)", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.SizedBox(height: 15),

              // 3. Metadata
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("Transaction ID: ${widget.docId.substring(0, 8).toUpperCase()}", style: const pw.TextStyle(fontSize: 10)),
                pw.Text("Date: ${DateFormat('dd MMM yyyy HH:mm').format(date)}", style: const pw.TextStyle(fontSize: 10)),
              ]),
              pw.SizedBox(height: 5),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("Customer:", style: const pw.TextStyle(fontSize: 10)),
                pw.Text(t['customer_name'] ?? "Walk-in", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ]),
              pw.SizedBox(height: 20),
              
              // 4. Details Box
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  color: PdfColors.grey50
                ),
                padding: const pw.EdgeInsets.all(12),
                child: pw.Column(
                  children: [
                    // Foreign Line
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text(isWeSelling ? "Amount Sold:" : "Amount Bought:", style: const pw.TextStyle(fontSize: 11)),
                      pw.Text(fmtForeign.format(amountForeign), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    ]),
                    pw.SizedBox(height: 8),
                    
                    // Rate Line
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text("Exchange Rate:", style: const pw.TextStyle(fontSize: 11)),
                      pw.Text(NumberFormat.decimalPattern().format(rate), style: const pw.TextStyle(fontSize: 12)),
                    ]),
                    
                    pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                    
                    // Total Line
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text(isWeSelling ? "TOTAL RECEIVED (IDR):" : "TOTAL PAID (IDR):", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text(fmtIdr.format(totalIdr), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    ]),
                  ]
                )
              ),
              
              pw.Spacer(),
              
              // 5. Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                    pw.Container(width: 80, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text("Customer", style: const pw.TextStyle(fontSize: 8)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                    pw.Container(width: 80, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text("Teller / Authorized", style: const pw.TextStyle(fontSize: 8)),
                  ]),
                ]
              ),
              pw.SizedBox(height: 20),
              
              // 6. Footer
              pw.Center(child: pw.Text(_noteCtrl.text, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600), textAlign: pw.TextAlign.center)),
            ]
          )
        );
      }
    ));
    return pdf.save();
  }
}