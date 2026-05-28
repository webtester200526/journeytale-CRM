import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

// --- MODELS ---

class ItineraryProfile {
  final String id;
  final String profileName;
  final String companyName;
  final String companyAddress;
  final String companyEmail;
  final String contactPerson;

  ItineraryProfile({
    required this.id,
    required this.profileName,
    required this.companyName,
    required this.companyAddress,
    required this.companyEmail,
    required this.contactPerson,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': 'itinerary_profile',
      'profileName': profileName,
      'companyName': companyName,
      'companyAddress': companyAddress,
      'companyEmail': companyEmail,
      'contactPerson': contactPerson,
    };
  }

  factory ItineraryProfile.fromMap(String id, Map<String, dynamic> map) {
    return ItineraryProfile(
      id: id,
      profileName: map['profileName'] ?? 'Unnamed',
      companyName: map['companyName'] ?? '',
      companyAddress: map['companyAddress'] ?? '',
      companyEmail: map['companyEmail'] ?? '',
      contactPerson: map['contactPerson'] ?? '',
    );
  }
}

// --- MAIN WIDGET ---

class ItineraryPdfEditorPage extends StatefulWidget {
  final Map<String, dynamic> itineraryData; // 'generatedItinerary' map
  final String clientName;

  const ItineraryPdfEditorPage({
    super.key,
    required this.itineraryData,
    required this.clientName,
  });

  @override
  State<ItineraryPdfEditorPage> createState() => _ItineraryPdfEditorPageState();
}

class _ItineraryPdfEditorPageState extends State<ItineraryPdfEditorPage> {
  bool _isLoading = true;
  
  // --- NEW: Language State ---
  bool _isChinese = false;

  // Data Containers
  List<ItineraryProfile> _savedProfiles = [];
  ItineraryProfile? _selectedProfile;

  // Form Controllers
  late TextEditingController _tripTitleCtrl;
  final _companyNameCtrl = TextEditingController(text: "journeytale Travels");
  final _companyAddressCtrl = TextEditingController(text: "123 Sunshine Blvd, Suite 404\nSingapore, 000000");
  final _companyEmailCtrl = TextEditingController(text: "bookings@journeytale.com");
  final _contactPersonCtrl = TextEditingController(text: "Victor Ong (Senior Agent)");

  // Design Colors (journeytale Standard)
  static const PdfColor _journeytaleBlue = PdfColor.fromInt(0xFF00A0E9);
  static const PdfColor _journeytaleOrange = PdfColor.fromInt(0xFFF5A623);
  static const PdfColor _lightGreyBg = PdfColor.fromInt(0xFFF8F9FA); // Lighter background
  static const PdfColor _textGrey = PdfColor.fromInt(0xFF555555);

  

  // --- TRANSLATION MAP ---
  Map<String, String> get _labels => _isChinese ? {
    'subtitle': '您的东方之旅',
    'itinerary_title': '行程单',
    'client': '客户:',
    'day_prefix': '第', // Used as "第 1 天"
    'day_suffix': '天',
    'free_easy': '自由活动',
    'thank_you': '感谢您选择',
    'wish': '祝您旅途愉快！',
  } : {
    'subtitle': 'Explore city like a local',
    'itinerary_title': 'TRAVEL ITINERARY',
    'client': 'Client:',
    'day_prefix': 'Day',
    'day_suffix': '',
    'free_easy': 'Free & Easy',
    'thank_you': 'Thank you for choosing',
    'wish': 'We wish you a safe journey!',
  };

  @override
  void initState() {
    super.initState();
    _tripTitleCtrl = TextEditingController(text: widget.itineraryData['trip_title'] ?? 'Luxury Vacation');
    _initData();
  }

  Future<void> _initData() async {
    try {
      final profilesSnap = await FirebaseFirestore.instance
          .collection('utilities')
          .where('type', isEqualTo: 'itinerary_profile')
          .get();
      
      _savedProfiles = profilesSnap.docs.map((e) => ItineraryProfile.fromMap(e.id, e.data())).toList();

    } catch (e) {
      debugPrint("Error init: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC ---

  void _applyProfile(ItineraryProfile profile) {
    setState(() {
      _selectedProfile = profile;
      _companyNameCtrl.text = profile.companyName;
      _companyAddressCtrl.text = profile.companyAddress;
      _companyEmailCtrl.text = profile.companyEmail;
      _contactPersonCtrl.text = profile.contactPerson;
    });
  }

  Future<void> _saveNewProfile() async {
    final nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Save Company Profile"),
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
    final newProfile = ItineraryProfile(
      id: '',
      profileName: name,
      companyName: _companyNameCtrl.text,
      companyAddress: _companyAddressCtrl.text,
      companyEmail: _companyEmailCtrl.text,
      contactPerson: _contactPersonCtrl.text,
    );
    await FirebaseFirestore.instance.collection('utilities').add(newProfile.toMap());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Saved")));
    _initData(); 
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    
    // Merge edited title
    final Map<String, dynamic> mergedData = Map.from(widget.itineraryData);
    mergedData['trip_title'] = _tripTitleCtrl.text;
    final List<dynamic> days = mergedData['days'] ?? [];

    final ByteData data = await rootBundle.load('assets/Explore city like a local.png');
    final Uint8List bytes = data.buffer.asUint8List();

    // 2. Create the PDF Image provider
    final logoImage = pw.MemoryImage(bytes);

    // Noto Sans SC (Simplified Chinese) supports both English and Chinese
    final fontRegular = await PdfGoogleFonts.notoSansSCRegular();
    final fontBold = await PdfGoogleFonts.notoSansSCBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30), 
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return [
            // 1. TOP BAR
            pw.Container(height: 4, color: _journeytaleBlue),
            pw.SizedBox(height: 10),

            // 2. HEADER
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(logoImage, width: 150, height: 150),
                // CONTACT INFO (Smaller Text)
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(_companyNameCtrl.text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_companyEmailCtrl.text, style: const pw.TextStyle(fontSize: 7, color: _textGrey)),
                  pw.Text(_contactPersonCtrl.text, style: const pw.TextStyle(fontSize: 7, color: _textGrey)),
                  pw.Text(_companyAddressCtrl.text.replaceAll("\n", ", "), style: const pw.TextStyle(fontSize: 7, color: _textGrey)),
                ])
              ]
            ),
            pw.SizedBox(height: 15),

