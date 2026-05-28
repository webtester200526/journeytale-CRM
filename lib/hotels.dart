import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

// --- SHARED CONSTANTS ---
const Map<String, String> kCurrencies = {
  'IDR': 'Rp ',
  'RMB': '¥',
  'USD': '\$',
  'EUR': '€',
  'SGD': 'S\$',
  'MYR': 'RM',
  'JPY': '¥',
  'CHF': 'CHF ',
  'KRW': '₩',
  'TWD': 'NT\$',
  'HKD': 'HK\$',
  'MOP': 'MOP\$',
  'AUD': 'A\$',
  'GBP': '£',
};


class HotelDatabasePage extends StatelessWidget {
  const HotelDatabasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Hotel Inventory", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('hotels_db').orderBy('city').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return _buildEmptyState();

          Map<String, List<DocumentSnapshot>> groupedHotels = {};
          Set<String> uniqueCities = {}; 

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            String city = data['city'] ?? 'Uncategorized';
            uniqueCities.add(city);
            
            if (!groupedHotels.containsKey(city)) {
              groupedHotels[city] = [];
            }
            groupedHotels[city]!.add(doc);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: groupedHotels.keys.length,
            itemBuilder: (context, index) {
              String city = groupedHotels.keys.elementAt(index);
              List<DocumentSnapshot> cityHotels = groupedHotels[city]!;
              
              return _CityGroupSection(
                city: city, 
                hotels: cityHotels,
                existingCities: uniqueCities.toList(),
              );
            },
          );
        },
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showHotelEditor(context, null, []),
      label: const Text("New Hotel", style: TextStyle(fontWeight: FontWeight.w600)),
      icon: const Icon(Icons.add),
      backgroundColor: Colors.blue,
      elevation: 4,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.domain_disabled_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("No hotels found", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }

  void _showHotelEditor(BuildContext context, DocumentSnapshot? doc, List<String> cities) async {
    List<String> suggestions = cities;
    if (suggestions.isEmpty) {
      final snap = await FirebaseFirestore.instance.collection('hotels_db').get();
      suggestions = snap.docs.map((d) => d['city'] as String).toSet().toList();
    }
    
    if (context.mounted) {
      showDialog(context: context, builder: (_) => _HotelMasterEditor(doc: doc, existingCities: suggestions));
    }
  }
}

// -----------------------------------------------------------------------------
// UI COMPONENTS
// -----------------------------------------------------------------------------

class _CityGroupSection extends StatelessWidget {
  final String city;
  final List<DocumentSnapshot> hotels;
  final List<String> existingCities;

  const _CityGroupSection({required this.city, required this.hotels, required this.existingCities});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: Text(
            city.toUpperCase(), 
            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 14, color: Colors.black87)
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.location_city, color: Colors.white, size: 18),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            child: Text("${hotels.length} Hotels", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          ),
          children: [
            ...hotels.map((h) => _HotelCard(doc: h, existingCities: existingCities)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _HotelCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final List<String> existingCities;
  const _HotelCard({required this.doc, required this.existingCities});

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Hotel?"),
        content: const Text("This will remove the hotel and its room inventory from the database."),
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
      await doc.reference.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final imageUrl = data['image_url'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(12),
        shape: const Border(),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 60, height: 60,
            color: Colors.grey[100],
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? Image.network(imageUrl, fit: BoxFit.cover)
                : const Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
          ),
        ),
        title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.map, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Expanded(child: Text(data['address'] ?? '-', style: TextStyle(fontSize: 13, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[400]),
          onSelected: (value) {
            if (value == 'edit') {
               showDialog(context: context, builder: (_) => _HotelMasterEditor(doc: doc, existingCities: existingCities));
            } else if (value == 'delete') {
              _confirmDelete(context);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 10), Text("Edit Info")]),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 10), Text("Delete Hotel", style: TextStyle(color: Colors.red))]),
            ),
          ],
        ),
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: _RoomManager(hotelId: doc.id),
          )
        ],
      ),
    );
  }
}

class _RoomManager extends StatelessWidget {
  final String hotelId;
  const _RoomManager({required this.hotelId});

  Future<void> _confirmDeleteRoom(BuildContext context, DocumentReference ref) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Room?"),
        content: const Text("Are you sure you want to delete this room type?"),
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
      await ref.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('hotels_db').doc(hotelId).collection('rooms').orderBy('price').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator(minHeight: 2);
        final rooms = snapshot.data!.docs;

