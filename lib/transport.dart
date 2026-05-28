import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class TransportSuppliersPage extends StatelessWidget {
  const TransportSuppliersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Modern Light Grey Background
      appBar: AppBar(
        title: const Text(
          "Transport Fleet Management",
         // style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('transport_suppliers').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final suppliers = snapshot.data!.docs;

          if (suppliers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No suppliers added yet", style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: suppliers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return _SupplierCard(doc: supplier);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupplierDialog(context, null),
        label: const Text("New Supplier", style: TextStyle(fontWeight: FontWeight.w600)),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue,
        elevation: 4,
      ),
    );
  }

  void _showSupplierDialog(BuildContext context, DocumentSnapshot? doc) {
    showDialog(context: context, builder: (_) => _SupplierEditor(doc: doc));
  }
}

class _SupplierCard extends StatelessWidget {
  final DocumentSnapshot doc;
  const _SupplierCard({required this.doc});

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Supplier?"),
        content: const Text("This will remove the supplier and their details. This action cannot be undone."),
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
    final String name = data['name'] ?? 'Unknown';
    final String initial = name.isNotEmpty ? name[0] : '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blueGrey.shade50,
            child: Text(initial, style: TextStyle(color: Colors.blueGrey.shade800, fontWeight: FontWeight.bold)),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(data['city'] ?? '-', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(width: 12),
                Icon(Icons.person, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(data['contact_person'] ?? '-', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[400]),
            onSelected: (value) {
              if (value == 'edit') {
                showDialog(context: context, builder: (_) => _SupplierEditor(doc: doc));
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
                child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 10), Text("Delete Supplier", style: TextStyle(color: Colors.red))]),
              ),
            ],
          ),
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: _VehicleList(supplierId: doc.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleList extends StatelessWidget {
  final String supplierId;
  const _VehicleList({required this.supplierId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transport_suppliers')
          .doc(supplierId)
          .collection('vehicles')
          .orderBy('base_price')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
        final vehicles = snapshot.data!.docs;

        return Column(
          children: [
            if (vehicles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text("No vehicles in fleet.", style: TextStyle(color: Colors.grey[400], fontSize: 13, fontStyle: FontStyle.italic)),
                ),
              ),
            ...vehicles.map((v) => _VehicleRow(doc: v)).toList(),
            
            // Add Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showVehicleDialog(context, null),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Add Vehicle to Fleet"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            )
          ],
        );
      },
    );
  }

  void _showVehicleDialog(BuildContext context, DocumentSnapshot? doc) {
    showDialog(context: context, builder: (_) => _VehicleEditor(supplierId: supplierId, doc: doc));
  }
}

class _VehicleRow extends StatelessWidget {
  final DocumentSnapshot doc;
  const _VehicleRow({required this.doc});

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Vehicle?"),
        content: const Text("Are you sure you want to remove this vehicle from the fleet?"),
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
    final vData = doc.data() as Map<String, dynamic>;
    final currency = NumberFormat.simpleCurrency(name: vData['currency'] ?? 'RMB', decimalDigits: 0);

    double base = (vData['base_price'] ?? 0).toDouble();
    double markup = (vData['markup_percent'] ?? 0).toDouble();
    double total = base * (1 + markup / 100);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
            child: Icon(_getIconForType(vData['type']), size: 20, color: Colors.black87),
          ),
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${vData['name']} (${vData['type']})", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Badge(text: "${vData['capacity']} Pax", color: Colors.blueGrey, icon: Icons.groups),
                    const SizedBox(width: 8),
                    _Badge(text: "+${markup.toStringAsFixed(0)}%", color: Colors.amber, icon: Icons.trending_up),
                  ],
                )
              ],
            ),
          ),

          // Pricing
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(currency.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              Text("Base: ${currency.format(base)}", style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ],
          ),
          const SizedBox(width: 16),
          
          // Actions
          PopupMenuButton(
            icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[400]),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text("Edit")])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
            ],
            onSelected: (val) {
              if (val == 'edit') {
                 showDialog(context: context, builder: (_) => _VehicleEditor(supplierId: doc.reference.parent.parent!.id, doc: doc));
              } else if (val == 'delete') {
                _confirmDelete(context);
              }
            },
          )
        ],
      ),
    );
  }

  IconData _getIconForType(String? type) {
    String t = (type ?? '').toLowerCase();
    if (t.contains('bus')) return Icons.directions_bus;
    if (t.contains('van')) return Icons.airport_shuttle;
    return Icons.directions_car;
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _Badge({required this.text, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// --- DIALOGS ---

class _SupplierEditor extends StatefulWidget {
  final DocumentSnapshot? doc;
  const _SupplierEditor({this.doc});
  @override
  State<_SupplierEditor> createState() => _SupplierEditorState();
}

class _SupplierEditorState extends State<_SupplierEditor> {
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!.data() as Map<String, dynamic>;
      _nameCtrl.text = d['name'];
      _contactCtrl.text = d['contact_person'];
      _cityCtrl.text = d['city'];
    }
  }

  Future<void> _save() async {
    final data = {
      'name': _nameCtrl.text,
      'contact_person': _contactCtrl.text,
      'city': _cityCtrl.text,
    };
    if (widget.doc != null) {
      await widget.doc!.reference.update(data);
    } else {
      await FirebaseFirestore.instance.collection('transport_suppliers').add(data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.doc == null ? "Add Supplier" : "Edit Supplier", style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModernInput(controller: _nameCtrl, label: "Company Name"),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _ModernInput(controller: _contactCtrl, label: "Contact Person")),
              const SizedBox(width: 12),
              Expanded(child: _ModernInput(controller: _cityCtrl, label: "City / Area")),
            ],
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: _save, 
         
          child: const Text("Save Supplier"),
        ),
      ],
    );
  }
}

