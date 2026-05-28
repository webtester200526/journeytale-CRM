import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/service_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// IMPORT YOUR ACTUAL MODEL HERE
 

// --- MODELS ---

class VoucherProfile {
  final String id;
  final String profileName; 
  final String supplierName;
  final String supplierAddress;
  final String supplierContact;

  VoucherProfile({
    required this.id,
    required this.profileName,
    required this.supplierName,
    required this.supplierAddress,
    required this.supplierContact,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': 'voucher_profile',
      'profileName': profileName,
      'supplierName': supplierName,
      'supplierAddress': supplierAddress,
      'supplierContact': supplierContact,
    };
  }

  factory VoucherProfile.fromMap(String id, Map<String, dynamic> map) {
    return VoucherProfile(
      id: id,
      profileName: map['profileName'] ?? 'Unnamed',
      supplierName: map['supplierName'] ?? '',
      supplierAddress: map['supplierAddress'] ?? '',
      supplierContact: map['supplierContact'] ?? '',
    );
  }
}

// --- MAIN WIDGET ---

class ServiceVoucherEditorPage extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> serviceData; 
  final OrderModel orderModel; 

  const ServiceVoucherEditorPage({
    super.key,
    required this.orderId,
    required this.serviceData,
    required this.orderModel,
  });

  @override
  State<ServiceVoucherEditorPage> createState() => _ServiceVoucherEditorPageState();
}

class _ServiceVoucherEditorPageState extends State<ServiceVoucherEditorPage> {
  bool _isLoading = true;
  bool _isInternalMode = false; 
  
  // --- NEW: Language State ---
  bool _isChinese = false;

  // Data Containers
  List<VoucherProfile> _savedProfiles = [];
  VoucherProfile? _selectedProfile;

  // Form Controllers
  final _supplierNameCtrl = TextEditingController();
  final _supplierAddressCtrl = TextEditingController();
  final _supplierContactCtrl = TextEditingController();
  
  final _bookingRefCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController(); 

  // Dates
  DateTime? _startDate;
  DateTime? _endDate;

  // PDF Design Colors
  static const PdfColor _journeytaleBlue = PdfColor.fromInt(0xFF00A0E9);
  static const PdfColor _journeytaleOrange = PdfColor.fromInt(0xFFF5A623);
  static const PdfColor _tableHeaderBlue = PdfColor.fromInt(0xFF00A0E9);
  static const PdfColor _lightGreyBg = PdfColor.fromInt(0xFFF2F2F2);

  // --- TRANSLATION MAP ---
  Map<String, String> get _labels => _isChinese ? {
    'title_internal': '内部单据',
    'title_po': '采购订单',
    'to_provider': '致供应商:',
    'booking_ref': '预订编号:',
    'client_group': '客户组:',
    'date': '日期:',
    'col_no': '序号',
    'col_desc': '服务描述 / 日期',
    'col_qty': '天数/数量',
    'col_rate': '协议价',
    'col_cost': '成本价',
    'col_total': '总计',
    'internal_analysis': '内部利润分析',
    'client_price': '客户总价:',
    'supplier_cost': '供应商成本:',
    'net_profit': '净利润:',
    'footer_internal': '仅供内部使用 - 请勿发送给供应商',
    'footer_po': '请在24小时内确认此服务订单。',
  } : {
    'title_internal': 'INTERNAL VOUCHER',
    'title_po': 'PURCHASE ORDER',
    'to_provider': 'To Provider:',
    'booking_ref': 'Booking Ref:',
    'client_group': 'Client Group:',
    'date': 'Date:',
    'col_no': 'No.',
    'col_desc': 'Service Description / Dates',
    'col_qty': 'Days/Qty',
    'col_rate': 'Agreed Rate',
    'col_cost': 'Rate / Cost',
    'col_total': 'Total',
    'internal_analysis': 'INTERNAL PROFIT ANALYSIS',
    'client_price': 'Client Price (Total):',
    'supplier_cost': 'Supplier Cost (Total):',
    'net_profit': 'NET PROFIT:',
    'footer_internal': 'INTERNAL USE ONLY - DO NOT SEND TO SUPPLIER',
    'footer_po': 'Please confirm this service order within 24 hours.',
  };

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      // 1. Load Profiles
      final profilesSnap = await FirebaseFirestore.instance
          .collection('utilities')
          .where('type', isEqualTo: 'voucher_profile')
          .get();
      
