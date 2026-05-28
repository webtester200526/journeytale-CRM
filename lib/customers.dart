import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:dotted_border/dotted_border.dart';

// ==========================================
// 1. MODELS
// ==========================================

class GroupModel {
  final String id;
  final String name;
  final String notes;

  GroupModel({required this.id, required this.name, this.notes = ''});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory GroupModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: doc.id,
      name: data['name'] ?? '',
      notes: data['notes'] ?? '',
    );
  }
}

class CustomerModel {
  final String id;
  final String name;
  final String passportNumber;
  final String passportImageUrl;
  final DateTime? dob;
  final String preferences; 
  final String notes;
  final List<String> groupIds;
  
  // New Fields
  final List<String> phoneNumbers;
  final List<String> emails;
  final List<String> addresses;

  CustomerModel({
    required this.id,
    required this.name,
    this.passportNumber = '',
    this.passportImageUrl = '',
    this.dob,
    this.preferences = '',
    this.notes = '',
    this.groupIds = const [], 
    this.phoneNumbers = const [],
    this.emails = const [],
    this.addresses = const [],
  });

  int get age {
    if (dob == null) return 0;
    final today = DateTime.now();
    int age = today.year - dob!.year;
    if (today.month < dob!.month || (today.month == dob!.month && today.day < dob!.day)) {
      age--;
    }
    return age;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.toLowerCase(),
      'display_name': name,
      'passport_number': passportNumber,
      'passport_image_url': passportImageUrl,
      'dob': dob != null ? Timestamp.fromDate(dob!) : null,
      'preferences': preferences,
      'notes': notes,
      'group_ids': groupIds,
      'phone_numbers': phoneNumbers,
      'emails': emails,
      'addresses': addresses,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory CustomerModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Migration logic for old single-group data
    List<String> gIds = [];
    if (data['group_ids'] != null) {
      gIds = List<String>.from(data['group_ids']);
    } else if (data['group_id'] != null && data['group_id'] != "") {
      gIds = [data['group_id']];
    }

    return CustomerModel(
      id: doc.id,
      name: data['display_name'] ?? data['name'] ?? '',
      passportNumber: data['passport_number'] ?? '',
      passportImageUrl: data['passport_image_url'] ?? '',
      dob: (data['dob'] as Timestamp?)?.toDate(),
      preferences: data['preferences'] ?? '',
      notes: data['notes'] ?? '',
      groupIds: gIds,
      phoneNumbers: List<String>.from(data['phone_numbers'] ?? []),
      emails: List<String>.from(data['emails'] ?? []),
      addresses: List<String>.from(data['addresses'] ?? []),
    );
  }
}

// ==========================================
// 2. DIALOGS
// ==========================================

// --- Group Creation ---
class GroupCreatorDialog extends StatefulWidget {
  final Future<void> Function(GroupModel) onSave;
  const GroupCreatorDialog({super.key, required this.onSave});

  @override
  State<GroupCreatorDialog> createState() => _GroupCreatorDialogState();
}

class _GroupCreatorDialogState extends State<GroupCreatorDialog> {
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Create New Group"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Group Name", border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: "Description / Notes", border: OutlineInputBorder())),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: _isSaving ? null : () async {
            if(_nameCtrl.text.isEmpty) return;
            setState(() => _isSaving = true);
            await widget.onSave(GroupModel(id: '', name: _nameCtrl.text, notes: _notesCtrl.text));
            if(mounted) Navigator.pop(context);
          },
          child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Create Group"),
        )
      ],
    );
  }
}

