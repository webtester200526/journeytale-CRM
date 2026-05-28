import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/service_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:crmx/service_model.dart';

class TicketPdfEditorPage extends StatefulWidget {
  final String orderId;
  final OrderModel orderModel;

  const TicketPdfEditorPage({super.key, required this.orderId, required this.orderModel});

  @override
  State<TicketPdfEditorPage> createState() => _TicketPdfEditorPageState();
}

class _TicketPdfEditorPageState extends State<TicketPdfEditorPage> {
  // Supplier / Header Info
  final _supplierNameCtrl = TextEditingController(text: "Ticket Vendor / Agent");
  final _supplierContactCtrl = TextEditingController();
  final _orderNoCtrl = TextEditingController();
  final _noteCtrl = TextEditingController(text: "Please issue tickets for the following:");

  List<Map<String, dynamic>> _ticketItems = [];
  bool _isLoading = true;
  
  // Language State
  bool _isChinese = false;

  // Design Colors
  static const PdfColor _journeytaleBlue = PdfColor.fromInt(0xFF00A0E9);
  static const PdfColor _journeytaleOrange = PdfColor.fromInt(0xFFF5A623);
  static const PdfColor _tableHeaderBlue = PdfColor.fromInt(0xFF00A0E9);
  static const PdfColor _lightGreyBg = PdfColor.fromInt(0xFFF2F2F2);

  // --- TRANSLATION MAP ---
  Map<String, String> get _labels => _isChinese ? {
    'subtitle': '您的东方之旅',
    'header_title': '门票预订单',
    'to': '致供应商:',
    'note': '备注:',
    'order_no': '订单号:',
    'client': '客户:',
    'col_no': '序号',
    'col_date': '日期',
    'col_city': '城市',
    'col_attraction': '景点门票',
    'col_qty': '数量',
    'col_total': '总价',
    'footer': '请在24小时内确认出票。',
  } : {
    'subtitle': 'Explore city like a local',
    'header_title': 'TICKET ORDER',
    'to': 'To:',
    'note': 'Note:',
    'order_no': 'Order No:',
    'client': 'Client:',
    'col_no': 'No.',
    'col_date': 'Date',
    'col_city': 'City',
    'col_attraction': 'Attraction / Ticket',
    'col_qty': 'Qty',
    'col_total': 'Total',
    'footer': 'Please confirm availability within 24 hours.',
  };

  @override
  void initState() {
    super.initState();
    _orderNoCtrl.text = "TKT-${DateFormat('yyyyMMdd').format(DateTime.now())}-${widget.orderId.substring(0, 3).toUpperCase()}";
    _loadData();
  }

