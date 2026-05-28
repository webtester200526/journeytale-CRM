import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:crmx/service_model.dart';

class TourGuidePdfEditorPage extends StatefulWidget {
  final String orderId;
  final OrderModel orderModel;
  final Map<String, dynamic> guideData;

  const TourGuidePdfEditorPage({
    super.key,
    required this.orderId,
    required this.orderModel,
    required this.guideData,
  });

  @override
  State<TourGuidePdfEditorPage> createState() => _TourGuidePdfEditorPageState();
}

class _TourGuidePdfEditorPageState extends State<TourGuidePdfEditorPage> {
  // Guide Info (Pre-filled from DB)
  late TextEditingController _nameCtrl;
  late TextEditingController _idCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _feeCtrl;
  late TextEditingController _otCtrl;
  
  // Policies (Pre-filled)
  late TextEditingController _transPolicyCtrl;
  late TextEditingController _foodPolicyCtrl;
  late TextEditingController _notesCtrl;

  // Defaults / Constants
  final _orderNoCtrl = TextEditingController();
  final _guestNameCtrl = TextEditingController(); // e.g. Tata & Aling Family
  final _paxCtrl = TextEditingController(); // e.g. 38 pax
  
  // Rules (Editable List)
  final _rulesCtrl = TextEditingController(text: 
"""1. Harap datang tepat waktu sesuai jadwal yang telah disepakati.
2. Layani tamu dengan ramah, terutama lansia dan anak-anak.
3. Bantu tamu dalam pemesanan makanan dan jelaskan area atau tempat sekitar dengan baik.
4. Selalu ajak tamu berbicara selama perjalanan agar suasana tidak canggung atau hening terlalu lama.
5. Tanyakan secara berkala apakah tamu lelah berjalan dan ingin beristirahat.
6. Jam kerja dimulai saat pihak tamu atau pihak journeytale memberikan jadwal janji pada hari sebelumnya.
7. Fee dan jam kerja akan dibicarakan secara personal dan rahasia, dimohon untuk menjaga kerahasiaan ini.
8. Jika ada lembur (Over Time), wajib memberitahukan terlebih dahulu kepada pihak journeytale.""");

  final _reimburseCtrl = TextEditingController(text: "Dimohon untuk berdiskusi terlebih dahulu untuk Reimburse Item.");

  // Colors
  static const PdfColor _journeytaleBlue = PdfColor.fromInt(0xFF00A0E9);
  static const PdfColor _journeytaleOrange = PdfColor.fromInt(0xFFF5A623);
  static const PdfColor _lightGreyBg = PdfColor.fromInt(0xFFF2F2F2);

  @override
  void initState() {
    super.initState();
    final d = widget.guideData;
    _nameCtrl = TextEditingController(text: d['name'] ?? '');
    _idCtrl = TextEditingController(text: d['passport'] ?? '');
    _areaCtrl = TextEditingController(text: d['area'] ?? 'HangZhou 杭州');
    _feeCtrl = TextEditingController(text: "RMB ${d['fee_per_day'] ?? 450} / 10 jam");
    _otCtrl = TextEditingController(text: "RMB ${d['ot_fee'] ?? 50} / jam");
    
    _transPolicyCtrl = TextEditingController(text: d['transport_policy'] ?? "Perjalanan berangkat atau pulang pada jam 22:00 - 07:00 dapat direimburse.");
    _foodPolicyCtrl = TextEditingController(text: d['food_policy'] ?? "Makan bersama dengan tamu.");
    _notesCtrl = TextEditingController(text: d['notes'] ?? "Adanya lansia yang perlu di jaga sebanyak 6 orang.");

    _orderNoCtrl.text = "2025${DateTime.now().month}${DateTime.now().day}-001";
    _guestNameCtrl.text = widget.orderModel.name;
    _paxCtrl.text = "1 Group"; // Can't auto-fetch pax easily unless stored in order
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.notoSansSCRegular();
    final fontBold = await PdfGoogleFonts.notoSansSCBold();
    final ByteData data = await rootBundle.load('assets/Explore city like a local.png');
    final Uint8List bytes = data.buffer.asUint8List();

    final ByteData data2 = await rootBundle.load('assets/3.png');
    final  _logoImage2 = pw.MemoryImage(data2.buffer.asUint8List());
    // 2. Create the PDF Image provider
    final logoImage = pw.MemoryImage(bytes);

    // Dates
    final start = (widget.guideData['start_date'] as Timestamp?)?.toDate();
    final end = (widget.guideData['end_date'] as Timestamp?)?.toDate();
    final dateStr = (start != null && end != null) 
        ? "${DateFormat('dd').format(start)}-${DateFormat('dd MMMM yyyy').format(end)}"
        : "TBA";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return [
            // 1. TOP BAR
            pw.Container(height: 8, color: _journeytaleBlue),
            pw.SizedBox(height: 20),

            // 2. HEADER
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(logoImage, width: 150, height: 150),
                // Compass Logo Placeholder
                pw.Image(_logoImage2, width: 150, height: 100),
                
              ]
            ),
            pw.SizedBox(height: 20),

