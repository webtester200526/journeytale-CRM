import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

// --- MODELS ---

class InvoiceProfile {
  final String id;
  final String profileName;
  final String senderName;
  final String senderEmail;
  final String senderPhone;
  final String paymentInfo;

  InvoiceProfile({
    required this.id,
    required this.profileName,
    required this.senderName,
    required this.senderEmail,
    required this.senderPhone,
    required this.paymentInfo,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': 'invoice_profile',
      'profileName': profileName,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'senderPhone': senderPhone,
      'paymentInfo': paymentInfo,
    };
  }

  factory InvoiceProfile.fromMap(String id, Map<String, dynamic> map) {
    return InvoiceProfile(
      id: id,
      profileName: map['profileName'] ?? 'Unnamed',
      senderName: map['senderName'] ?? '',
      senderEmail: map['senderEmail'] ?? '',
      senderPhone: map['senderPhone'] ?? '',
      paymentInfo: map['paymentInfo'] ?? '',
    );
  }
}

// --- MAIN WIDGET ---

class InvoiceEditorPage extends StatefulWidget {
  final String orderId;

  const InvoiceEditorPage({super.key, required this.orderId});

  @override
  State<InvoiceEditorPage> createState() => _InvoiceEditorPageState();
}

class _InvoiceEditorPageState extends State<InvoiceEditorPage> {
  bool _isLoading = true;
  bool _isChinese = false;

  // --- RESOURCES CACHE (FIXED) ---
  pw.Font? _fontRegular;
  pw.Font? _fontBold;
  pw.MemoryImage? _logoImage1;
  pw.MemoryImage? _logoImage2;
  bool _resourcesLoaded = false;

  // Data Containers
  Map<String, dynamic>? _orderData;
  String _orderNotes = "";
  final List<Map<String, dynamic>> _invoiceItems = [];

  List<InvoiceProfile> _savedProfiles = [];
  InvoiceProfile? _selectedProfile;

  // Controllers
  final _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _invoiceNoCtrl = TextEditingController();
  final _invoiceDateCtrl = TextEditingController();

  // Sender Profile Controllers
  final _profileNameCtrl = TextEditingController();
  final _senderNameCtrl = TextEditingController(text: "journeytale Travels");
  final _senderEmailCtrl = TextEditingController(text: "contact@journeytale.com");
  final _senderPhoneCtrl = TextEditingController();
  final _bankInfoCtrl = TextEditingController(
      text:
          "Bank: Bank Central Asia (BCA)\nAccount No.: 449 - 038 - 6802\nAccount Name: Franky/Victor");

  // PDF Styles
  static const PdfColor _journeytaleBlue = PdfColor.fromInt(0xFF28A0DC);
  static const PdfColor _journeytaleOrange = PdfColor.fromInt(0xFFF6A623);
  static const PdfColor _tableHeaderBlue = PdfColor.fromInt(0xFF28A0DC);
  static const PdfColor _itemRowBg = PdfColor.fromInt(0xFFF7F7F7);

  // TRANSLATION MAP
  Map<String, String> get _labels => _isChinese
      ? {
          'client_label': 'Client (客户):',
          'name': 'Name (姓名)',
          'phone': 'Phone (电话)',
          'invoice_no': 'Invoice # (发票号)',
          'date': 'Date (日期)',
          'col_no': '序号',
          'col_desc': 'Description (项目描述)',
          'col_qty': 'Qty (数量)',
          'col_price': 'Price (单价)',
          'col_total': 'Total (总价)',
          'subtotal': 'Subtotal (小计)',
          'payment_info': 'Payment Information (付款信息):',
          'total_label': 'TOTAL (总额)',
          'footer_text': '@ journeytaleTRAVEL',
          'notes_label': 'Notes / 注意事项:',
        }
      : {
          'client_label': 'Client:',
          'name': 'Name',
          'phone': 'Phone Number',
          'invoice_no': 'Invoice #',
          'date': 'Date',
          'col_no': 'No.',
          'col_desc': 'Description',
          'col_qty': 'Qty',
          'col_price': 'Price',
          'col_total': 'Total',
          'subtotal': 'Subtotal',
          'payment_info': 'Payment Information:',
          'total_label': 'TOTAL',
          'footer_text': '@ journeytaleTRAVEL',
          'notes_label': 'Notes:',
        };

  @override
  void initState() {
    super.initState();
    // Load resources and data in parallel
    Future.wait([
      _fetchData(),
      _loadPdfResources(),
    ]);
  }