            // 3. TRIP TITLE BLOCK
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.white, 
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: _journeytaleBlue, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(_labels['itinerary_title']!, style: pw.TextStyle(fontSize: 7, letterSpacing: 1.2, color: _journeytaleOrange, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text(_tripTitleCtrl.text, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _journeytaleBlue)),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(color: _journeytaleOrange, borderRadius: pw.BorderRadius.circular(12)),
                    child: pw.Text("${_labels['client']} ${widget.clientName}", style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // 4. TIMELINE BODY
            ...days.expand((day) => _buildDayWidgets(day)).toList(),
            
            // 5. FOOTER
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300, thickness: 0.5),
            pw.Center(
              child: pw.Text(
                "${_labels['thank_you']} ${_companyNameCtrl.text}. ${_labels['wish']}",
                style: const pw.TextStyle(color: _textGrey, fontSize: 7),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // --- PDF WIDGETS ---

  List<pw.Widget> _buildDayWidgets(dynamic day) {
    final activities = (day['activities'] as List);
    
    // Format Day Header (e.g. "Day 1" vs "第 1 天")
    String dayHeader = _isChinese 
        ? "${_labels['day_prefix']} ${day['day_number']} ${_labels['day_suffix']}"
        : "${_labels['day_prefix']} ${day['day_number']}";

    List<pw.Widget> widgets = [];

    // 1. Day Header
    widgets.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8, top: 12),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const pw.BoxDecoration(
                color: _journeytaleBlue,
                borderRadius: pw.BorderRadius.only(topLeft: pw.Radius.circular(4), bottomRight: pw.Radius.circular(4)),
              ),
              child: pw.Text(
                dayHeader,
                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              "|  ${day['theme']}",
              style: pw.TextStyle(color: _journeytaleBlue, fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ]
        )
      )
    );

    // 2. Activities (Flattened)
    if (activities.isEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 15, bottom: 10),
          child: pw.Text(_labels['free_easy']!, style:  pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic))
        )
      );
    } else {
      widgets.addAll(activities.map((act) => _buildActivityRow(act)));
    }

    return widgets;
  }

  pw.Widget _buildActivityRow(dynamic act) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Time Column
          pw.SizedBox(
            width: 45,
            child: pw.Text(
              act['time'],
              style: pw.TextStyle(
                color: _journeytaleOrange,
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
            ),
          ),

          // Vertical Line
          pw.Container(
            width: 1.5,
            margin: const pw.EdgeInsets.only(right: 10),
            color: _journeytaleOrange,
          ),

          // Content
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: _lightGreyBg,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "${act['location']} - ${act['spot']}",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                      color: _journeytaleBlue,
                    ),
                  ),
                  if (act['description'] != null &&
                      act['description'].toString().isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      act['description'],
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.black,
                        lineSpacing: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Generate Itinerary PDF"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Row(
        children: [
          // LEFT: CONTROLS
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

                  // Profiles
                  ExpansionTile(
                    title: const Text("Company Profiles", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      DropdownButtonFormField<ItineraryProfile>(
                        isExpanded: true,
                        decoration: _inputDecoration("Load Profile"),
                        value: _selectedProfile,
                        items: _savedProfiles.map((p) => DropdownMenuItem(value: p, child: Text(p.profileName))).toList(),
                        onChanged: (val) { if (val != null) _applyProfile(val); },
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: _saveNewProfile,
                          icon: const Icon(Icons.save_alt, size: 16),
                          label: const Text("Save as New Profile"),
                        )),
                      ])
                    ],
                  ),
                  const Divider(),

                  const Text("Header Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _input(_companyNameCtrl, "Company Name"),
                  _input(_contactPersonCtrl, "Contact Person"),
                  _input(_companyEmailCtrl, "Email"),
                  _input(_companyAddressCtrl, "Address", maxLines: 2),
                  
                  const SizedBox(height: 20),
                  const Text("Trip Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _input(_tripTitleCtrl, "Trip Title"),
                  
                  const SizedBox(height: 30),
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
                        await Printing.sharePdf(bytes: bytes, filename: 'Itinerary_${widget.clientName}.pdf');
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }
}

class InfoBox extends StatelessWidget {
  final String text;
  const InfoBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.blue.shade800))),
        ],
      ),
    );
  }
}