  Future<void> _loadData() async {
    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .collection('tickets')
        .orderBy('date')
        .get();

    setState(() {
      _ticketItems = snap.docs.map((d) => d.data()).toList();
      _isLoading = false;
    });
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    final ByteData data = await rootBundle.load('assets/Explore city like a local.png');
    final Uint8List bytes = data.buffer.asUint8List();

    // Create the PDF Image provider
    final logoImage = pw.MemoryImage(bytes);
    // Support Chinese characters
    final fontRegular = await PdfGoogleFonts.notoSansSCRegular();
    final fontBold = await PdfGoogleFonts.notoSansSCBold();
    
    final dateFormat = DateFormat('yyyy-MM-dd');

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
              ]
            ),
            pw.SizedBox(height: 30),

            // 3. BOOKING ORDER TITLE
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(_labels['header_title']!, style: pw.TextStyle(color: _journeytaleOrange, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text("${_labels['to']} ${_supplierNameCtrl.text}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    if(_supplierContactCtrl.text.isNotEmpty) pw.Text(_supplierContactCtrl.text),
                    pw.SizedBox(height: 10),
                    pw.Text("${_labels['note']} ${_noteCtrl.text}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ])
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.SizedBox(height: 30),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text(_labels['order_no']!, style: const pw.TextStyle(color: PdfColors.grey700)),
                      pw.Text(_orderNoCtrl.text, style: const pw.TextStyle(color: PdfColors.black)),
                    ]),
                    pw.SizedBox(height: 5),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text(_labels['client']!, style: const pw.TextStyle(color: PdfColors.grey700)),
                      pw.Text(widget.orderModel.name, style: pw.TextStyle(color: _journeytaleOrange, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ])
                )
              ]
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            // 4. TABLE HEADER
            pw.Row(children: [
              pw.Expanded(flex: 1, child: pw.Text(_labels['col_no']!, style: pw.TextStyle(color: _tableHeaderBlue, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 2, child: pw.Text(_labels['col_date']!, style: pw.TextStyle(color: _tableHeaderBlue, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 2, child: pw.Text(_labels['col_city']!, style: pw.TextStyle(color: _tableHeaderBlue, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 4, child: pw.Text(_labels['col_attraction']!, style: pw.TextStyle(color: _tableHeaderBlue, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 3, child: pw.Text(_labels['col_qty']!, style: pw.TextStyle(color: _tableHeaderBlue, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 2, child: pw.Text(_labels['col_total']!, textAlign: pw.TextAlign.right, style: pw.TextStyle(color: _journeytaleOrange, fontWeight: pw.FontWeight.bold))),
            ]),
            pw.SizedBox(height: 5),

            // 5. TABLE ROWS
            ..._ticketItems.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final data = entry.value;
              final date = (data['date'] as Timestamp).toDate();
              
              // --- CURRENCY LOGIC START ---
              // Determine Price based on intended audience (Supplier gets 'total_cost', usually)
              // If this PDF is for the client, use 'total_price'.
              // Assuming this is for Supplier booking -> Use 'total_cost' (Internal Price) 
              // *Change 'total_cost' to 'total_price' if this PDF is for the Client*
              final amount = (data['total_cost'] as num?)?.toDouble() ?? 0;
              
              final currencyCode = data['currency'] ?? 'RMB';
              final format = NumberFormat.simpleCurrency(name: currencyCode, decimalDigits: 0);
              final priceStr = format.format(amount);
              // --- CURRENCY LOGIC END ---

              // Format breakdown string
              final qtys = data['quantities'] as Map<String, dynamic>? ?? {};
              final breakdownList = <String>[];
              qtys.forEach((k, v) { if((v as num) > 0) breakdownList.add("$v $k"); });
              
              return pw.Container(
                color: _lightGreyBg,
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Row(children: [
                  pw.Expanded(flex: 1, child: pw.Text("$index", style: const pw.TextStyle(color: PdfColors.grey600))),
                  pw.Expanded(flex: 2, child: pw.Text(dateFormat.format(date))),
                  pw.Expanded(flex: 2, child: pw.Text(data['city_name'] ?? '-')),
                  pw.Expanded(flex: 4, child: pw.Text(data['spot_name'] ?? '-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 3, child: pw.Text(breakdownList.join(", "), style: const pw.TextStyle(fontSize: 10))),
                  // Display Formatted Price
                  pw.Expanded(flex: 2, child: pw.Text(priceStr, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ])
              );
            }),

            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Center(child: pw.Text(_labels['footer']!, style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10))),
          ];
        },
      )
    );
    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Generate Ticket Order"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Row(
        children: [
          // LEFT: CONTROLS
          Container(
            width: 350,
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LANGUAGE TOGGLE ---
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

                  const Text("Vendor Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _input(_supplierNameCtrl, "Supplier Name"),
                  _input(_supplierContactCtrl, "Contact Info (Phone/WeChat)"),
                  _input(_orderNoCtrl, "Order Reference No"),
                  _input(_noteCtrl, "Order Notes", maxLines: 3),
                  
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
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final bytes = await _generatePdf();
                        await Printing.sharePdf(bytes: bytes, filename: 'TicketOrder_${_orderNoCtrl.text}.pdf');
                      },
                      icon: const Icon(Icons.download),
                      label: const Text("Download PDF"),
                    ),
                  )
                ],
              ),
            ),
          ),
          
          // RIGHT: PREVIEW
          Expanded(
            child: PdfPreview(
              build: (format) => _generatePdf(),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              padding: const EdgeInsets.all(20),
            ),
          ),
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
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          isDense: true,
        ),
      ),
    );
  }
}