        return Column(
          children: [
            if (rooms.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("No room types added.", style: TextStyle(fontSize: 12, color: Colors.grey[400], fontStyle: FontStyle.italic)),
              ),
            ...rooms.map((r) {
              final d = r.data() as Map<String, dynamic>;
              double price = (d['price'] ?? 0).toDouble();
              double markup = (d['markup'] ?? 0).toDouble();
              double clientPrice = price * (1 + markup/100);
              
              String currencyCode = d['currency'] ?? 'RMB';
              String symbol = kCurrencies[currencyCode] ?? currencyCode;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                    image: (d['image_url'] != null && d['image_url'].isNotEmpty)
                        ? DecorationImage(image: NetworkImage(d['image_url']), fit: BoxFit.cover)
                        : null
                  ),
                  child: (d['image_url'] == null || d['image_url'].isEmpty) ? const Icon(Icons.bed, size: 16, color: Colors.grey) : null,
                ),
                title: Text(d['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text("Markup: ${markup.toStringAsFixed(0)}%", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Cost: $symbol${price.toStringAsFixed(0)}", style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                        Text("Client: $symbol${clientPrice.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // Replaced single IconButton with PopupMenuButton
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, size: 18),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showRoomEditor(context, hotelId, r);
                        } else if (value == 'delete') {
                          _confirmDeleteRoom(context, r.reference);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text("Edit")])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 1),
            TextButton.icon(
              onPressed: () => _showRoomEditor(context, hotelId, null),
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text("Add Room Type"),
              style: TextButton.styleFrom(padding: const EdgeInsets.all(16), foregroundColor: Colors.black87),
            )
          ],
        );
      },
    );
  }

  void _showRoomEditor(BuildContext context, String hotelId, DocumentSnapshot? doc) {
    showDialog(context: context, builder: (_) => _RoomEditor(hotelId: hotelId, doc: doc));
  }
}

// -----------------------------------------------------------------------------
// MODERN EDITORS (DIALOGS)
// -----------------------------------------------------------------------------

class _HotelMasterEditor extends StatefulWidget {
  final DocumentSnapshot? doc;
  final List<String> existingCities;
  const _HotelMasterEditor({this.doc, required this.existingCities});
  @override
  State<_HotelMasterEditor> createState() => _HotelMasterEditorState();
}

class _HotelMasterEditorState extends State<_HotelMasterEditor> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  XFile? _imageFile;
  String? _existingImageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!.data() as Map<String, dynamic>;
      _nameCtrl.text = d['name'];
      _addressCtrl.text = d['address'] ?? '';
      _descCtrl.text = d['description'] ?? '';
      _cityCtrl.text = d['city'] ?? '';
      _existingImageUrl = d['image_url'];
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) setState(() => _imageFile = img);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _cityCtrl.text.isEmpty) return;
    setState(() => _isUploading = true);
    
    String imgUrl = _existingImageUrl ?? '';
    if (_imageFile != null) {
      final ref = FirebaseStorage.instance.ref().child('hotels/${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (kIsWeb) {
        await ref.putData(await _imageFile!.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(_imageFile!.path));
      }
      imgUrl = await ref.getDownloadURL();
    }

    final data = {
      'name': _nameCtrl.text,
      'address': _addressCtrl.text,
      'city': _cityCtrl.text,
      'description': _descCtrl.text,
      'image_url': imgUrl,
    };

    if (widget.doc != null) {
      await widget.doc!.reference.update(data);
    } else {
      await FirebaseFirestore.instance.collection('hotels_db').add(data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.doc == null ? "Add Hotel" : "Edit Hotel", style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ImagePickerBox(
                imageFile: _imageFile, 
                existingUrl: _existingImageUrl, 
                onTap: _pickImage,
                label: "Upload Hotel Photo",
              ),
              const SizedBox(height: 20),
              
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _cityCtrl.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') return const Iterable<String>.empty();
                  return widget.existingCities.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  _cityCtrl.text = selection;
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  if(_cityCtrl.text.isNotEmpty && textEditingController.text.isEmpty) {
                     textEditingController.text = _cityCtrl.text;
                  }
                  textEditingController.addListener(() {
                    _cityCtrl.text = textEditingController.text;
                  });

                  return _ModernInput(
                    controller: textEditingController, 
                    label: "City", 
                    hint: "e.g. Shanghai, Beijing...",
                    focusNode: focusNode,
                  );
                },
              ),
              
              const SizedBox(height: 12),
              _ModernInput(controller: _nameCtrl, label: "Hotel Name"),
              const SizedBox(height: 12),
              _ModernInput(controller: _addressCtrl, label: "Address"),
              const SizedBox(height: 12),
              _ModernInput(controller: _descCtrl, label: "Description", maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [
        if (_isUploading) const Center(child: CircularProgressIndicator())
        else ...[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: _save, 
            child: const Text("Save"),
          )
        ]
      ],
    );
  }
}

