import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:crmx/service_model.dart';

class TransportPdfEditorPage extends StatefulWidget {
  final String orderId;
  final OrderModel orderModel;

  const TransportPdfEditorPage({super.key, required this.orderId, required this.orderModel});

  @override
  State<TransportPdfEditorPage> createState() => _TransportPdfEditorPageState();
}

class _TransportPdfEditorPageState extends State<TransportPdfEditorPage> {
  // Supplier Info Controllers
  final _supplierNameCtrl = TextEditingController();
  final _supplierContactCtrl = TextEditingController();
  final _supplierPhoneCtrl = TextEditingController();
  final _areaCtrl = TextEditingController(text: "Shanghai 上海");
  final _orderNoCtrl = TextEditingController();

  List<Map<String, dynamic>> _transportItems = [];
  bool _isLoading = true;
  bool _isChinese = false;

  // Colors based on the image provided
  static const PdfColor _journeytaleBlue = PdfColor.fromInt(0xFF00A0E9);
  static const PdfColor _journeytaleOrange = PdfColor.fromInt(0xFFF5A623);
  static const PdfColor _tableHeaderBlue = PdfColor.fromInt(0xFF00A0E9);
  static const PdfColor _lightGreyBg = PdfColor.fromInt(0xFFF2F2F2);

  // --- TRANSLATION MAP ---
  Map<String, String> get _labels => _isChinese ? {
    'subtitle': '您的东方之旅',
    'header_title': '预订单',
    'to': '致:',
    'area': '地区:',
    'order_no': '订单号:',
    'col_no': '序号',
    'col_desc': '项目描述',
    'col_qty': '数量',
    'col_price': '单价',
    'col_total': '总计',
    'date': '日期:',
    'pax': '人数:',
    'luggage': '行李',
    'vehicle': '车型:',
    'plate': '接机牌:',
    'client': '客户名:',
    'subtotal': 'Subtotal 小计',
    'total': 'Total 合计',
    'requests_title': 'Requests 注意事项:',
    'req_1': '车辆须准时到达指定接送地点。',
    'req_2': '车辆必须保持干净、无异味且状况良好。',
    'req_3': '司机不得有烟味，应保持个人清洁。',
    'req_4': '司机须礼貌、友善，禁止说粗口，并在需要时协助乘客搬运行李。',
    'req_5': '在机场接送的情况下，司机须在到达大厅迎接客人。\n司机必备写客人姓名的接机牌或纸牌，字体清晰可见，并且司机在到达大厅举牌等候客人。',
  } : {
    'subtitle': 'Explore city like a local',
    'header_title': 'Booking Order',
    'to': 'To:',
    'area': 'Area:',
    'order_no': 'Order Number:',
    'col_no': 'No.',
    'col_desc': 'Description',
    'col_qty': 'Qty',
    'col_price': 'Price',
    'col_total': 'Total',
    'date': 'Date:',
    'pax': 'Pax:',
    'luggage': 'Luggage',
    'vehicle': 'Vehicle:',
    'plate': 'Sign/Board:',
    'client': 'Client Name:',
    'subtotal': 'Subtotal',
    'total': 'Total',
    'requests_title': 'Requests / Terms:',
    'req_1': 'Vehicle must arrive on time at the designated location.',
    'req_2': 'Vehicle must be clean, odorless, and in good condition.',
    'req_3': 'Driver must not smell of smoke and should maintain personal hygiene.',
    'req_4': 'Driver must be polite, friendly, refrain from profanity, and assist with luggage when needed.',
    'req_5': 'For airport transfers, driver must meet guests at the arrival hall.\nDriver must hold a clear sign/board with the guest\'s name.',
  };

  @override
  void initState() {
    super.initState();
    _orderNoCtrl.text = "${DateFormat('yyyyMMdd').format(DateTime.now())}-${widget.orderId.substring(0, 3).toUpperCase()}";
    _loadData();
  }

  Future<void> _loadData() async {
    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .collection('transport')
        .orderBy('date')
        .get();

    setState(() {
      _transportItems = snap.docs.map((d) => d.data()).toList();
      _isLoading = false;
    });
  }

  // --- PDF GENERATION LOGIC ---
  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    
    // SAFE IMAGE LOADING
    pw.MemoryImage? logoImage;
    pw.MemoryImage? logoImage2;

