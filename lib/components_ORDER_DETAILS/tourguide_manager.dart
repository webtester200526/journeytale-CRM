import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/pdfEditor/tourguide_editor.dart';
import 'package:crmx/service_model.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Import your models and the PDF editor



class TourGuideManager extends StatelessWidget {
  final String orderId;
  final OrderModel orderModel;

  const TourGuideManager({
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
            const Text("Tour Guide Assignments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () => _showEditorDialog(context, null),
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text("Assign Guide"),
              style: ElevatedButton.styleFrom(
               
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // --- LIST ---
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .collection('tourguides')
              .orderBy('start_date')
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
                final data = docs[index].data() as Map<String, dynamic>;
                return _GuideCard(
                  data: data,
                  orderId: orderId,
                  orderModel: orderModel,
                  docId: docs[index].id,
                  onEdit: () => _showEditorDialog(context, docs[index]),
                  onDelete: () => _deleteGuide(context, docs[index].id), 
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _deleteGuide(BuildContext context, String docId) async {
  // 1. Show Confirmation Dialog
  bool? confirm = await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Remove Tour Guide?"),
      content: const Text("Are you sure you want to remove this assignment? This action cannot be undone."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("Remove", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  // 2. Delete if Confirmed
  if (confirm == true) {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .collection('tourguides')
        .doc(docId)
        .delete();
  }
}

  void _showEditorDialog(BuildContext context, DocumentSnapshot? doc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GuideEditorDialog(
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
          Icon(Icons.badge_outlined, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text("No tour guides assigned.", style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;
  final OrderModel orderModel;
  final String docId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GuideCard({
    required this.data,
    required this.orderId,
    required this.orderModel,
    required this.docId,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final start = (data['start_date'] as Timestamp?)?.toDate();
    final end = (data['end_date'] as Timestamp?)?.toDate();
    final fmt = DateFormat('dd MMM');
    
    // Currency & Calculation
    final String currencyCode = data['currency'] ?? 'RMB';
    final currency = NumberFormat.simpleCurrency(name: currencyCode, decimalDigits: 0);
    
    final double feePerDay = (data['fee_per_day'] ?? 0).toDouble();
    final double otRate = (data['ot_fee'] ?? 0).toDouble();
    final double otHours = (data['total_ot_hours'] ?? 0).toDouble();
    
    // Days calc
    int days = 1;
    if (start != null && end != null) {
      days = end.difference(start).inDays + 1;
    }
    
    final double baseTotal = feePerDay * days;
    final double otTotal = otRate * otHours;
    final double grandTotal = baseTotal + otTotal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.amber.shade50,
                    foregroundColor: Colors.amber,
                    child: Text(data['name'] != null ? data['name'][0].toUpperCase() : "?"),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Area: ${data['area'] ?? '-'}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Total: ${currency.format(grandTotal)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                  Text("(${days}d @ ${currency.format(feePerDay)} + ${otHours}h OT)", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    start != null ? "${fmt.format(start)} - ${fmt.format(end!)}" : "Dates Not Set",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  // PDF BUTTON
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.blue, size: 18),
                    tooltip: "Generate Assignment PDF",
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TourGuidePdfEditorPage(
                        orderId: orderId,
                        orderModel: orderModel,
                        guideData: data,
                      )));
                    },
                  ),
                  IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, size: 18, color: Colors.grey)),
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}

// --- EDITOR DIALOG ---

class _GuideEditorDialog extends StatefulWidget {
  final String orderId;
  final DocumentSnapshot? existingDoc;
  final DateTime defaultDate;

  const _GuideEditorDialog({required this.orderId, this.existingDoc, required this.defaultDate});

  @override
  State<_GuideEditorDialog> createState() => _GuideEditorDialogState();
}

class _GuideEditorDialogState extends State<_GuideEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  
  final _feeCtrl = TextEditingController();
  final _workHoursCtrl = TextEditingController(text: "10"); // Default 10h workday
  
  final _otFeeCtrl = TextEditingController();
  final _otHoursCtrl = TextEditingController(text: "0"); // Actual OT done

  final _transportPolicyCtrl = TextEditingController(text: "Perjalanan berangkat atau pulang pada jam 22:00 - 07:00 dapat direimburse biaya taksi. MRT/Bus juga dapat direimburse.");
  final _foodPolicyCtrl = TextEditingController(text: "Makan bersama dengan tamu.");
  final _notesCtrl = TextEditingController();

  late DateTime _startDate;
  late DateTime _endDate;
  String _selectedCurrency = 'RMB'; // Default
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existingDoc?.data() as Map<String, dynamic>?;
    
    _nameCtrl.text = data?['name'] ?? '';
    _passportCtrl.text = data?['passport'] ?? '';
    _areaCtrl.text = data?['area'] ?? 'HangZhou 杭州';
    
    _feeCtrl.text = data?['fee_per_day']?.toString() ?? '450';
    _workHoursCtrl.text = data?['working_hours_per_day']?.toString() ?? '10';
    
    _otFeeCtrl.text = data?['ot_fee']?.toString() ?? '50';
    _otHoursCtrl.text = data?['total_ot_hours']?.toString() ?? '0';

    if(data?['transport_policy'] != null) _transportPolicyCtrl.text = data!['transport_policy'];
    if(data?['food_policy'] != null) _foodPolicyCtrl.text = data!['food_policy'];
    _notesCtrl.text = data?['notes'] ?? '';
    _selectedCurrency = data?['currency'] ?? 'RMB';

    _startDate = (data?['start_date'] as Timestamp?)?.toDate() ?? widget.defaultDate;
    _endDate = (data?['end_date'] as Timestamp?)?.toDate() ?? widget.defaultDate;
  }

  // --- Calculations ---
  String get _calculatedTotal {
    double daily = double.tryParse(_feeCtrl.text) ?? 0;
    double otRate = double.tryParse(_otFeeCtrl.text) ?? 0;
    double otHours = double.tryParse(_otHoursCtrl.text) ?? 0;
    
    int days = _endDate.difference(_startDate).inDays + 1;
    if (days < 1) days = 1;

    double total = (daily * days) + (otRate * otHours);
    
    final format = NumberFormat.simpleCurrency(name: _selectedCurrency);
    return format.format(total);
  }

  // --- NEW: Load from Profile ---
  void _loadFromProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: 500,
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(16.0), child: Text("Select Saved Guide", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tourguides').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final profiles = snapshot.data!.docs;
                  return ListView.separated(
                    itemCount: profiles.length,
                    separatorBuilder: (_,__) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = profiles[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: CircleAvatar(child: Text(p['name'][0])),
                        title: Text(p['name']),
                        subtitle: Text("${p['area']} • Age: ${p['age'] ?? '-'}"),
                        trailing: Text("¥${p['default_fee'] ?? 0}"),
                        onTap: () {
                          // Fill Form
                          setState(() {
                            _nameCtrl.text = p['name'];
                            if(p['passport'] != null) _passportCtrl.text = p['passport'];
                            if(p['area'] != null) _areaCtrl.text = p['area'];
                            if(p['default_fee'] != null) _feeCtrl.text = p['default_fee'].toString();
                            if(p['currency'] != null) _selectedCurrency = p['currency'];
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      )
    );
  }

  Future<void> _saveAsProfile() async {
    if (_nameCtrl.text.isEmpty) return;
    
    bool? confirm = await showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text("Save to Profiles"), 
        content: Text("Create a new master profile for '${_nameCtrl.text}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Yes")),
        ],
      )
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('tourguides').add({
        'name': _nameCtrl.text,
        'passport': _passportCtrl.text,
        'area': _areaCtrl.text,
        'default_fee': double.tryParse(_feeCtrl.text) ?? 0,
        'currency': _selectedCurrency,
        'notes': _notesCtrl.text, 
        'created_at': Timestamp.now(),
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Saved!")));
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if(picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final data = {
      'name': _nameCtrl.text,
      'passport': _passportCtrl.text,
      'area': _areaCtrl.text,
      'start_date': Timestamp.fromDate(_startDate),
      'end_date': Timestamp.fromDate(_endDate),
      
      'fee_per_day': double.tryParse(_feeCtrl.text) ?? 0,
      'working_hours_per_day': double.tryParse(_workHoursCtrl.text) ?? 10,
      
      'ot_fee': double.tryParse(_otFeeCtrl.text) ?? 0,
      'total_ot_hours': double.tryParse(_otHoursCtrl.text) ?? 0,
      
      'currency': _selectedCurrency,
      
      'transport_policy': _transportPolicyCtrl.text,
      'food_policy': _foodPolicyCtrl.text,
      'notes': _notesCtrl.text,
    };

    final col = FirebaseFirestore.instance.collection('orders').doc(widget.orderId).collection('tourguides');

    if (widget.existingDoc != null) {
      await col.doc(widget.existingDoc!.id).update(data);
    } else {
      await col.add(data);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("Tour Guide Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ]),
                const Divider(height: 20),

                // Button Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text("Load Saved Profile"),
                        onPressed: _loadFromProfile,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text("Save as New Profile"),
                        onPressed: _saveAsProfile,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Basic Info
                Row(children: [
                  Expanded(child: _input(_nameCtrl, "Name (English/Chinese)")),
                  const SizedBox(width: 12),
                  Expanded(child: _input(_passportCtrl, "Passport / ID No.")),
                ]),
                _input(_areaCtrl, "Area / City (e.g. Shanghai 上海)"),

                // 2. Dates
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickDateRange,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: "Assignment Dates", border: OutlineInputBorder()),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}"),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Financials Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Calculated Fee:", style: TextStyle(fontWeight: FontWeight.bold)),
                    // Currency Selector
                    DropdownButton<String>(
                      value: _selectedCurrency,
                      underline: Container(),
                      items: ['RMB', 'IDR', 'USD', 'EUR', 'JPY', 'SGD'].map((c) => 
                        DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)))
                      ).toList(),
                      onChanged: (val) {
                        if(val != null) setState(() => _selectedCurrency = val);
                      },
                    )
                  ],
                ),
                const SizedBox(height: 8),

                // 4. Fees Inputs
                Row(children: [
                  Expanded(child: _input(_feeCtrl, "Fee per Day", isNumber: true, onChanged: (_) => setState((){}))),
                  const SizedBox(width: 12),
                  Expanded(child: _input(_workHoursCtrl, "Work Hours/Day", isNumber: true)), // Just info
                ]),
                
                Row(children: [
                  Expanded(child: _input(_otFeeCtrl, "OT Rate / Hour", isNumber: true, onChanged: (_) => setState((){}))),
                  const SizedBox(width: 12),
                  Expanded(child: _input(_otHoursCtrl, "Total OT Hours", isNumber: true, onChanged: (_) => setState((){}))),
                ]),

                // Calculated Total Display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Estimated Total Pay:", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Text(_calculatedTotal, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),

                // 5. Policies
                _input(_transportPolicyCtrl, "Transport Policy", maxLines: 3),
                _input(_foodPolicyCtrl, "Food / Consumption Policy"),
                
                // 6. Notes
                _input(_notesCtrl, "Special Notes (Red Text in PDF)", maxLines: 2),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(),
                    child: Text(_isSaving ? "Saving..." : "Save Assignment"),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController ctrl, 
    String label, 
    {int maxLines = 1, bool isNumber = false, ValueChanged<String>? onChanged}
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        onChanged: onChanged,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          isDense: true,
        ),
        validator: (v) => v!.isEmpty ? "Required" : null,
      ),
    );
  }
}