            // 3. TITLE
            pw.Row(
              children: [
                pw.Text("Tour Guide Assignment ", style: pw.TextStyle(color: _journeytaleBlue, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text("导游派单", style: pw.TextStyle(color: _journeytaleOrange, fontSize: 20, fontWeight: pw.FontWeight.bold)),
              ]
            ),
            pw.SizedBox(height: 10),

            // 4. BASIC INFO ROW
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(_nameCtrl.text, style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(height: 2),
                  pw.Text("Passport No. ${_idCtrl.text}", style: const pw.TextStyle(fontSize: 12)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: "Area 地区 :  ", style: pw.TextStyle(color: _journeytaleBlue)),
                    pw.TextSpan(text: _areaCtrl.text, style: pw.TextStyle(color: _journeytaleOrange, fontWeight: pw.FontWeight.bold)),
                  ])),
                  pw.SizedBox(height: 5),
                  pw.Text("Order Number 订单号:  ${_orderNoCtrl.text}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ])
              ]
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 20),

            // 5. DESCRIPTION SECTION
            pw.Row(children: [
              pw.Text("Description ", style: pw.TextStyle(color: _journeytaleBlue, fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text("明细", style: pw.TextStyle(color: _journeytaleOrange, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.SizedBox(height: 10),
            
            // Meta
            pw.Text("Tanggal Penugasan: $dateStr"),
            pw.Text("Jumlah Client: ${_paxCtrl.text}"),
            pw.Text("Nama Client: ${_guestNameCtrl.text}"),
            pw.SizedBox(height: 10),

            // Fees
            pw.Text("Fee Guide:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text("• Full Day: ${_feeCtrl.text}"),
            pw.Text("• Overtime (OT): ${_otCtrl.text}"),
            pw.SizedBox(height: 10),

            // Transport (Grey Box)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              color: _lightGreyBg,
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("Transportasi:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("• ${_transPolicyCtrl.text}", style: const pw.TextStyle(fontSize: 10)),
              ])
            ),
            pw.SizedBox(height: 10),

            // Consumption
            pw.Text("Konsumsi:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text("• ${_foodPolicyCtrl.text}"),
            pw.SizedBox(height: 10),

            // Notes (Red)
            pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: "Catatan: ", style: const pw.TextStyle(color: PdfColors.red)),
              pw.TextSpan(text: _notesCtrl.text, style: pw.TextStyle(color: PdfColors.red, fontWeight: pw.FontWeight.bold)),
            ])),

            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 20),

            // 6. REMINDER & RULES
            pw.Row(children: [
              pw.Text("Reminder ", style: pw.TextStyle(color: _journeytaleBlue, fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text("注意事项:", style: pw.TextStyle(color: _journeytaleOrange, fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.Text("Rules:", style: pw.TextStyle(color: _journeytaleBlue, fontSize: 10)),
            pw.SizedBox(height: 5),
            
            // Rules Text Block
            pw.Text(_rulesCtrl.text, style: const pw.TextStyle(fontSize: 9, lineSpacing: 2)),
            
            pw.SizedBox(height: 15),
            pw.Text("Reimbursement:", style: pw.TextStyle(color: _journeytaleOrange, fontSize: 10)),
            pw.Text(_reimburseCtrl.text, style: const pw.TextStyle(fontSize: 9)),

            // Footer bar
            pw.Spacer(),
            pw.Container(height: 6, color: _journeytaleOrange),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(title: const Text("Generate Guide Assignment"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: Row(
        children: [
          // CONTROLS
          Container(
            width: 380,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Guide Info", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _input(_nameCtrl, "Name"),
                  _input(_idCtrl, "Passport/ID"),
                  _input(_areaCtrl, "Area"),
                  
                  const SizedBox(height: 16),
                  const Text("Trip Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  _input(_orderNoCtrl, "Order No"),
                  _input(_guestNameCtrl, "Guest Name"),
                  _input(_paxCtrl, "Pax Count"),

                  const SizedBox(height: 16),
                  const Text("Policies & Fees", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(children: [
                    Expanded(child: _input(_feeCtrl, "Fee")),
                    const SizedBox(width: 8),
                    Expanded(child: _input(_otCtrl, "OT")),
                  ]),
                  _input(_transPolicyCtrl, "Transport Policy", maxLines: 3),
                  _input(_foodPolicyCtrl, "Food Policy"),
                  _input(_notesCtrl, "Special Notes (Red)", maxLines: 2),

                  const SizedBox(height: 16),
                  const Text("Rules Template", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  _input(_rulesCtrl, "Rules List", maxLines: 8),
                  _input(_reimburseCtrl, "Reimburse Note"),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final bytes = await _generatePdf();
                        await Printing.layoutPdf(onLayout: (_) async => bytes);
                      },
                      icon: const Icon(Icons.print),
                      label: const Text("Print / Preview"),
                      style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 16)),
                    )
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final bytes = await _generatePdf();
                        await Printing.sharePdf(bytes: bytes, filename: 'Guide_${_nameCtrl.text}.pdf');
                      },
                      icon: const Icon(Icons.download),
                      label: const Text("Download PDF"),
                    )
                  )
                ],
              ),
            ),
          ),

          // PREVIEW
          Expanded(
            child: PdfPreview(
              build: (format) => _generatePdf(),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              padding: const EdgeInsets.all(20),
            ),
          )
        ],
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        onChanged: (_) => setState((){}),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
      ),
    );
  }
}