  // --- 1. LOAD FONTS & IMAGES ONCE (FIXED) ---
  Future<void> _loadPdfResources() async {
    try {
      // Load Fonts (Use NotoSansSC for Chinese Support)
      // Note: This requires internet access the first time run
      try {
        _fontRegular = await PdfGoogleFonts.notoSansSCRegular();
        _fontBold = await PdfGoogleFonts.notoSansSCBold();
      } catch (e) {
        debugPrint("Font download failed: $e");
        // Fallback (Warning: Chinese will not render with Courier)
        _fontRegular = pw.Font.courier();
        _fontBold = pw.Font.courierBold();
      }

      // Load Images
      try {
        final ByteData data = await rootBundle.load('assets/Explore city like a local.png');
        _logoImage1 = pw.MemoryImage(data.buffer.asUint8List());
      } catch (e) {
        debugPrint("Logo 1 load error: $e");
      }

      try {
        final ByteData data2 = await rootBundle.load('assets/3.png');
        _logoImage2 = pw.MemoryImage(data2.buffer.asUint8List());
      } catch (e) {
        debugPrint("Logo 2 load error: $e");
      }

    } catch (e) {
      debugPrint("General Resource Error: $e");
    } finally {
      if (mounted) {
        setState(() => _resourcesLoaded = true);
      }
    }
  }