    try {
      final ByteData data = await rootBundle.load('assets/Explore city like a local.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      debugPrint("Logo 1 missing");
    }

    try {
      final ByteData data2 = await rootBundle.load('assets/3.png');
      logoImage2 = pw.MemoryImage(data2.buffer.asUint8List());
    } catch (e) {
      debugPrint("Logo 2 missing");
    }
    
    // SAFE FONT LOADING
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      fontRegular = await PdfGoogleFonts.notoSansSCRegular(); 
      fontBold = await PdfGoogleFonts.notoSansSCBold();
    } catch (e) {
      fontRegular = pw.Font.courier();
      fontBold = pw.Font.courierBold();
    }

    final dateFormat = DateFormat('yyyy-MM-dd');
    
    // Calculate Total
    double totalCost = 0;
    String currencyCode = 'RMB '; // Default
    for (var item in _transportItems) {
      totalCost += (item['cost'] as num?)?.toDouble() ?? 0;
      currencyCode = item['currency'] ?? 'RMB ';
    }
    final format = NumberFormat.simpleCurrency(name: currencyCode, decimalDigits: 0);
    final totalStr = format.format(totalCost);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return [
            // 1. TOP COLOR BAR
            pw.Container(height: 8, color: _journeytaleBlue),
            pw.SizedBox(height: 20),

            // 2. HEADER LOGOS
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null) pw.Image(logoImage, width: 180),
                if (logoImage2 != null) pw.Image(logoImage2, width: 80),
              ]
            ),
            pw.SizedBox(height: 30),

            // 3. TITLE & INFO BLOCK
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Left: To Supplier
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(_labels['header_title']!, style: pw.TextStyle(color: _journeytaleOrange, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 10),
                      pw.Text(_labels['to']!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                      pw.Text(_supplierNameCtrl.text, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text(_supplierContactCtrl.text),
                      pw.Text(_supplierPhoneCtrl.text),
                    ]
                  )
                ),
                // Right: Area & Order No
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.SizedBox(height: 25), 
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(_labels['area']!, style: pw.TextStyle(color: _journeytaleBlue, fontWeight: pw.FontWeight.bold)),
                          pw.Text(_areaCtrl.text, style: pw.TextStyle(color: _journeytaleOrange, fontWeight: pw.FontWeight.bold)),
                        ]
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(_labels['order_no']!, style: const pw.TextStyle(color: PdfColors.grey700)),
                          pw.Text(_orderNoCtrl.text, style: const pw.TextStyle(color: PdfColors.black)),
                        ]
                      ),
                    ]
                  )
                )
              ]
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            // 4. TABLE HEADERS
            pw.Row(
              children: [
                pw.Expanded(flex: 1, child: pw.Text(_labels['col_no']!, style: pw.TextStyle(color: _tableHeaderBlue, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 8, child: pw.Text(_labels['col_desc']!, style: pw.TextStyle(color: _tableHeaderBlue, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 2, child: pw.Text(_labels['col_qty']!, textAlign: pw.TextAlign.center, style: pw.TextStyle(color: _tableHeaderBlue, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 2, child: pw.Text(_labels['col_price']!, textAlign: pw.TextAlign.right, style: pw.TextStyle(color: _tableHeaderBlue, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 2, child: pw.Text(_labels['col_total']!, textAlign: pw.TextAlign.right, style: pw.TextStyle(color: _journeytaleOrange, fontWeight: pw.FontWeight.bold))),
              ]
            ),
            pw.SizedBox(height: 5),

            // 5. TABLE ROWS
            ..._transportItems.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final data = entry.value;
              final date = (data['date'] as Timestamp).toDate();
              final price = (data['cost'] as num?)?.toDouble() ?? 0; 
              final priceStr = format.format(price);

              return pw.Container(
                color: _lightGreyBg,
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                margin: const pw.EdgeInsets.only(bottom: 15),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(flex: 1, child: pw.Text("$index", style: const pw.TextStyle(color: PdfColors.grey600))),
                    
                    pw.Expanded(
                      flex: 8,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(data['route_title'] ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                          pw.SizedBox(height: 4),
                          pw.Text("${_labels['date']} ${dateFormat.format(date)}"),
                          pw.Text(data['route_details'] ?? '', style: const pw.TextStyle(fontSize: 10, lineSpacing: 2)),
                          pw.SizedBox(height: 8),
                          pw.Text("${_labels['pax']} ${data['pax'] ?? 0}  (${data['luggage'] ?? 0} ${_labels['luggage']})", style: const pw.TextStyle(fontSize: 10)),
                          pw.Text("${_labels['vehicle']} ${data['vehicle'] ?? ''}", style: const pw.TextStyle(fontSize: 10)),
                          if (data['plate'] != null && data['plate'].toString().isNotEmpty)
                             pw.Text("${_labels['plate']} ${data['plate']}", style: const pw.TextStyle(fontSize: 10)),
                          if (data['notes'] != null && data['notes'].toString().isNotEmpty)
                             pw.Text("*${data['notes']}", style: const pw.TextStyle(fontSize: 10)),
                        ]
                      )
                    ),
                    pw.Expanded(flex: 2, child: pw.Text("1", textAlign: pw.TextAlign.center, style: const pw.TextStyle(color: PdfColors.grey600))),
                    pw.Expanded(flex: 2, child: pw.Text(priceStr, textAlign: pw.TextAlign.right, style: const pw.TextStyle(color: PdfColors.grey600))),
                    pw.Expanded(flex: 2, child: pw.Text(priceStr, textAlign: pw.TextAlign.right, style:  pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ]
                )
              );
            }),

            // 6. TOTAL BAR (Moved Below Items)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 250,
                child: pw.Column(
                  children: [
                    // Subtotal Row
                    pw.Container(
                      color: _lightGreyBg,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(_labels['subtotal']!, style: pw.TextStyle(color: _journeytaleOrange, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text(totalStr, style: pw.TextStyle(color: _journeytaleBlue, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        ]
                      )
                    ),
                    // Total Row
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 100,
                          color: _journeytaleOrange,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          alignment: pw.Alignment.center,
                          child: pw.Text(_labels['total']!, style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Expanded(
                          child: pw.Container(
                            color: _journeytaleBlue,
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(totalStr, style: pw.TextStyle(color: _journeytaleOrange, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          )
                        )
                      ]
                    )
                  ]
                )
              )
            ),

            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 10),

            // 7. REQUESTS SECTION
            pw.Row(
              children: [
                pw.Text(_labels['requests_title']!, style: pw.TextStyle(color: _journeytaleBlue, fontWeight: pw.FontWeight.bold, fontSize: 14)),
              ]
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              color: _lightGreyBg,
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildReqRow(1, _labels['req_1']!),
                  _buildReqRow(2, _labels['req_2']!),
                  _buildReqRow(3, _labels['req_3']!),
                  _buildReqRow(4, _labels['req_4']!),
                  _buildReqRow(5, _labels['req_5']!),
                ]
              )
            ),
            // Bottom Orange Bar
            pw.Container(height: 8, color: _journeytaleOrange, margin: const pw.EdgeInsets.only(top: 0)),
          ];
        },
      )
    );

    return pdf.save();
  }

  pw.Widget _buildReqRow(int no, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 20, child: pw.Text("$no", style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 10))),
        ]
      )
    );
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Generate Booking Order PDF"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Row(
        children: [
          // LEFT PANEL: Controls
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

                  const Text("Supplier Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _input(_supplierNameCtrl, "Company Name", hint: "e.g. 嘉腾巴士"),
                  _input(_supplierContactCtrl, "Contact Person", hint: "e.g. 徐磊"),
                  _input(_supplierPhoneCtrl, "Phone", hint: "e.g. 18049888878"),
                  _input(_areaCtrl, "Area / Region"),
                  const Divider(height: 30),
                  const Text("Order Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _input(_orderNoCtrl, "Order Number"),
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
                      
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final bytes = await _generatePdf();
                        await Printing.sharePdf(bytes: bytes, filename: 'BookingOrder_${_orderNoCtrl.text}.pdf');
                      },
                      icon: const Icon(Icons.download),
                      label: const Text("Download PDF"),
                    ),
                  )
                ],
              ),
            ),
          ),
          
          // RIGHT PANEL: Live Preview
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

  Widget _input(TextEditingController ctrl, String label, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          isDense: true,
        ),
      ),
    );
  }
}