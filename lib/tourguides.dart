import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class TourGuideProfilesPage extends StatefulWidget {
  const TourGuideProfilesPage({super.key});

  @override
  State<TourGuideProfilesPage> createState() => _TourGuideProfilesPageState();
}

class _TourGuideProfilesPageState extends State<TourGuideProfilesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFFF3F5F7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Tour Guide Profiles", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            color: bgColor,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
              decoration: InputDecoration(
                hintText: "Search guides by name...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                  : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
            ),
          ),

          // --- GRID CONTENT ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('tourguides').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final allDocs = snapshot.data!.docs;
                
                // FILTER LOGIC
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  if (_searchQuery.isNotEmpty) {
                    return Center(child: Text("No guides found matching '$_searchQuery'", style: const TextStyle(color: Colors.grey)));
                  }
                  return const Center(
                    child: Text("No saved profiles.\nAdd a guide to get started.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    childAspectRatio: 2.4, // Short/Wide Card
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    return _GuideGridCard(
                      data: data,
                      docId: doc.id,
                      onEdit: () => _showProfileForm(context, doc),
                      onDelete: () => _deleteProfile(context, doc.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Profile", style: TextStyle(color: Colors.white)),
        onPressed: () => _showProfileForm(context, null),
      ),
    );
  }

  void _showProfileForm(BuildContext context, DocumentSnapshot? doc) {
  showDialog(
    context: context,
    barrierDismissible: false, // Prevents closing while uploading
    builder: (ctx) => TourGuideEditorDialog(existingDoc: doc),
  );
}

  Future<void> _deleteProfile(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Profile?"),
        content: const Text("This will remove the guide from the master list. Existing orders will not be affected."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('tourguides').doc(docId).delete();
    }
  }
}

// --- CARD WIDGET (Compact Layout) ---