      _savedProfiles = profilesSnap.docs.map((e) => VoucherProfile.fromMap(e.id, e.data())).toList();

      // 2. Pre-fill Form
      _supplierNameCtrl.text = widget.serviceData['supplier_name'] ?? ""; 
      _instructionsCtrl.text = widget.serviceData['description'] ?? "";
      
      String serviceNameShort = (widget.serviceData['name'] ?? "SVC").toString().substring(0, 3).toUpperCase();
      String randomDigits = DateTime.now().millisecondsSinceEpoch.toString().substring(9);
      _bookingRefCtrl.text = "$serviceNameShort-$randomDigits";

      if (widget.serviceData['start_date'] != null) {
        _startDate = (widget.serviceData['start_date'] as Timestamp).toDate();
      } else {
        _startDate = widget.orderModel.startDate;
      }

      int days = (widget.serviceData['days'] as num?)?.toInt() ?? 1;
      
      if (widget.serviceData['end_date'] != null) {
        _endDate = (widget.serviceData['end_date'] as Timestamp).toDate();
      } else {
         _endDate = _startDate?.add(Duration(days: days > 0 ? days - 1 : 0));
      }

    } catch (e) {
      debugPrint("Error init: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC ---

  void _applyProfile(VoucherProfile profile) {
    setState(() {
      _selectedProfile = profile;
      _supplierNameCtrl.text = profile.supplierName;
      _supplierAddressCtrl.text = profile.supplierAddress;
      _supplierContactCtrl.text = profile.supplierContact;
    });
  }

  Future<void> _saveNewProfile() async {
    final nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Save Supplier Profile"),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: "Profile Name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel",style: TextStyle(color: Colors.red))),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performSaveProfile(nameCtrl.text);
            }, 
            child: const Text("Save")
          )
        ],
      )
    );
  }

  Future<void> _performSaveProfile(String name) async {
    if (name.isEmpty) return;
    final newProfile = VoucherProfile(
      id: '',
      profileName: name,
      supplierName: _supplierNameCtrl.text,
      supplierAddress: _supplierAddressCtrl.text,
      supplierContact: _supplierContactCtrl.text,
    );
    await FirebaseFirestore.instance.collection('utilities').add(newProfile.toMap());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Supplier Profile Saved")));
    _initData(); 
  }

  // --- PDF GENERATION ---

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    
    // Support Chinese fonts
    final fontRegular = await PdfGoogleFonts.notoSansSCRegular();
    final fontBold = await PdfGoogleFonts.notoSansSCBold();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final currency = NumberFormat.simpleCurrency(decimalDigits: 0, name: '¥', locale: 'zh_CN');

    // Financials
    final int days = (widget.serviceData['days'] as num?)?.toInt() ?? 1;
    final double costPerDay = (widget.serviceData['modal_per_day'] as num?)?.toDouble() ?? 0.0;
    final double pricePerDay = (widget.serviceData['price_per_day'] as num?)?.toDouble() ?? 0.0;
    final double discount = (widget.serviceData['discount'] as num?)?.toDouble() ?? 0.0;

    final double totalCost = costPerDay * days;
    final double clientTotal = (pricePerDay * days) - discount;
    final double profit = clientTotal - totalCost;

    final String docTitle = _isInternalMode ? _labels['title_internal']! : _labels['title_po']!;
    
    // Dates String
    String dateRange = "";
    if (_startDate != null && _endDate != null) {
      dateRange = "${dateFormat.format(_startDate!)} to ${dateFormat.format(_endDate!)}";
    }

    // Merge Details
    String details = widget.serviceData['name'] ?? "Service";
    if (_instructionsCtrl.text.isNotEmpty) {
      details += "\n\nDetails / Instructions:\n${_instructionsCtrl.text}";
    }

    pdf.addPage(pw.MultiPage(
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
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("journeytale", style: pw.TextStyle(color: _journeytaleBlue, fontSize: 32, fontWeight: pw.FontWeight.bold)),
                pw.Text("Explore city like a local", style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
              ]),
              pw.Container(
                height: 40, width: 40, 
                decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.grey200),
                child: pw.Center(child: pw.Text("PO", style: const pw.TextStyle(fontSize: 10)))
              )
            ]
          ),
          pw.SizedBox(height: 30),

          // 3. INFO BLOCK
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // LEFT: SUPPLIER
              pw.Expanded(
                flex: 3,
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: docTitle, style: pw.TextStyle(color: _journeytaleOrange, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  ])),
                  pw.SizedBox(height: 10),
                  pw.Text(_labels['to_provider']!, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(_supplierNameCtrl.text, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  if(_supplierContactCtrl.text.isNotEmpty) pw.Text(_supplierContactCtrl.text),
                  if(_supplierAddressCtrl.text.isNotEmpty) pw.Text(_supplierAddressCtrl.text, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ])
              ),
              // RIGHT: ORDER META
              pw.Expanded(
                flex: 2,
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.SizedBox(height: 30),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text(_labels['booking_ref']!, style: const pw.TextStyle(color: PdfColors.grey700)),
                    pw.Text(_bookingRefCtrl.text, style:  pw.TextStyle(color: PdfColors.black, fontWeight: pw.FontWeight.bold)),
                  ]),
                  pw.SizedBox(height: 5),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text(_labels['client_group']!, style: const pw.TextStyle(color: PdfColors.grey700)),
                    pw.Text(widget.orderModel.name, style: const pw.TextStyle(color: PdfColors.black)),
                  ]),
                  pw.SizedBox(height: 5),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text(_labels['date']!, style: const pw.TextStyle(color: PdfColors.grey700)),
                    pw.Text(dateFormat.format(DateTime.now()), style: const pw.TextStyle(color: PdfColors.black)),
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
            pw.Expanded(flex: 6, child: pw.Text(_labels['col_desc']!, style: pw.TextStyle(color: _tableHeaderBlue, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 2, child: pw.Text(_labels['col_qty']!, textAlign: pw.TextAlign.center, style: pw.TextStyle(color: _tableHeaderBlue, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 3, child: pw.Text(_isInternalMode ? _labels['col_cost']! : _labels['col_rate']!, textAlign: pw.TextAlign.right, style: pw.TextStyle(color: _tableHeaderBlue, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 3, child: pw.Text(_labels['col_total']!, textAlign: pw.TextAlign.right, style: pw.TextStyle(color: _journeytaleOrange, fontWeight: pw.FontWeight.bold))),
          ]),
          pw.SizedBox(height: 5),

          // 5. TABLE ROW (Main Service)
          pw.Container(
            color: _lightGreyBg,
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            margin: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(flex: 1, child: pw.Text("1", style: const pw.TextStyle(color: PdfColors.grey600))),
                pw.Expanded(flex: 6, child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(details, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(dateRange, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ]
                )),
                pw.Expanded(flex: 2, child: pw.Text("$days", textAlign: pw.TextAlign.center)),
                pw.Expanded(flex: 3, child: pw.Text(currency.format(costPerDay), textAlign: pw.TextAlign.right)),
                pw.Expanded(flex: 3, child: pw.Text(currency.format(totalCost), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              ]
            )
          ),

          // 6. INTERNAL ONLY DATA (Additional Rows if Internal Mode)
          if (_isInternalMode) ...[
             pw.SizedBox(height: 20),
             pw.Container(
               padding: const pw.EdgeInsets.all(10),
               decoration: pw.BoxDecoration(color: PdfColors.red50, borderRadius: pw.BorderRadius.circular(4)),
               child: pw.Column(
                 crossAxisAlignment: pw.CrossAxisAlignment.start,
                 children: [
                   pw.Text(_labels['internal_analysis']!, style: pw.TextStyle(color: PdfColors.red800, fontWeight: pw.FontWeight.bold)),
                   pw.SizedBox(height: 5),
                   pw.Row(children: [
                     pw.Expanded(child: pw.Text(_labels['client_price']!)),
                     pw.Text(currency.format(clientTotal)),
                   ]),
                   pw.Row(children: [
                     pw.Expanded(child: pw.Text(_labels['supplier_cost']!)),
                     pw.Text("- ${currency.format(totalCost)}"),
                   ]),
                   pw.Divider(),
                   pw.Row(children: [
                     pw.Expanded(child: pw.Text(_labels['net_profit']!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                     pw.Text(currency.format(profit), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: profit >= 0 ? PdfColors.green700 : PdfColors.red700)),
                   ]),
                 ]
               )
             )
          ],

          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.Text(_isInternalMode 
            ? _labels['footer_internal']!
            : _labels['footer_po']!,
            style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10)
          ),
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
        title: const Text("Generate Service Voucher"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Row(
        children: [
          // LEFT PANEL: CONTROLS
          Container(
            width: 380,
            color: Colors.white,
            padding: const EdgeInsets.all(20),
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

                  // MODE TOGGLE
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isInternalMode ? Colors.red[50] : Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _isInternalMode ? Colors.red.shade200 : Colors.amber.shade200)
                    ),
                    child: Row(
                      children: [
                        Icon(_isInternalMode ? Icons.admin_panel_settings : Icons.description, color: _isInternalMode ? Colors.red : Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_isInternalMode ? "Internal Analysis" : "Supplier Voucher", style: const TextStyle(fontWeight: FontWeight.bold))),
                        Switch(
                          value: _isInternalMode,
                          activeColor: Colors.red,
                          onChanged: (val) => setState(() => _isInternalMode = val),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // PROFILE MANAGER
                  ExpansionTile(
                    title: const Text("Supplier Profiles", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      DropdownButtonFormField<VoucherProfile>(
                        isExpanded: true,
                        decoration: _inputDecoration("Load Profile"),
                        value: _selectedProfile,
                        items: _savedProfiles.map((p) => DropdownMenuItem(value: p, child: Text(p.profileName))).toList(),
                        onChanged: (val) { if (val != null) _applyProfile(val); },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _saveNewProfile,
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text("Save Supplier Info as New Profile"),
                      )
                    ],
                  ),
                  const Divider(),

                  // SUPPLIER INFO
                  const Text("Vendor Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _input(_supplierNameCtrl, "Company / Supplier Name"),
                  _input(_supplierContactCtrl, "Contact Person"),
                  _input(_supplierAddressCtrl, "Address / Location"),
                  
                  const SizedBox(height: 20),
                  const Text("Service Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _input(_bookingRefCtrl, "Booking Ref No."),
                  
                  // DATE RANGE PICKER (Mini)
                  InkWell(
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context, 
                        firstDate: DateTime(2020), 
                        lastDate: DateTime(2030),
                        initialDateRange: (_startDate != null && _endDate != null) 
                            ? DateTimeRange(start: _startDate!, end: _endDate!) 
                            : null
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked.start;
                          _endDate = picked.end;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_startDate != null ? "${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}" : "Select Dates"),
                          const Icon(Icons.calendar_today, size: 16),
                        ],
                      ),
                    ),
                  ),

                  _input(_instructionsCtrl, "Instructions / Notes", maxLines: 4),

                  const SizedBox(height: 20),
                  
                  // ACTIONS
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
                        String prefix = _isInternalMode ? "Internal" : "PO";
                        await Printing.sharePdf(bytes: bytes, filename: '${prefix}_${widget.serviceData['name']}.pdf');
                      },
                      icon: const Icon(Icons.download),
                      label: const Text("Download PDF"),
                    ),
                  )
                ],
              ),
            ),
          ),

          // RIGHT PANEL: PREVIEW
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
        style: const TextStyle(fontSize: 13),
        decoration: _inputDecoration(label).copyWith(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }
}