  Future<void> _fetchData() async {
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      final servicesSnap =
          await orderDoc.reference.collection('services').get();
      final transportSnap =
          await orderDoc.reference.collection('transport').orderBy('date').get();
      final ticketSnap =
          await orderDoc.reference.collection('tickets').orderBy('date').get();
      final feesSnap = await orderDoc.reference.collection('additional').get();

      final profilesSnap = await FirebaseFirestore.instance
          .collection('utilities')
          .where('type', isEqualTo: 'invoice_profile')
          .get();

      if (orderDoc.exists) {
        final data = orderDoc.data()!;
        _orderData = data;
        _orderNotes = data['notes'] ?? '';

        _clientNameCtrl.text = data['name'] ?? '';
        _clientPhoneCtrl.text = data['client_phone'] ?? '';

        String dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
        String shortId = widget.orderId.length > 4
            ? widget.orderId.substring(0, 4).toUpperCase()
            : widget.orderId;
        _invoiceNoCtrl.text = "$dateStr-$shortId";
        _invoiceDateCtrl.text =
            DateFormat('dd MMM yyyy').format(DateTime.now());

        // --- COMPILE INVOICE ITEMS ---
        _invoiceItems.clear();

        // 1. Services
        for (var doc in servicesSnap.docs) {
          final s = doc.data();
          final price = (s['price_per_day'] as num?)?.toDouble() ?? 0.0;
          final days = (s['days'] as num?)?.toInt() ?? 1;
          final discount = (s['discount'] as num?)?.toDouble() ?? 0.0;
          final desc = s['description'] ?? '';

          String dateText = "";
          if (s['start_date'] != null) {
            final start = (s['start_date'] as Timestamp).toDate();
            final end = s['end_date'] != null
                ? (s['end_date'] as Timestamp).toDate()
                : start.add(Duration(days: days - 1));
            dateText = "${DateFormat('dd MMM yyyy').format(start)}";
            if (days > 1)
              dateText += " - ${DateFormat('dd MMM yyyy').format(end)}";
          }

          String fullDesc = s['name'] ?? "Service";
          if (dateText.isNotEmpty) fullDesc += ", $dateText";
          if (desc.isNotEmpty) fullDesc += "\n$desc";

          _invoiceItems.add({
            'desc': fullDesc,
            'qty': days,
            'price': price,
            'total': (price * days) - discount
          });
        }

        // 2. Transport
        for (var doc in transportSnap.docs) {
          final t = doc.data();
          final date = (t['date'] as Timestamp?)?.toDate();
          final dateStr =
              date != null ? DateFormat('dd MMM yyyy').format(date) : "";
          final title = t['route_title'] ?? 'Transport';

          String details = "Driver & Car";
          if (t['vehicle'] != null) details += " ${t['vehicle']}";
          details += ", $dateStr,\n$title";

          _invoiceItems.add({
            'desc': details,
            'qty': 1,
            'price': (t['fee'] as num?)?.toDouble() ?? 0.0,
            'total': (t['fee'] as num?)?.toDouble() ?? 0.0,
          });
        }

        // 3. Tickets
        for (var doc in ticketSnap.docs) {
          final t = doc.data();
          final date = (t['date'] as Timestamp?)?.toDate();
          final dateStr =
              date != null ? DateFormat('dd MMM yyyy').format(date) : "";
          final spotName = t['spot_name'] ?? 'Ticket';

          final qtys = t['quantities'] as Map<String, dynamic>? ?? {};
          final prices = t['unit_prices'] as Map<String, dynamic>? ?? {};

          qtys.forEach((type, qty) {
            if ((qty as num) > 0) {
              final unitPrice = (prices[type] as num?)?.toDouble() ?? 0.0;

              String desc = "Ticket $type, $spotName, $dateStr";

              _invoiceItems.add({
                'desc': desc,
                'qty': qty,
                'price': unitPrice,
                'total': qty * unitPrice,
              });
            }
          });
        }

        // 4. Additional Fees
        for (var doc in feesSnap.docs) {
          final f = doc.data();
          String desc = f['description'] ?? "Fee";
          if (f['note'] != null && f['note'].toString().isNotEmpty)
            desc += "\n${f['note']}";

          _invoiceItems.add({
            'desc': desc,
            'qty': 1,
            'price': (f['amount'] as num?)?.toDouble() ?? 0.0,
            'total': (f['amount'] as num?)?.toDouble() ?? 0.0,
          });
        }

        _savedProfiles = profilesSnap.docs
            .map((e) => InvoiceProfile.fromMap(e.id, e.data()))
            .toList();
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC ---

  void _applyProfile(InvoiceProfile profile) {
    setState(() {
      _selectedProfile = profile;
      _senderNameCtrl.text = profile.senderName;
      _senderEmailCtrl.text = profile.senderEmail;
      _senderPhoneCtrl.text = profile.senderPhone;
      _bankInfoCtrl.text = profile.paymentInfo;
    });
  }

  Future<void> _saveNewProfile() async {
    if (_profileNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter a Profile Name")));
      return;
    }
    final newProfile = InvoiceProfile(
      id: '',
      profileName: _profileNameCtrl.text,
      senderName: _senderNameCtrl.text,
      senderEmail: _senderEmailCtrl.text,
      senderPhone: _senderPhoneCtrl.text,
      paymentInfo: _bankInfoCtrl.text,
    );
    await FirebaseFirestore.instance
        .collection('utilities')
        .add(newProfile.toMap());
    _profileNameCtrl.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Profile Saved")));
    _fetchData();
  }

  // --- PDF GENERATION (OPTIMIZED) ---

  Future<Uint8List> _generatePdf() async {
    // If resources aren't ready, return empty to avoid crash
    if (!_resourcesLoaded || _fontRegular == null) {
      return Uint8List(0);
    }

    try {
      final pdf = pw.Document();
      final format = NumberFormat.currency(
          locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

      double subtotal = 0;
      for (var item in _invoiceItems) {
        subtotal += item['total'];
      }

      pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: _fontRegular, bold: _fontBold),
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return [
              // 1. TOP BLUE BAR
              pw.Container(
                  height: 10,
                  color: _journeytaleBlue,
                  margin:
                      const pw.EdgeInsets.only(top: 40, left: 40, right: 40)),

              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                child: pw.Column(children: [
                  pw.SizedBox(height: 20),

                  // 2. LOGO & HEADER
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              // Safe Image Rendering using Cached Images
                              if (_logoImage1 != null)
                                pw.Image(_logoImage1!, width: 180)
                              else
                                pw.Text("journeytale Travels",
                                    style: pw.TextStyle(
                                        fontSize: 24,
                                        fontWeight: pw.FontWeight.bold,
                                        color: _journeytaleBlue)),

                              pw.SizedBox(height: 10),
                              pw.Text(_labels['client_label']!,
                                  style: const pw.TextStyle(fontSize: 12)),
                              pw.SizedBox(height: 5),
                              pw.Row(children: [
                                pw.SizedBox(
                                    width: 100,
                                    child: pw.Text(_labels['name']!,
                                        style: const pw.TextStyle(
                                            color: PdfColors.grey700,
                                            fontSize: 11))),
                                pw.Text(_clientNameCtrl.text,
                                    style: const pw.TextStyle(
                                        color: PdfColors.black, fontSize: 11)),
                              ]),
                              pw.SizedBox(height: 3),
                              pw.Row(children: [
                                pw.SizedBox(
                                    width: 100,
                                    child: pw.Text(_labels['phone']!,
                                        style: const pw.TextStyle(
                                            color: PdfColors.grey700,
                                            fontSize: 11))),
                                pw.Text(_clientPhoneCtrl.text,
                                    style: const pw.TextStyle(
                                        color: PdfColors.black, fontSize: 11)),
                              ]),
                            ]),
                        pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              if (_logoImage2 != null)
                                pw.Image(_logoImage2!, width: 80),
                              pw.SizedBox(height: 10),
                              pw.Row(children: [
                                pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.end,
                                    children: [
                                      pw.Text(_labels['invoice_no']!,
                                          style:
                                              const pw.TextStyle(fontSize: 12)),
                                      pw.Text(_labels['date']!,
                                          style:
                                              const pw.TextStyle(fontSize: 12)),
                                    ]),
                                pw.SizedBox(
                                  width: 20,
                                ),
                                pw.Column(children: [
                                  pw.Text(_invoiceNoCtrl.text,
                                      style: const pw.TextStyle(fontSize: 12)),
                                  pw.Text(_invoiceDateCtrl.text,
                                      style: const pw.TextStyle(fontSize: 12)),
                                ])
                              ]),
                            ])
                      ]),
                  pw.SizedBox(height: 30),