class _RoomEditor extends StatefulWidget {
  final String hotelId;
  final DocumentSnapshot? doc;
  const _RoomEditor({required this.hotelId, this.doc});
  @override
  State<_RoomEditor> createState() => _RoomEditorState();
}

class _RoomEditorState extends State<_RoomEditor> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _markupCtrl = TextEditingController(text: "15");
  String _selectedCurrency = 'RMB'; // Default currency
  
  XFile? _imageFile;
  String? _existingImageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!.data() as Map<String, dynamic>;
      _nameCtrl.text = d['name'];
      _priceCtrl.text = d['price'].toString();
      _markupCtrl.text = d['markup'].toString();
      _existingImageUrl = d['image_url'];
      _selectedCurrency = d['currency'] ?? 'RMB';
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) setState(() => _imageFile = img);
  }

  Future<void> _save() async {
    setState(() => _isUploading = true);
    
    String imgUrl = _existingImageUrl ?? '';
    if (_imageFile != null) {
      final ref = FirebaseStorage.instance.ref().child('hotels/rooms/${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (kIsWeb) {
        await ref.putData(await _imageFile!.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(_imageFile!.path));
      }
      imgUrl = await ref.getDownloadURL();
    }

    final data = {
      'name': _nameCtrl.text,
      'price': double.tryParse(_priceCtrl.text) ?? 0,
      'markup': double.tryParse(_markupCtrl.text) ?? 0,
      'currency': _selectedCurrency,
      'image_url': imgUrl,
    };

    final col = FirebaseFirestore.instance.collection('hotels_db').doc(widget.hotelId).collection('rooms');
    if (widget.doc != null) {
      await widget.doc!.reference.update(data);
    } else {
      await col.add(data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.doc == null ? "Add Room Type" : "Edit Room", style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ImagePickerBox(
                imageFile: _imageFile, 
                existingUrl: _existingImageUrl, 
                onTap: _pickImage,
                label: "Room Photo",
                height: 120,
              ),
              const SizedBox(height: 20),
              _ModernInput(controller: _nameCtrl, label: "Room Name", hint: "e.g. Deluxe King"),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 8),
                    child: DropdownButtonFormField<String>(
                      value: _selectedCurrency,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                      items: kCurrencies.keys.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _selectedCurrency = v!),
                    ),
                  ),
                  Expanded(child: _ModernInput(controller: _priceCtrl, label: "Base Price", isNumber: true)),
                ],
              ),
              const SizedBox(height: 12),
              _ModernInput(controller: _markupCtrl, label: "Markup %", isNumber: true),
            ],
          ),
        ),
      ),
      actions: [
         if (_isUploading) const Center(child: CircularProgressIndicator())
         else ...[
           TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
           ElevatedButton(
             onPressed: _save, 
             //style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
             child: const Text("Save"),
           )
         ]
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// HELPER WIDGETS
// -----------------------------------------------------------------------------

class _ModernInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final bool isNumber;
  final FocusNode? focusNode;

  const _ModernInput({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.isNumber = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))] : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
    );
  }
}

class _ImagePickerBox extends StatelessWidget {
  final XFile? imageFile;
  final String? existingUrl;
  final VoidCallback onTap;
  final String label;
  final double height;

  const _ImagePickerBox({
    this.imageFile,
    this.existingUrl,
    required this.onTap,
    this.label = "Upload Image",
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    bool hasImage = imageFile != null || (existingUrl != null && existingUrl!.isNotEmpty);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: hasImage ? null : Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
          image: hasImage ? DecorationImage(
            image: imageFile != null 
              ? (kIsWeb ? NetworkImage(imageFile!.path) : FileImage(File(imageFile!.path))) as ImageProvider
              : NetworkImage(existingUrl!),
            fit: BoxFit.cover,
          ) : null,
        ),
        child: hasImage ? null : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: Colors.grey[400], size: 30),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      ),
    );
  }
}