// --- Group Manager ---
class GroupManagerDialog extends StatelessWidget {
  final GroupModel group;
  const GroupManagerDialog({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('customers').orderBy('display_name').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const AlertDialog(content: SizedBox(height:100, child: Center(child: CircularProgressIndicator())));

        final allCustomers = snapshot.data!.docs.map((d) => CustomerModel.fromSnapshot(d)).toList();
        
        final members = allCustomers.where((c) => c.groupIds.contains(group.id)).toList();
        final potentialMembers = allCustomers.where((c) => !c.groupIds.contains(group.id)).toList();

        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Manage Group", style: TextStyle(fontSize: 14, color: Colors.grey)),
              Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Current Members:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: members.isEmpty 
                  ? const Center(child: Text("No members in this group.", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        return ListTile(
                          leading: CircleAvatar(backgroundImage: member.passportImageUrl.isNotEmpty ? NetworkImage(member.passportImageUrl) : null, child: member.passportImageUrl.isEmpty ? Text(member.name[0]) : null),
                          title: Text(member.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            tooltip: "Remove from group",
                            onPressed: () {
                              FirebaseFirestore.instance.collection('customers').doc(member.id).update({
                                'group_ids': FieldValue.arrayRemove([group.id])
                              });
                            },
                          ),
                        );
                      },
                    ),
                ),
                const Divider(),
                ElevatedButton.icon(
                  onPressed: () {
                    _showAddMemberSheet(context, potentialMembers, group.id);
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text("Add Member from Database"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          ],
        );
      },
    );
  }

  void _showAddMemberSheet(BuildContext context, List<CustomerModel> availablePeople, String groupId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text("Select Person to Add", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Expanded(
                child: availablePeople.isEmpty 
                  ? const Center(child: Text("All customers are already in this group.")) 
                  : ListView.builder(
                    itemCount: availablePeople.length,
                    itemBuilder: (context, index) {
                      final p = availablePeople[index];
                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(p.name),
                        subtitle: Text(p.passportNumber),
                        onTap: () {
                          FirebaseFirestore.instance.collection('customers').doc(p.id).update({
                            'group_ids': FieldValue.arrayUnion([groupId])
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
              )
            ],
          ),
        );
      },
    );
  }
}


// ==========================================
// CUSTOMER EDITOR DIALOG (PROFESSIONAL UI)
// ==========================================

class CustomerEditorDialog extends StatefulWidget {
  final CustomerModel? existingCustomer;
  final Future<void> Function(CustomerModel, XFile?) onSave;
  final Future<void> Function(String)? onDelete;