                  // 3. TABLE HEADER
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 5),
                    child: pw.Row(children: [
                      pw.SizedBox(
                          width: 30,
                          child: pw.Text(_labels['col_no']!,
                              style: pw.TextStyle(
                                  color: _tableHeaderBlue,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 11))),
                      pw.Expanded(
                          flex: 5,
                          child: pw.Text(_labels['col_desc']!,
                              style: pw.TextStyle(
                                  color: _tableHeaderBlue,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 11))),
                      pw.Expanded(
                          flex: 1,
                          child: pw.Text(_labels['col_qty']!,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                  color: _journeytaleOrange,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 11))),
                      pw.Expanded(
                          flex: 2,
                          child: pw.Text(_labels['col_price']!,
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                  color: _tableHeaderBlue,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 11))),
                      pw.Expanded(
                          flex: 2,
                          child: pw.Text(_labels['col_total']!,
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                  color: _journeytaleOrange,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 11))),
                    ]),
                  ),
                  pw.Divider(color: PdfColors.grey300, thickness: 0.5),

                  // 4. TABLE ROWS
                  ..._invoiceItems.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final item = entry.value;

                    return pw.Container(
                        color: _itemRowBg, // Grey Container per row
                        margin: const pw.EdgeInsets.only(bottom: 2),
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        child: pw.Row(children: [
                          pw.SizedBox(
                              width: 30,
                              child: pw.Text("$idx",
                                  style: const pw.TextStyle(fontSize: 10))),
                          pw.Expanded(
                              flex: 5,
                              child: pw.Text(item['desc'],
                                  style: const pw.TextStyle(fontSize: 10))),
                          pw.Expanded(
                              flex: 1,
                              child: pw.Text("${item['qty']}",
                                  textAlign: pw.TextAlign.center,
                                  style: const pw.TextStyle(fontSize: 10))),
                          pw.Expanded(
                              flex: 2,
                              child: pw.Text(format.format(item['price']),
                                  textAlign: pw.TextAlign.right,
                                  style: const pw.TextStyle(fontSize: 10))),
                          pw.Expanded(
                              flex: 2,
                              child: pw.Text(format.format(item['total']),
                                  textAlign: pw.TextAlign.right,
                                  style: const pw.TextStyle(fontSize: 10))),
                        ]));
                  }),

                  // 5. SPACER
                  pw.Container(height: 40, color: PdfColors.white),

                  // 6. SUBTOTAL
                  pw.Container(
                      padding: const pw.EdgeInsets.only(top: 10, bottom: 20),
                      alignment: pw.Alignment.centerRight,
                      child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Text(_labels['subtotal']!,
                                style: pw.TextStyle(
                                    color: _journeytaleBlue, fontSize: 12)),
                            pw.SizedBox(width: 20),
                            pw.Text(format.format(subtotal),
                                style: pw.TextStyle(
                                    color: _journeytaleOrange,
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold)),
                          ])),

                  // 7. PAYMENT & TOTAL FOOTER
                  pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        // Payment Info
                        pw.Expanded(
                            child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                              pw.Text(_labels['payment_info']!,
                                  style: const pw.TextStyle(fontSize: 10)),
                              pw.SizedBox(height: 2),
                              pw.Text(_bankInfoCtrl.text,
                                  style: pw.TextStyle(
                                      fontSize: 11,
                                      fontWeight: pw.FontWeight.bold)),
                            ])),

                        // Orange Total Box
                        pw.Container(
                            height: 35,
                            width: 250,
                            child: pw.Row(children: [
                              pw.Container(
                                  width: 80,
                                  height: double.infinity,
                                  color: _journeytaleOrange,
                                  alignment: pw.Alignment.center,
                                  child: pw.Text(_labels['total_label']!,
                                      style: pw.TextStyle(
                                          color: PdfColors.white,
                                          fontWeight: pw.FontWeight.bold))),
                              pw.Expanded(
                                  child: pw.Container(
                                      height: double.infinity,
                                      color: _journeytaleBlue,
                                      alignment: pw.Alignment.centerRight,
                                      padding:
                                          const pw.EdgeInsets.only(right: 15),
                                      child: pw.Text(format.format(subtotal),
                                          style: pw.TextStyle(
                                              color: PdfColors.white,
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 14))))
                            ]))
                      ]),

                  pw.SizedBox(height: 20),

                  // 8. NOTES SECTION (RED)
                  if (_orderNotes.isNotEmpty)
                    pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border:
                              pw.Border.all(color: PdfColors.red, width: 0.5),
                          color: PdfColor.fromInt(0xFFFFF5F5),
                        ),
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(_labels['notes_label']!,
                                  style: pw.TextStyle(
                                      color: PdfColors.red,
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10)),
                              pw.SizedBox(height: 4),
                              pw.Text(_orderNotes,
                                  style: const pw.TextStyle(
                                      color: PdfColors.red, fontSize: 10)),
                            ])),
                ]),
              ),

              pw.Spacer(),

              // 9. BOTTOM FOOTER BAR
              pw.Container(
                  height: 30,
                  width: double.infinity,
                  color: _journeytaleBlue,
                  alignment: pw.Alignment.centerLeft,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                  child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      color: _journeytaleOrange,
                      child: pw.Text(_labels['footer_text']!,
                          style: const pw.TextStyle(
                              color: PdfColors.black, fontSize: 8))))
            ];
          }));

      return pdf.save();
    } catch (e) {
      debugPrint("PDF Generation Failed: $e");
      return Uint8List(0);
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
          title: const Text("Generate Invoice"),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black),
      body: Row(
        children: [
          Container(
            width: 380,
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("PDF Language",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      ToggleButtons(
                        borderRadius: BorderRadius.circular(8),
                        isSelected: [!_isChinese, _isChinese],
                        onPressed: (index) =>
                            setState(() => _isChinese = index == 1),
                        constraints:
                            const BoxConstraints(minHeight: 32, minWidth: 60),
                        children: const [Text("EN"), Text("中文")],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ExpansionTile(
                      title: const Text("Sender Profiles",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      children: [
                        DropdownButtonFormField<InvoiceProfile>(
                          isExpanded: true,
                          value: _selectedProfile,
                          items: _savedProfiles
                              .map((p) => DropdownMenuItem(
                                  value: p, child: Text(p.profileName)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) _applyProfile(val);
                          },
                        ),
                        TextButton(
                            onPressed: _saveNewProfile,
                            child: const Text("Save Profile")),
                      ]),
                  const Divider(),
                  _input(_senderNameCtrl, "Company Name"),
                  _input(_senderEmailCtrl, "Email"),
                  _input(_senderPhoneCtrl, "Phone"),
                  _input(_bankInfoCtrl, "Payment Details", maxLines: 4),
                  const Divider(),
                  _input(_clientNameCtrl, "Client Name"),
                  _input(_clientPhoneCtrl, "Client Phone"),
                  _input(_invoiceNoCtrl, "Invoice #"),

                  const SizedBox(height: 20),
                  // Note Editor in case they want to change it just for this invoice
                  const Text("Invoice Note:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  TextField(
                    controller: TextEditingController(text: _orderNotes),
                    onChanged: (val) => _orderNotes = val,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Notes appear in red at bottom"),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final bytes = await _generatePdf();
                          if (bytes.isNotEmpty) {
                            await Printing.layoutPdf(
                                onLayout: (_) async => bytes);
                          }
                        },
                        icon: const Icon(Icons.print),
                        label: const Text("Print / Preview"),
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                      )),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final bytes = await _generatePdf();
                        if (bytes.isNotEmpty) {
                          await Printing.sharePdf(
                              bytes: bytes,
                              filename: 'Invoice_${_invoiceNoCtrl.text}.pdf');
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text("Download PDF"),
                    ),
                  )
                ],
              ),
            ),
          ),
          Expanded(
            child: !_resourcesLoaded
                ? const Center(child: CircularProgressIndicator())
                : PdfPreview(
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
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true),
      ),
    );
  }
}