class _VehicleEditor extends StatefulWidget {
  final String supplierId;
  final DocumentSnapshot? doc;
  const _VehicleEditor({required this.supplierId, this.doc});
  @override
  State<_VehicleEditor> createState() => _VehicleEditorState();
}

class _VehicleEditorState extends State<_VehicleEditor> {
  final _nameCtrl = TextEditingController();
  final _typeCtrl = TextEditingController(text: "Van");
  final _capacityCtrl = TextEditingController();
  final _basePriceCtrl = TextEditingController();
  final _markupCtrl = TextEditingController(text: "20");
  String _currency = 'RMB';

  // Real-time calculation state
  double _calculatedClientPrice = 0;

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!.data() as Map<String, dynamic>;
      _nameCtrl.text = d['name'];
      _typeCtrl.text = d['type'];
      _capacityCtrl.text = d['capacity'].toString();
      _basePriceCtrl.text = d['base_price'].toString();
      _markupCtrl.text = d['markup_percent'].toString();
      _currency = d['currency'] ?? 'RMB';
    }
    _calcPrice();
  }

  void _calcPrice() {
    double base = double.tryParse(_basePriceCtrl.text) ?? 0;
    double markup = double.tryParse(_markupCtrl.text) ?? 0;
    setState(() {
      _calculatedClientPrice = base * (1 + markup / 100);
    });
  }

  Future<void> _save() async {
    final data = {
      'name': _nameCtrl.text,
      'type': _typeCtrl.text,
      'capacity': int.tryParse(_capacityCtrl.text) ?? 0,
      'base_price': double.tryParse(_basePriceCtrl.text) ?? 0,
      'markup_percent': double.tryParse(_markupCtrl.text) ?? 0,
      'currency': _currency,
    };
    final col = FirebaseFirestore.instance.collection('transport_suppliers').doc(widget.supplierId).collection('vehicles');
    
    if (widget.doc != null) {
      await widget.doc!.reference.update(data);
    } else {
      await col.add(data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = NumberFormat.simpleCurrency(name: _currency).currencySymbol;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.doc == null ? "Add Vehicle" : "Edit Vehicle", style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ModernInput(controller: _nameCtrl, label: "Vehicle Name", hint: "e.g. Toyota Alphard"),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _ModernInput(controller: _typeCtrl, label: "Type", hint: "Car, Van, Bus")),
                const SizedBox(width: 12),
                Expanded(child: _ModernInput(controller: _capacityCtrl, label: "Capacity (Pax)", isNumber: true)),
              ],
            ),
            const SizedBox(height: 20),
            const Text("Pricing Structure", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _ModernInput(
                    controller: _basePriceCtrl, 
                    label: "Internal Price", 
                    isNumber: true, 
                    onChanged: (_) => _calcPrice(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _ModernInput(
                    controller: _markupCtrl, 
                    label: "Markup %", 
                    isNumber: true,
                    onChanged: (_) => _calcPrice(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      labelText: "Curr"
                    ),
                    items: [
                      'IDR', 'RMB', 'EUR', 'USD', 'SGD', 'MYR',
                      'JPY', 'CHF', 'KRW', 'TWD', 'HKD', 'MOP', 'AUD',
                    ].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) {
                      setState(() => _currency = v!);
                      _calcPrice();
                    },
                  ),
                )
              ],
            ),
            
            // Preview Calculation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Final Client Price:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                  Text("$currencySymbol${_calculatedClientPrice.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade800)),
                ],
              ),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: _save, 
          //style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text("Save Vehicle"),
        ),
      ],
    );
  }
}

class _ModernInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool isNumber;
  final Function(String)? onChanged;

  const _ModernInput({
    required this.controller,
    required this.label,
    this.hint,
    this.isNumber = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))] : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: Colors.grey[600]),
      ),
    );
  }
}