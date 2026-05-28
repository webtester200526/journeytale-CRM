import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/pdfEditor/transport_editor.dart';
import 'package:crmx/permission_service.dart';
import 'package:crmx/service_model.dart';
import 'package:crmx/transport.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

 

class OrderTransportManager extends StatelessWidget {
  final String orderId;
  final OrderModel orderModel;

  const OrderTransportManager({
    super.key,
    required this.orderId,
    required this.orderModel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- HEADER ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Transport Schedule", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              children: [
                 // Shortcut to Manage Fleet
                 IconButton(
                  tooltip: "Manage Suppliers & Fleet",
                  icon: const Icon(Icons.garage, color: Colors.grey),
                  onPressed: () async {
                    bool granted = await PermissionService().canAccessTransport;
                    if (granted) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TransportSuppliersPage()));
                    }
                    else {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You do not have permission to manage transport fleet.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransportPdfEditorPage(
                          orderId: orderId,
                          orderModel: orderModel,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text("Booking PDF"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00A0E9),
                    side: const BorderSide(color: Color(0xFF00A0E9)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showTransportDialog(context, null),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Add"),
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 16),

        // --- LIST ---
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .collection('transport')
              .orderBy('date')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return _EmptyState();

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _TransportCard(
                  data: docs[index].data() as Map<String, dynamic>,
                  onEdit: () => _showTransportDialog(context, docs[index]),
                  onDelete: () => _deleteTransport(docs[index].id),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _deleteTransport(String docId) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).collection('transport').doc(docId).delete();
  }

  void _showTransportDialog(BuildContext context, DocumentSnapshot? doc) {
    showDialog(
      context: context,
      builder: (ctx) => _TransportEditorDialog(
        orderId: orderId,
        existingDoc: doc,
        defaultDate: orderModel.startDate,
      ),
    );
  }
}

// --- WIDGETS ---

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.directions_bus_outlined, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text("No transport arrangements added yet.", style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _TransportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TransportCard({required this.data, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final date = (data['date'] as Timestamp?)?.toDate();
    final fmtDate = date != null ? DateFormat('yyyy-MM-dd').format(date) : "No Date";
    
    final String currencyCode = data['currency'] ?? 'RMB'; 
    final currencyFormat = NumberFormat.simpleCurrency(name: currencyCode, decimalDigits: 0);

    final fee = (data['fee'] as num?)?.toDouble() ?? 0.0;
    final cost = (data['cost'] as num?)?.toDouble() ?? 0.0;
    final profit = fee - cost;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF00A0E9).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(fmtDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A0E9), fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Text(data['route_title'] ?? 'Day Trip', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(currencyFormat.format(fee), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text("P: ${currencyFormat.format(profit)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: profit>=0?Colors.green:Colors.red)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, size: 18, color: Colors.grey)),
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent)),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(data['route_details'] ?? '', style: TextStyle(color: Colors.grey[800], fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            children: [
              _InfoBadge(Icons.directions_car, "${data['vehicle']} (${data['plate'] ?? '-'})"),
              _InfoBadge(Icons.groups, "${data['pax']} Pax"),
              if (data['luggage'] != null) _InfoBadge(Icons.luggage, "${data['luggage']} Bags"),
            ],
          ),
          if (data['notes'] != null && data['notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text("Note: ${data['notes']}", style: const TextStyle(fontSize: 12, color: Colors.red, fontStyle: FontStyle.italic)),
          ]
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBadge(this.icon, this.text);
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// --- EDITOR DIALOG ---

class _TransportEditorDialog extends StatefulWidget {
  final String orderId;
  final DocumentSnapshot? existingDoc;
  final DateTime defaultDate;

  const _TransportEditorDialog({required this.orderId, this.existingDoc, required this.defaultDate});

  @override
  State<_TransportEditorDialog> createState() => _TransportEditorDialogState();
}

class _TransportEditorDialogState extends State<_TransportEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleCtrl;
  late TextEditingController _detailsCtrl;
  late TextEditingController _vehicleCtrl;
  late TextEditingController _plateCtrl;
  late TextEditingController _paxCtrl;
  late TextEditingController _luggageCtrl;
  late TextEditingController _feeCtrl; 
  late TextEditingController _costCtrl; 
  late TextEditingController _notesCtrl;
  late DateTime _selectedDate;
  String _selectedCurrency = 'RMB';

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existingDoc?.data() as Map<String, dynamic>?;
    
    _titleCtrl = TextEditingController(text: data?['route_title'] ?? '');
    _detailsCtrl = TextEditingController(text: data?['route_details'] ?? '');
    _vehicleCtrl = TextEditingController(text: data?['vehicle'] ?? '');
    _plateCtrl = TextEditingController(text: data?['plate'] ?? '');
    _paxCtrl = TextEditingController(text: data?['pax']?.toString() ?? '1');
    _luggageCtrl = TextEditingController(text: data?['luggage']?.toString() ?? '');
    _feeCtrl = TextEditingController(text: data?['fee']?.toString() ?? '0');
    _costCtrl = TextEditingController(text: data?['cost']?.toString() ?? '0');
    _notesCtrl = TextEditingController(text: data?['notes'] ?? '');
    _selectedDate = (data?['date'] as Timestamp?)?.toDate() ?? widget.defaultDate;
    _selectedCurrency = data?['currency'] ?? 'RMB';
  }

  // --- NEW: Load from Fleet Logic ---
  void _openFleetSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => _FleetSelectorSheet(
          scrollController: scrollController,
          onSelected: (vehicleData) {
            // AUTO FILL LOGIC
            setState(() {
              // 1. Fill Vehicle Name
              _vehicleCtrl.text = "${vehicleData['name']} (${vehicleData['type']})";
              
              // 2. Fill Capacity
              _paxCtrl.text = vehicleData['capacity'].toString();
              
              // 3. Fill Currency
              _selectedCurrency = vehicleData['currency'] ?? 'RMB';

              // 4. Calculate Prices
              double base = (vehicleData['base_price'] ?? 0).toDouble();
              double markupPercent = (vehicleData['markup_percent'] ?? 0).toDouble();
              double clientFee = base * (1 + markupPercent/100);

              _costCtrl.text = base.toString(); // Internal Cost
              _feeCtrl.text = clientFee.toStringAsFixed(0); // Client Fee
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final data = {
      'date': Timestamp.fromDate(_selectedDate),
      'route_title': _titleCtrl.text,
      'route_details': _detailsCtrl.text,
      'vehicle': _vehicleCtrl.text,
      'plate': _plateCtrl.text,
      'pax': int.tryParse(_paxCtrl.text) ?? 0,
      'luggage': _luggageCtrl.text,
      'fee': double.tryParse(_feeCtrl.text) ?? 0.0,
      'cost': double.tryParse(_costCtrl.text) ?? 0.0,
      'currency': _selectedCurrency,
      'notes': _notesCtrl.text,
    };

    final col = FirebaseFirestore.instance.collection('orders').doc(widget.orderId).collection('transport');
    if (widget.existingDoc != null) {
      await col.doc(widget.existingDoc!.id).update(data);
    } else {
      await col.add(data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingDoc == null ? "Add Transport" : "Edit Transport"),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- NEW BUTTON ---
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openFleetSelector,
                    icon: const Icon(Icons.directions_car, size: 16),
                    label: const Text("Load Vehicle from Fleet"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Date
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (d != null) setState(() => _selectedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                _input(_titleCtrl, "Route Title", hint: "e.g. Shanghai Day Tour"),
                _input(_detailsCtrl, "Route Details", maxLines: 3, hint: "A -> B -> C -> Hotel"),
                
                Row(
                  children: [
                    Expanded(child: _input(_vehicleCtrl, "Vehicle Type")),
                    const SizedBox(width: 12),
                    Expanded(child: _input(_plateCtrl, "BOARD / Plate")),
                  ],
                ),
                
                Row(
                  children: [
                    Expanded(child: _input(_paxCtrl, "Pax", isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _input(_luggageCtrl, "Luggage")),
                  ],
                ),

                const SizedBox(height: 8),
                const Text("Financials", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    Expanded(flex: 2, child: _input(_costCtrl, "Internal Cost", isNumber: true)),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCurrency,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: "Curr.",
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          'IDR', 'RMB', 'EUR', 'USD', 'SGD', 'MYR',
                          'JPY', 'CHF', 'KRW', 'TWD', 'HKD', 'MOP', 'AUD',
                        ].map((c) => 
                          DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))
                        ).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCurrency = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _input(_feeCtrl, "Client Price", isNumber: true)),
                    const SizedBox(width: 8),
                  ],
                ),

                _input(_notesCtrl, "Special Notes"),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel",style: TextStyle(color: Colors.red))),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: Colors.black),
          child: Text(_isSaving ? "Saving..." : "Save"),
        )
      ],
    );
  }

 Widget _input(
  TextEditingController ctrl,
  String label, {
  int maxLines = 1,
  bool isNumber = false,
  String? hint,
}) {
  final bool isMultiline = maxLines > 1;

  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      minLines: isMultiline ? 1 : null,
      keyboardType: isMultiline
          ? TextInputType.multiline
          : (isNumber ? TextInputType.number : TextInputType.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        isDense: true,
      ),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    ),
  );
 }
}

// --- HELPER SHEET FOR SELECTING VEHICLE ---

class _FleetSelectorSheet extends StatelessWidget {
  final ScrollController scrollController;
  final Function(Map<String, dynamic>) onSelected;

  const _FleetSelectorSheet({required this.scrollController, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text("Select Vehicle from Fleet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('transport_suppliers').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final suppliers = snapshot.data!.docs;
                
                return ListView.builder(
                  controller: scrollController,
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = suppliers[index];
                    final sData = supplier.data() as Map<String, dynamic>;

                    return Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(sData['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(sData['city']),
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream: supplier.reference.collection('vehicles').orderBy('base_price').snapshots(),
                            builder: (ctx, vSnap) {
                              if (!vSnap.hasData) return const SizedBox();
                              final vehicles = vSnap.data!.docs;
                              return Column(
                                children: vehicles.map((v) {
                                  final vData = v.data() as Map<String, dynamic>;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                                    leading: const Icon(Icons.directions_car, size: 18),
                                    title: Text("${vData['name']} (${vData['type']})"),
                                    subtitle: Text("Cost: ${vData['base_price']} | Markup: ${vData['markup_percent']}%"),
                                    onTap: () => onSelected(vData),
                                  );
                                }).toList(),
                              );
                            },
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}