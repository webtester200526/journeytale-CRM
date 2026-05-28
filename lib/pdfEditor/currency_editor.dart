import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// --- MODELS ---

class ReceiptProfile {
  final String id;
  final String profileName;
  final String companyName;
  final String agentName;
  final String contactInfo;

  ReceiptProfile({required this.id, required this.profileName, required this.companyName, required this.agentName, required this.contactInfo});

  factory ReceiptProfile.fromMap(String id, Map<String, dynamic> map) {
    return ReceiptProfile(
      id: id,
      profileName: map['profileName'] ?? 'Unnamed',
      companyName: map['companyName'] ?? '',
      agentName: map['agentName'] ?? '',
      contactInfo: map['contactInfo'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'type': 'receipt_profile',
    'profileName': profileName,
    'companyName': companyName,
    'agentName': agentName,
    'contactInfo': contactInfo,
  };
}

// --- MAIN WIDGET ---

class CurrencyReceiptPdfEditor extends StatefulWidget {
  final String orderId;
  final String clientName;
  final Map<String, dynamic> transactionData; 

  const CurrencyReceiptPdfEditor({
    super.key,
    required this.orderId,
    required this.clientName,
    required this.transactionData,
  });

  @override
  State<CurrencyReceiptPdfEditor> createState() => _CurrencyReceiptPdfEditorState();
}

class _CurrencyReceiptPdfEditorState extends State<CurrencyReceiptPdfEditor> {
  bool _isLoading = true;
  
  // --- NEW: Language State ---
  bool _isChinese = false;

  // Controllers
  final _receiptNoCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController(text: "journeytale Money Exchange");
  final _agentNameCtrl = TextEditingController(text: "Victor Ong");
  final _contactCtrl = TextEditingController(text: "+62 812 3456 7890");
  final _noteCtrl = TextEditingController(text: "Thank you for your business.");

  // Data
  List<ReceiptProfile> _savedProfiles = [];
  ReceiptProfile? _selectedProfile;

  // PDF Colors
  static const PdfColor _journeytaleBlue = PdfColor.fromInt(0xFF00A0E9);
  static const PdfColor _journeytaleOrange = PdfColor.fromInt(0xFFF5A623);
  static const PdfColor _lightGreyBg = PdfColor.fromInt(0xFFF2F2F2);

  // --- TRANSLATION MAP ---
  Map<String, String> get _labels => _isChinese ? {
    'header_title': '货币兑换收据',
    'receipt_no': '收据编号:',
    'date': '日期:',
    'client': '客户:',
    'agent': '经办人:',
    'paid_by': '客户支付',
    'received_by': '客户收到',
    'rate': '汇率:',
    'contact': '联系方式:',
    'thank_you': '谢谢惠顾!',
  } : {
    'header_title': 'MONEY RECEIPT',
    'receipt_no': 'Receipt No:',
    'date': 'Date:',
    'client': 'Client:',
    'agent': 'Agent:',
    'paid_by': 'PAID BY CLIENT',
    'received_by': 'RECEIVED BY CLIENT',
    'rate': 'Exchange Rate:',
    'contact': 'Contact:',
    'thank_you': 'Thank You!',
  };

  @override
  void initState() {
    super.initState();
    _receiptNoCtrl.text = "EX-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
    _initData();
  }

  Future<void> _initData() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('utilities').where('type', isEqualTo: 'receipt_profile').get();
      _savedProfiles = snap.docs.map((e) => ReceiptProfile.fromMap(e.id, e.data())).toList();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC ---

  void _applyProfile(ReceiptProfile p) {
    setState(() {
      _selectedProfile = p;
      _companyNameCtrl.text = p.companyName;
      _agentNameCtrl.text = p.agentName;
      _contactCtrl.text = p.contactInfo;
    });
  }

  Future<void> _saveProfile() async {
    final nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Save Profile"),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Profile Name")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel",style: TextStyle(color: Colors.red))),
          FilledButton(onPressed: () {
            FirebaseFirestore.instance.collection('utilities').add(ReceiptProfile(
              id: '', 
              profileName: nameCtrl.text,
              companyName: _companyNameCtrl.text,
              agentName: _agentNameCtrl.text,
              contactInfo: _contactCtrl.text
            ).toMap());
            Navigator.pop(ctx);
            _initData();
          }, child: const Text("Save"))
        ],
      )
    );
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    
    // Using NotoSansSC ensures special chars and Chinese render correctly
    final fontRegular = await PdfGoogleFonts.notoSansSCRegular();
    final fontBold = await PdfGoogleFonts.notoSansSCBold();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    // Transaction Data
    final t = widget.transactionData;
    final date = (t['date'] as Timestamp).toDate();
    
    final curIn = t['currency_in'] ?? 'IDR';
    final curOut = t['currency_out'] ?? 'RMB';
    final amountIn = (t['amount_in'] as num).toDouble();
    final amountOut = (t['amount_out'] as num).toDouble();
    final rate = (t['rate'] as num).toDouble();

    // Custom formatters for PDF
    final fmtIn = NumberFormat.simpleCurrency(name: curIn, decimalDigits: 0);
    final fmtOut = NumberFormat.simpleCurrency(name: curOut, decimalDigits: 0);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5, // A5 Landscape or Portrait fits receipts well
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      build: (pw.Context context) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _journeytaleBlue, width: 2)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(_labels['header_title']!, style: pw.TextStyle(color: _journeytaleBlue, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_companyNameCtrl.text, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ]
              ),
              pw.Divider(color: _journeytaleOrange),
              pw.SizedBox(height: 10),

              // META
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text("${_labels['receipt_no']} ${_receiptNoCtrl.text}", style: const pw.TextStyle(fontSize: 9)),
                    pw.Text("${_labels['date']} ${dateFormat.format(date)}", style: const pw.TextStyle(fontSize: 9)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text("${_labels['client']} ${widget.clientName}", style: const pw.TextStyle(fontSize: 9)),
                    pw.Text("${_labels['agent']} ${_agentNameCtrl.text}", style: const pw.TextStyle(fontSize: 9)),
                  ]),
                ]
              ),
              pw.SizedBox(height: 15),

              // TRANSACTION BOX
              pw.Container(
                color: _lightGreyBg,
                padding: const pw.EdgeInsets.all(15),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(_labels['paid_by']!, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 8)),
                        pw.Text(_labels['received_by']!, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 8)),
                      ]
                    ),
                    pw.SizedBox(height: 5),
                    
                    // AMOUNTS ROW
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            fmtIn.format(amountIn), 
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.left
                          )
                        ),
                        
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                          child: pw.Text("→", style: pw.TextStyle(color: _journeytaleOrange, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ),
                        
                        pw.Expanded(
                          child: pw.Text(
                            fmtOut.format(amountOut), 
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _journeytaleBlue),
                            textAlign: pw.TextAlign.right
                          )
                        ),
                      ]
                    ),
                    
                    pw.SizedBox(height: 10),
                    pw.Divider(),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text("${_labels['rate']} ", style: const pw.TextStyle(fontSize: 9)),
                        pw.Text("1 $curOut = $rate $curIn", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ]
                    )
                  ]
                )
              ),

              pw.Spacer(),
              
              // FOOTER
              pw.Text(_noteCtrl.text, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.SizedBox(height: 2),
              pw.Text("${_labels['contact']} ${_contactCtrl.text}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.SizedBox(height: 15),
              pw.Center(child: pw.Text(_labels['thank_you']!, style: pw.TextStyle(color: _journeytaleOrange, fontWeight: pw.FontWeight.bold, fontSize: 12))),
            ]
          )
        );
      }
    ));

    return pdf.save();
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(title: const Text("Generate Receipt"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: Row(
        children: [
          // LEFT CONTROLS
          Container(
            width: 350,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- NEW: LANGUAGE TOGGLE ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("PDF Language", style: TextStyle(fontWeight: FontWeight.bold)),
                      ToggleButtons(
                        borderRadius: BorderRadius.circular(8),
                        isSelected: [!_isChinese, _isChinese],
                        onPressed: (index) => setState(() => _isChinese = index == 1),
                        constraints: const BoxConstraints(minHeight: 32, minWidth: 60),
                        children: const [Text("EN"), Text("中文")],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ExpansionTile(
                    title: const Text("Receipt Profiles", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    children: [
                      DropdownButtonFormField<ReceiptProfile>(
                        isExpanded: true,
                        items: _savedProfiles.map((p) => DropdownMenuItem(value: p, child: Text(p.profileName))).toList(),
                        onChanged: (v) { if(v!=null) _applyProfile(v); },
                        hint: const Text("Load Profile"),
                      ),
                      TextButton(onPressed: _saveProfile, child: const Text("Save Current as Profile")),
                    ]
                  ),
                  const Divider(),
                  _input(_companyNameCtrl, "Company Name"),
                  _input(_agentNameCtrl, "Agent Name"),
                  _input(_contactCtrl, "Contact Info"),
                  _input(_receiptNoCtrl, "Receipt No"),
                  _input(_noteCtrl, "Footer Note"),
                  
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final bytes = await _generatePdf();
                        await Printing.layoutPdf(onLayout: (_) async => bytes);
                      },
                      icon: const Icon(Icons.print),
                      label: const Text("Print"),
                   
                    )
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final bytes = await _generatePdf();
                        await Printing.sharePdf(bytes: bytes, filename: 'Receipt_${_receiptNoCtrl.text}.pdf');
                      },
                      icon: const Icon(Icons.download),
                      label: const Text("Download PDF"),
                    )
                  )
                ],
              ),
            ),
          ),

          // RIGHT PREVIEW
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

  Widget _input(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        onChanged: (_) => setState((){}),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      ),
    );
  }
}