class _GuideGridCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GuideGridCard({
    required this.data,
    required this.docId,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(name: 'RMB', decimalDigits: 0);
    final String initial = data['name'] != null && data['name'].isNotEmpty ? data['name'][0].toUpperCase() : "?";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.indigo.shade50,
                  child: Text(
                    initial,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.indigo.shade700),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['name'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1C20)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: onDelete,
                            child: Icon(Icons.close, size: 18, color: Colors.grey.shade300),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (data['area'] != null && data['area'].isNotEmpty)
                            _MiniBadge(text: data['area'], icon: Icons.location_on, color: Colors.blueGrey),
                          if (data['area'] != null && data['area'].isNotEmpty)
                            const SizedBox(width: 6),
                          if (data['age'] != null && data['age'] > 0)
                            _MiniBadge(text: "${data['age']} Y.O", color: Colors.amber),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${currency.format(data['default_fee'] ?? 0)} / day",
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black87),
                          ),
                          InkWell(
                            onTap: onEdit,
                            child: const Icon(Icons.edit, size: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;

  const _MiniBadge({required this.text, this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 10, color: color), const SizedBox(width: 3)],
          Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}


// ==========================================
// TOUR GUIDE EDITOR DIALOG
// ==========================================

class TourGuideEditorDialog extends StatefulWidget {
  final DocumentSnapshot? existingDoc;

  const TourGuideEditorDialog({super.key, this.existingDoc});

  @override
  State<TourGuideEditorDialog> createState() => _TourGuideEditorDialogState();
}

class _TourGuideEditorDialogState extends State<TourGuideEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _feeCtrl;
  late TextEditingController _passportCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _dobCtrl; // Display controller for the date

  // State Variables
  DateTime? _dob;
  XFile? _imageFile;
  Uint8List? _webImageBytes;
  String _existingImageUrl = '';
  bool _isSaving = false;
  bool _isHoveringImage = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize with existing data or defaults
    final data = widget.existingDoc?.data() as Map<String, dynamic>?;

    _nameCtrl = TextEditingController(text: data?['name'] ?? '');
    _areaCtrl = TextEditingController(text: data?['area'] ?? '');
    _feeCtrl = TextEditingController(text: data?['default_fee']?.toString() ?? '');
    _passportCtrl = TextEditingController(text: data?['passport'] ?? '');
    _notesCtrl = TextEditingController(text: data?['notes'] ?? '');
    _existingImageUrl = data?['passport_image_url'] ?? '';

    // Handle Date of Birth
    if (data?['dob'] != null) {
      _dob = (data!['dob'] as Timestamp).toDate();
      _dobCtrl = TextEditingController(text: DateFormat('dd MMM yyyy').format(_dob!));
    } else {
      _dobCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _areaCtrl.dispose();
    _feeCtrl.dispose();
    _passportCtrl.dispose();
    _notesCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  // --- LOGIC: Image Picking ---
  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageFile = image;
        _webImageBytes = bytes;
      });
    }
  }

  // --- LOGIC: Date Picker ---
  Future<void> _selectDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.black, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobCtrl.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  // --- LOGIC: Calculate Age ---
  int _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return 0;
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  // --- LOGIC: Save ---
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // 1. Determine ID
      final String docId = widget.existingDoc?.id ?? FirebaseFirestore.instance.collection('tourguides').doc().id;

      // 2. Upload Image if changed
      String imageUrl = _existingImageUrl;
      if (_webImageBytes != null) {
        final ref = FirebaseStorage.instance.ref().child('tourguides/$docId/passport.jpg');
        await ref.putData(_webImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
        imageUrl = await ref.getDownloadURL();
      }

      // 3. Prepare Data
      final data = {
        'name': _nameCtrl.text,
        'area': _areaCtrl.text,
        'default_fee': double.tryParse(_feeCtrl.text) ?? 0,
        'passport': _passportCtrl.text,
        'notes': _notesCtrl.text,
        'dob': _dob != null ? Timestamp.fromDate(_dob!) : null,
        'age': _calculateAge(_dob), // Calculated automatically
        'passport_image_url': imageUrl,
        'updated_at': FieldValue.serverTimestamp(),
      };

      // 4. Save to Firestore
      await FirebaseFirestore.instance.collection('tourguides').doc(docId).set(data, SetOptions(merge: true));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- UI CONSTRUCTION ---
  @override
  Widget build(BuildContext context) {
    final hasImage = _webImageBytes != null || _existingImageUrl.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      elevation: 5,
      child: Container(
        width: 850, // Wide Professional Width
        constraints: const BoxConstraints(maxHeight: 900),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existingDoc == null ? "New Tour Guide" : "Edit Profile",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Manage guide details, documents, and standard rates.",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), splashRadius: 20),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

            // BODY
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT: IMAGE
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Passport / ID Card", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 12),
                            MouseRegion(
                              onEnter: (_) => setState(() => _isHoveringImage = true),
                              onExit: (_) => setState(() => _isHoveringImage = false),
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: AspectRatio(
                                  aspectRatio: 3 / 2, // 3:2 Ratio
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: hasImage ? Border.all(color: Colors.grey.shade300) : Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                                        ),
                                        child: hasImage
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: _webImageBytes != null
                                                    ? Image.memory(_webImageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                                                    : Image.network(_existingImageUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                              )
                                            : Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey.shade400),
                                                    const SizedBox(height: 8),
                                                    Text("Upload Document", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                                                  ],
                                                ),
                                              ),
                                      ),
                                      if (hasImage && _isHoveringImage)
                                        Container(
                                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
                                          child: const Center(child: Icon(Icons.edit, color: Colors.white)),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),

                      // RIGHT: FORM
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Full Name"),
                            TextFormField(controller: _nameCtrl, validator: (v) => v!.isEmpty ? "Required" : null, decoration: _inputDec(hint: "e.g. Wang Wei", icon: Icons.person_outline)),
                            const SizedBox(height: 16),
                            
                            Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  _buildLabel("Passport Number"),
                                  TextFormField(controller: _passportCtrl, decoration: _inputDec(hint: "G12345678", icon: Icons.badge_outlined)),
                                ]),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  _buildLabel("Date of Birth"),
                                  TextFormField(
                                    controller: _dobCtrl, 
                                    readOnly: true, 
                                    onTap: _selectDOB,
                                    decoration: _inputDec(hint: "Select Date", icon: Icons.cake_outlined).copyWith(
                                      suffixText: _dob != null ? "${_calculateAge(_dob)} yrs" : null,
                                      suffixStyle: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)
                                    ),
                                  ),
                                ]),
                              ),
                            ]),

                            const SizedBox(height: 16),

                            Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  _buildLabel("Service Area"),
                                  TextFormField(controller: _areaCtrl, decoration: _inputDec(hint: "e.g. Beijing", icon: Icons.map_outlined)),
                                ]),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  _buildLabel("Daily Rate (RMB)"),
                                  TextFormField(controller: _feeCtrl, keyboardType: TextInputType.number, decoration: _inputDec(hint: "0.00", icon: Icons.attach_money)),
                                ]),
                              ),
                            ]),

                            const SizedBox(height: 16),
                            _buildLabel("Performance Notes"),
                            TextFormField(controller: _notesCtrl, maxLines: 3, decoration: _inputDec(hint: "Internal notes about language skills, personality...", icon: Icons.notes)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

            // FOOTER
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                   
                    child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Save Profile", style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333))));

  InputDecoration _inputDec({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, size: 20, color: Colors.grey.shade400) : null,
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent)),
    );
  }
}