  const CustomerEditorDialog({
    super.key,
    this.existingCustomer,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<CustomerEditorDialog> createState() => _CustomerEditorDialogState();
}

class _CustomerEditorDialogState extends State<CustomerEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _passportCtrl;
  late TextEditingController _prefCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _dobCtrl;
  
  // Dynamic Lists Controllers
  List<TextEditingController> _phoneCtrls = [];
  List<TextEditingController> _emailCtrls = [];
  List<TextEditingController> _addrCtrls = [];

  DateTime? _dob;
  XFile? _imageFile;
  Uint8List? _webImageBytes;
  bool _isSaving = false;
  bool _isHoveringImage = false; 

  @override
  void initState() {
    super.initState();
    final c = widget.existingCustomer;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _passportCtrl = TextEditingController(text: c?.passportNumber ?? '');
    _prefCtrl = TextEditingController(text: c?.preferences ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
    
    _dob = c?.dob;
    _dobCtrl = TextEditingController(
      text: _dob != null ? DateFormat('dd MMM yyyy').format(_dob!) : '',
    );

    // Initialize Dynamic lists. If empty, start with one empty field
    _phoneCtrls = c?.phoneNumbers.map((p) => TextEditingController(text: p)).toList() ?? [TextEditingController()];
    if (_phoneCtrls.isEmpty) _phoneCtrls.add(TextEditingController());

    _emailCtrls = c?.emails.map((e) => TextEditingController(text: e)).toList() ?? [TextEditingController()];
    if (_emailCtrls.isEmpty) _emailCtrls.add(TextEditingController());

    _addrCtrls = c?.addresses.map((a) => TextEditingController(text: a)).toList() ?? [TextEditingController()];
    if (_addrCtrls.isEmpty) _addrCtrls.add(TextEditingController());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passportCtrl.dispose();
    _prefCtrl.dispose();
    _notesCtrl.dispose();
    _dobCtrl.dispose();
    for (var c in _phoneCtrls) { c.dispose(); }
    for (var c in _emailCtrls) { c.dispose(); }
    for (var c in _addrCtrls) { c.dispose(); }
    super.dispose();
  }

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

  Future<void> _selectDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black, 
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    // Extract values from dynamic lists and filter out empty strings
    List<String> phones = _phoneCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    List<String> emails = _emailCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    List<String> addrs = _addrCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

    final customer = CustomerModel(
      id: widget.existingCustomer?.id ?? '',
      name: _nameCtrl.text,
      passportNumber: _passportCtrl.text,
      dob: _dob,
      preferences: _prefCtrl.text,
      notes: _notesCtrl.text,
      passportImageUrl: widget.existingCustomer?.passportImageUrl ?? '',
      groupIds: widget.existingCustomer?.groupIds ?? [],
      phoneNumbers: phones,
      emails: emails,
      addresses: addrs,
    );

    try {
      await widget.onSave(customer, _imageFile);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDelete() async {
    if (widget.existingCustomer == null || widget.onDelete == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Customer?"),
        content: Text("Are you sure you want to delete ${widget.existingCustomer!.name}? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      await widget.onDelete!(widget.existingCustomer!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting: $e")));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _webImageBytes != null || (widget.existingCustomer?.passportImageUrl.isNotEmpty ?? false);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      elevation: 5,
      child: Container(
        width: 800, 
        constraints: const BoxConstraints(maxHeight: 900),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existingCustomer == null ? "Add New Customer" : "Edit Customer Profile",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Enter details and preferences below.",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    splashRadius: 20,
                  )
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

            // --- BODY ---
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT COLUMN: PASSPORT IMAGE
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Passport / ID", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 12),
                            
                            MouseRegion(
                              onEnter: (_) => setState(() => _isHoveringImage = true),
                              onExit: (_) => setState(() => _isHoveringImage = false),
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: AspectRatio(
                                  aspectRatio: 3 / 2, 
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: hasImage 
                                              ? Border.all(color: Colors.grey.shade300) 
                                              : null,
                                        ),
                                        child: hasImage 
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: _webImageBytes != null
                                                  ? Image.memory(_webImageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                                                  : Image.network(widget.existingCustomer!.passportImageUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                            )
                                          : DottedBorder(
                                              child: const Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.add_photo_alternate_outlined, size: 32, color: Colors.grey),
                                                    SizedBox(height: 8),
                                                    Text("Upload Document", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      ),
                                      
                                      if (hasImage && _isHoveringImage)
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.4),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.edit, color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Supported formats: JPG, PNG. \nEnsure text is legible.",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 32),

                      // RIGHT COLUMN: FORM FIELDS
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Full Name"),
                            TextFormField(
                              controller: _nameCtrl,
                              validator: (v) => v!.isEmpty ? "Name is required" : null,
                              decoration: _inputDec(hint: "e.g. John Doe", icon: Icons.person_outline),
                            ),
                            const SizedBox(height: 20),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel("Passport Number"),
                                      TextFormField(
                                        controller: _passportCtrl,
                                        decoration: _inputDec(hint: "A12345678", icon: Icons.badge_outlined),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel("Date of Birth"),
                                      TextFormField(
                                        controller: _dobCtrl,
                                        readOnly: true,
                                        onTap: _selectDOB,
                                        decoration: _inputDec(hint: "Select Date", icon: Icons.calendar_today_outlined),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // --- DYNAMIC SECTIONS ---
                            _buildDynamicList(
                              title: "Phone Numbers", 
                              controllers: _phoneCtrls, 
                              icon: Icons.phone_outlined, 
                              hint: "+1 234 567 890"
                            ),
                            const SizedBox(height: 12),
                            
                            _buildDynamicList(
                              title: "Email Addresses", 
                              controllers: _emailCtrls, 
                              icon: Icons.email_outlined, 
                              hint: "email@example.com"
                            ),
                            const SizedBox(height: 12),
                            
                            _buildDynamicList(
                              title: "Addresses", 
                              controllers: _addrCtrls, 
                              icon: Icons.location_on_outlined, 
                              hint: "Street address, City, Country"
                            ),

                            const SizedBox(height: 20),

                            _buildLabel("Preferences"),
                            TextFormField(
                              controller: _prefCtrl,
                              decoration: _inputDec(hint: "e.g. Vegetarian, Window Seat", icon: Icons.star_outline),
                            ),
                            const SizedBox(height: 20),

                            _buildLabel("Internal Notes"),
                            TextFormField(
                              controller: _notesCtrl,
                              maxLines: 3,
                              decoration: _inputDec(hint: "Add private notes about this customer...", icon: Icons.notes),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

            // --- FOOTER ---
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // DELETE BUTTON (Left Side)
                  if (widget.existingCustomer != null)
                    TextButton.icon(
                      onPressed: _isSaving ? null : _handleDelete,
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      label: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  
                  const Spacer(),
                  
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // Brand color
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text("Save Customer", style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DYNAMIC LIST BUILDER ---
  Widget _buildDynamicList({
    required String title,
    required List<TextEditingController> controllers,
    required IconData icon,
    required String hint
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(title),
        ...controllers.asMap().entries.map((entry) {
          int index = entry.key;
          var ctrl = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: ctrl,
                    decoration: _inputDec(hint: hint, icon: icon),
                  ),
                ),
                if (controllers.length > 1) 
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                    onPressed: () => setState(() => controllers.removeAt(index)),
                  )
                else 
                  const SizedBox(width: 48), // Placeholder to keep alignment
              ],
            ),
          );
        }).toList(),
        TextButton.icon(
          onPressed: () => setState(() => controllers.add(TextEditingController())),
          icon: const Icon(Icons.add, size: 16),
          label: Text("Add another ${title.toLowerCase().substring(0, title.length-1)}"), // rough plural to singular
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            alignment: Alignment.centerLeft
          ),
        ),
      ],
    );
  }

  // Helper for consistent label styling
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
    );
  }

  // Helper for professional input styling
  InputDecoration _inputDec({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, size: 20, color: Colors.grey.shade400) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

// ==========================================
// 3. MAIN PAGE
// ==========================================
class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String _searchQuery = "";
  bool _expandGroups = true;
  bool _expandUngrouped = true;
  bool _expandAll = true; // New state for "All Individuals"

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Customer Database"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _showCreateGroup,
            icon: const Icon(Icons.group_add),
            label: const Text("New Group"),
          )
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search customers...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          
          // Main Content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('groups').snapshots(),
              builder: (context, groupSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('customers').orderBy('updatedAt', descending: true).snapshots(),
                  builder: (context, customerSnap) {
                    
                    if (!customerSnap.hasData || !groupSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // 1. Process Data
                    final allGroups = groupSnap.data!.docs.map((d) => GroupModel.fromSnapshot(d)).toList();
                    final allCustomers = customerSnap.data!.docs.map((d) => CustomerModel.fromSnapshot(d)).where((c) {
                      return c.name.toLowerCase().contains(_searchQuery) || c.passportNumber.toLowerCase().contains(_searchQuery);
                    }).toList();

                    final ungroupedCustomers = allCustomers.where((c) => c.groupIds.isEmpty).toList();
                    
                    // 2. Custom Scroll View
                    return CustomScrollView(
                      slivers: [
                        
                        // --- SECTION 1: GROUPS ---
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverToBoxAdapter(
                            child: _buildSectionHeader(
                              "Groups", 
                              allGroups.length, 
                              _expandGroups, 
                              () => setState(() => _expandGroups = !_expandGroups)
                            ),
                          ),
                        ),

                        if (_expandGroups)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final group = allGroups[index];
                                  final members = allCustomers.where((c) => c.groupIds.contains(group.id)).toList();
                                  return _buildGroupCard(group, members);
                                },
                                childCount: allGroups.length,
                              ),
                            ),
                          ),

                        // --- SECTION 2: UNGROUPED (Useful for organization) ---
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          sliver: SliverToBoxAdapter(
                            child: _buildSectionHeader(
                              "Ungrouped Individuals", 
                              ungroupedCustomers.length, 
                              _expandUngrouped, 
                              () => setState(() => _expandUngrouped = !_expandUngrouped)
                            ),
                          ),
                        ),

                        if (_expandUngrouped)
                          SliverPadding(
                            padding: const EdgeInsets.all(5),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 400,
                                childAspectRatio: 3,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildCustomerCard(ungroupedCustomers[index]),
                                childCount: ungroupedCustomers.length,
                              ),
                            ),
                          ),

                        // --- SECTION 3: ALL INDIVIDUALS (The Master List) ---
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          sliver: SliverToBoxAdapter(
                            child: _buildSectionHeader(
                              "All Individuals", 
                              allCustomers.length, 
                              _expandAll, 
                              () => setState(() => _expandAll = !_expandAll)
                            ),
                          ),
                        ),

                        if (_expandAll)
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 400,
                                childAspectRatio: 3,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildCustomerCard(allCustomers[index]),
                                childCount: allCustomers.length,
                              ),
                            ),
                          ),
                          
                        // Extra space at bottom
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCustomerEditor(null),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSectionHeader(String title, int count, bool isExpanded, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
        child: Row(
          children: [
            Icon(isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, color: Colors.grey),
            const SizedBox(width: 8),
            Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
              child: Text("$count", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(GroupModel group, List<CustomerModel> members) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.folder_shared_outlined, color: Colors.blue.shade700),
        ),
        title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${members.length} Members • ${group.notes}", maxLines: 1, overflow: TextOverflow.ellipsis),
        
        // Changed Trailing to Row to support Menu AND Expand Arrow
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             PopupMenuButton<String>(
               icon: const Icon(Icons.more_horiz, color: Colors.grey),
               tooltip: "Options",
               onSelected: (val) {
                 if (val == 'manage') {
                   _showGroupManager(group);
                 } else if (val == 'delete') {
                   _confirmDeleteGroup(group);
                 }
               },
               itemBuilder: (ctx) => [
                 const PopupMenuItem(
                   value: 'manage',
                   child: Row(children: [Icon(Icons.settings_outlined, size: 20), SizedBox(width: 8), Text("Manage Members")]),
                 ),
                 const PopupMenuItem(
                   value: 'delete',
                   child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 20), SizedBox(width: 8), Text("Delete Group", style: TextStyle(color: Colors.red))]),
                 ),
               ],
             ),
             const SizedBox(width: 8),
             const Icon(Icons.expand_more, color: Colors.grey), 
          ],
        ),

        childrenPadding: const EdgeInsets.all(16),
        children: [
          if(members.isEmpty) 
            const Padding(padding: EdgeInsets.all(8.0), child: Text("No members in this group", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: members.map((member) => SizedBox(
              width: 350,
              height: 100,
              child: _buildCustomerCard(member, isCompact: true),
            )).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildCustomerCard(CustomerModel customer, {bool isCompact = false}) {
    final String initial = customer.name.isNotEmpty ? customer.name[0].toUpperCase() : "?";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isCompact ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showCustomerEditor(customer),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Hero(
                  tag: customer.id,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue.shade50,
                    backgroundImage: customer.passportImageUrl.isNotEmpty ? NetworkImage(customer.passportImageUrl) : null,
                    child: customer.passportImageUrl.isEmpty ? Text(initial, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(customer.passportNumber.isNotEmpty ? customer.passportNumber : "No Passport", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                const Icon(Icons.edit, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- ACTIONS ---

  void _showCreateGroup() {
    showDialog(
      context: context,
      builder: (_) => GroupCreatorDialog(onSave: (group) async {
        await FirebaseFirestore.instance.collection('groups').add(group.toMap());
      }),
    );
  }

  void _showGroupManager(GroupModel group) {
    showDialog(
      context: context,
      builder: (_) => GroupManagerDialog(group: group),
    );
  }

  // New logic for deleting Groups
  void _confirmDeleteGroup(GroupModel group) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Group?"),
        content: Text("Are you sure you want to delete '${group.name}'? Members of this group will not be deleted, they will just be ungrouped."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('groups').doc(group.id).delete();
      // Optionally: Trigger a cloud function to remove group.id from all customers' groupIds list
      // For now, the UI simply filters them out.
    }
  }

  void _showCustomerEditor(CustomerModel? customer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomerEditorDialog(
        existingCustomer: customer,
        onSave: (model, file) async {
          String docId = model.id;
          
          if (docId.isEmpty) {
            final ref = await FirebaseFirestore.instance.collection('customers').add(model.toMap());
            docId = ref.id;
          } else {
            await FirebaseFirestore.instance.collection('customers').doc(docId).update(model.toMap());
          }

          if (file != null) {
            final ref = FirebaseStorage.instance.ref().child('customers/$docId/passport.jpg');
            await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
            final url = await ref.getDownloadURL();
            await FirebaseFirestore.instance.collection('customers').doc(docId).update({'passport_image_url': url});
          }
        },
        // Pass the Delete Logic
        onDelete: (docId) async {
          // 1. Try Delete Storage Image (if exists)
          try {
             await FirebaseStorage.instance.ref().child('customers/$docId/passport.jpg').delete();
          } catch(e) {
            // Ignore if file doesn't exist
          }
          // 2. Delete Firestore Doc
          await FirebaseFirestore.instance.collection('customers').doc(docId).delete();
        },
      ),
    );
  }
}