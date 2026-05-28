import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class InternalReportPdfEditor extends StatefulWidget {
  final String orderId;
  const InternalReportPdfEditor({super.key, required this.orderId});

  @override
  State<InternalReportPdfEditor> createState() => _InternalReportPdfEditorState();
}

class _InternalReportPdfEditorState extends State<InternalReportPdfEditor> {
  bool _isLoading = true;
  bool _isChinese = false;

  final _titleCtrl = TextEditingController(text: "INTERNAL PROFIT ANALYSIS");
  final _preparedByCtrl = TextEditingController(text: "Management");
  final _noteCtrl = TextEditingController();

  Map<String, dynamic>? _orderData;
  final List<Map<String, dynamic>> _reportItems = [];
  double _totalRevenue = 0;
  double _totalCost = 0;

  static const PdfColor _journeytaleBlue = PdfColor.fromInt(0xFF00A0E9);
  static const PdfColor _journeytaleOrange = PdfColor.fromInt(0xFFF5A623);
  static const PdfColor _lightGreyBg = PdfColor.fromInt(0xFFF2F2F2);

  Map<String, String> get _labels => _isChinese ? {
    'header_title': '内部财务报表',
    'header_subtitle': '机密财务分析',
    'order_ref': '订单编号:',
    'client_group': '客户组:',
    'destination': '目的地:',
    'date': '日期:',
    'prepared_by': '制表人:',
    'note': '备注:',
    'col_type': '类型',
    'col_desc': '描述',
    'col_rev': '收入 (客户)',
    'col_cost': '成本 (内部)',
    'col_profit': '利润',
    'total_rev': '总收入:',
    'total_cost': '总成本:',
    'net_profit': '净利润',
    'footer': '机密文件 - 仅限内部使用',
  } : {
    'header_title': 'journeytale Internal',
    'header_subtitle': 'Confidential Financial Report',
    'order_ref': 'Order Ref:',
    'client_group': 'Client Group:',
    'destination': 'Destination:',
    'date': 'Date:',
    'prepared_by': 'Prepared By:',
    'note': 'Note:',
    'col_type': 'Type',
    'col_desc': 'Description',
    'col_rev': 'Revenue (Client)',
    'col_cost': 'Cost (Internal)',
    'col_profit': 'Profit',
    'total_rev': 'Total Revenue:',
    'total_cost': 'Total Internal Cost:',
    'net_profit': 'NET PROFIT',
    'footer': 'CONFIDENTIAL - INTERNAL USE ONLY',
  };

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Helper to safely parse numbers
  double getDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is int) return val.toDouble();
    if (val is double) return val;
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  Future<void> _fetchData() async {
    try {
      final orderDoc = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
      
      // FETCH ALL SUBCOLLECTIONS
      final results = await Future.wait([
        orderDoc.reference.collection('services').get(),      // 0
        orderDoc.reference.collection('transport').get(),     // 1
        orderDoc.reference.collection('tickets').get(),       // 2
        orderDoc.reference.collection('additional').get(),    // 3
        orderDoc.reference.collection('flights').get(),       // 4
        orderDoc.reference.collection('trains').get(),        // 5
        orderDoc.reference.collection('hotels').get(),        // 6
        orderDoc.reference.collection('tourguides').get(),    // 7
      ]);

      if (orderDoc.exists) {
        _orderData = orderDoc.data();
        _reportItems.clear();
        _totalRevenue = 0;
        _totalCost = 0;

        void addItem(String type, String desc, double rev, double cost) {
          _reportItems.add({'type': type, 'desc': desc, 'rev': rev, 'cost': cost});
          _totalRevenue += rev;
          _totalCost += cost;
        }

        // 1. Services
        for (var d in results[0].docs) {
          final s = d.data();
          double days = getDouble(s['days'] ?? 1);
          double rev = (getDouble(s['price_per_day']) * days) - getDouble(s['discount']);
          double cost = getDouble(s['modal_per_day']) * days;
          addItem("Service", s['name'] ?? 'Service', rev, cost);
        }

        // 2. Transport
        for (var d in results[1].docs) {
          final t = d.data();
          addItem("Transport", t['route_title'] ?? 'Route', getDouble(t['fee']), getDouble(t['cost']));
        }

        // 3. Tickets
        for (var d in results[2].docs) {
          final t = d.data();
          addItem("Ticket", t['spot_name'] ?? 'Ticket', getDouble(t['total_price']), getDouble(t['total_cost']));
        }

        // 4. Additional Fees
        for (var d in results[3].docs) {
          final f = d.data();
          addItem("Fee", f['description'] ?? 'Fee', getDouble(f['amount']), getDouble(f['cost']));
        }

        // 5. Flights
        for (var d in results[4].docs) {
          final f = d.data();
          String desc = "Flight ${f['flight_number'] ?? ''} (${f['departure_city'] ?? ''}-${f['arrival_city'] ?? ''})";
          addItem("Flight", desc, getDouble(f['client_price']), getDouble(f['internal_price']));
        }

        // 6. Trains
        for (var d in results[5].docs) {
          final t = d.data();
          String desc = "Train ${t['train_number'] ?? ''} (${t['departure_city'] ?? ''}-${t['arrival_city'] ?? ''})";
          addItem("Train", desc, getDouble(t['client_price']), getDouble(t['internal_price']));
        }

        // 7. Hotels
        for (var d in results[6].docs) {
          final h = d.data();
          double nights = getDouble(h['nights'] ?? 1);
          String desc = "${h['name'] ?? 'Hotel'} ($nights nights)";
          // Revenue: Client Price (Total)
          // Cost: Base Price * Nights
          addItem("Hotel", desc, getDouble(h['client_price']), getDouble(h['base_price']) * nights);
        }

        // 8. Tour Guides
        for (var d in results[7].docs) {
          final g = d.data();
          addItem("Guide", g['name'] ?? 'Tour Guide', getDouble(g['client_price']), getDouble(g['internal_price']));
        }
      }
    } catch (e) {
      debugPrint("Error generating report data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- PDF GENERATION ---

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    
    final fontRegular = await PdfGoogleFonts.notoSansSCRegular();
    final fontBold = await PdfGoogleFonts.notoSansSCBold();
    // Defaulting to RMB symbol as per previous requirement, change if needed
    final format = NumberFormat.simpleCurrency(decimalDigits: 0, name: '¥', locale: 'zh_CN'); 

    final netProfit = _totalRevenue - _totalCost;
    final profitColor = netProfit >= 0 ? PdfColors.green700 : PdfColors.red700;

    final ByteData data = await rootBundle.load('assets/Explore city like a local.png');
    final Uint8List bytes = data.buffer.asUint8List();
    final logoImage = pw.MemoryImage(bytes);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      build: (pw.Context context) {
        return [
          // HEADER BAR
          pw.Container(height: 8, color: _journeytaleBlue),
          pw.SizedBox(height: 20),

          // TITLE ROW
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(_labels['header_title']!, style: pw.TextStyle(color: _journeytaleBlue, fontSize: 32, fontWeight: pw.FontWeight.bold)),
                pw.Text(_labels['header_subtitle']!, style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
              ]),
              pw.Container(
                height: 40, width: 40, 
                child: pw.Image(logoImage) // Using the logo
              )
            ]
          ),
          pw.SizedBox(height: 30),

          // META DATA ROW
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(_titleCtrl.text, style: pw.TextStyle(color: _journeytaleOrange, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                //pw.Text("${_labels['order_ref']} ${widget.orderId.substring(0, 8).toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                //pw.Text("${_labels['client_group']} ${_orderData?['name'] ?? 'Unknown'}"),
                //pw.Text("${_labels['destination']} ${_orderData?['destination'] ?? ''}"),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text("${_labels['date']} ${DateFormat('dd MMM yyyy').format(DateTime.now())}"),
                pw.Text("${_labels['prepared_by']} ${_preparedByCtrl.text}"),
                if(_noteCtrl.text.isNotEmpty) 
                  pw.Container(
                    width: 200,
                    margin: const pw.EdgeInsets.only(top: 10),
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(color: PdfColors.amber50, border: pw.Border.all(color: PdfColors.amber200)),
                    child: pw.Text("${_labels['note']} ${_noteCtrl.text}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))
                  )
              ])
            ]
          ),
          pw.SizedBox(height: 30),

          // TABLE HEADER
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            color: _journeytaleBlue,
            child: pw.Row(children: [
              pw.Expanded(flex: 2, child: pw.Text(_labels['col_type']!, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.Expanded(flex: 5, child: pw.Text(_labels['col_desc']!, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.Expanded(flex: 3, child: pw.Text(_labels['col_rev']!, textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.Expanded(flex: 3, child: pw.Text(_labels['col_cost']!, textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.Expanded(flex: 3, child: pw.Text(_labels['col_profit']!, textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10))),
            ])
          ),

          // TABLE ROWS
          ..._reportItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final itemProfit = (item['rev'] as double) - (item['cost'] as double);
            final bg = idx % 2 == 0 ? _lightGreyBg : PdfColors.white;
            final pColor = itemProfit >= 0 ? PdfColors.green700 : PdfColors.red700;

            return pw.Container(
              color: bg,
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: pw.Row(children: [
                pw.Expanded(flex: 2, child: pw.Text(item['type'], style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
                pw.Expanded(flex: 5, child: pw.Text(item['desc'], style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 3, child: pw.Text(format.format(item['rev']), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(flex: 3, child: pw.Text(format.format(item['cost']), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10, color: PdfColors.red900))),
                pw.Expanded(flex: 3, child: pw.Text(format.format(itemProfit), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: pColor))),
              ])
            );
          }),

          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.SizedBox(height: 10),

          // TOTALS
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 250,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: profitColor, width: 2),
                  borderRadius: pw.BorderRadius.circular(8),
                  color: netProfit >= 0 ? PdfColors.green50 : PdfColors.red50
                ),
                child: pw.Column(children: [
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text(_labels['total_rev']!),
                    pw.Text(format.format(_totalRevenue), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
                  ]),
                  pw.SizedBox(height: 4),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text(_labels['total_cost']!),
                    pw.Text(format.format(_totalCost), style: const pw.TextStyle(color: PdfColors.red900))
                  ]),
                  pw.Divider(color: profitColor),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text(_labels['net_profit']!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.Text(format.format(netProfit), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: profitColor))
                  ]),
                ])
              )
            ]
          ),

          pw.Spacer(),
          pw.Text(_labels['footer']!, style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
        ];
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
      appBar: AppBar(
        title: const Text("Internal Financial Report"), 
        backgroundColor: Colors.white, 
        elevation: 0, 
        foregroundColor: Colors.black
      ),
      body: Row(
        children: [
          Container(
            width: 350,
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const Text("Report Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _input(_titleCtrl, "Report Title"),
                  _input(_preparedByCtrl, "Prepared By"),
                  _input(_noteCtrl, "Internal Notes", maxLines: 4),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  _statRow("Revenue", _totalRevenue, Colors.blue),
                  _statRow("Cost", _totalCost, Colors.red),
                  const SizedBox(height: 10),
                  _statRow("Net Profit", _totalRevenue - _totalCost, (_totalRevenue - _totalCost) >= 0 ? Colors.green : Colors.red, isBold: true),
                  const SizedBox(height: 30),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () async { final bytes = await _generatePdf(); await Printing.layoutPdf(onLayout: (_) async => bytes); }, icon: const Icon(Icons.print), label: const Text("Print Report"),)),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () async { final bytes = await _generatePdf(); await Printing.sharePdf(bytes: bytes, filename: 'ProfitReport_${widget.orderId.substring(0,5)}.pdf'); }, icon: const Icon(Icons.download), label: const Text("Download PDF")))
                ],
              ),
            ),
          ),
          Expanded(child: PdfPreview(build: (format) => _generatePdf(), canChangeOrientation: false, canChangePageFormat: false, canDebug: false, padding: const EdgeInsets.all(20)))
        ],
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: ctrl, maxLines: maxLines, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true)));
  }

  Widget _statRow(String label, double value, Color color, {bool isBold = false}) {
    final fmt = NumberFormat.simpleCurrency(decimalDigits: 0, name: '¥');
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)), Text(fmt.format(value), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: isBold ? 16 : 14))]));
  }
}