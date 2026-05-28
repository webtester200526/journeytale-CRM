import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ForexPage extends StatefulWidget {
  const ForexPage({super.key});

  @override
  State<ForexPage> createState() => _ForexPageState();
}

class _ForexPageState extends State<ForexPage> {
  // Filters
  DateTimeRange? _dateRange;
  String _selectedTargetCurrency = 'All';
  final List<String> _currencies = ['All', 'RMB', 'USD', 'SGD', 'MYR', 'EUR', 'HKD', 'IDR'];

  // Cache
  List<QueryDocumentSnapshot> _allDocs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    Query query = FirebaseFirestore.instance.collection('currency').orderBy('date', descending: true);
    
    // Apply Date Filter
    if (_dateRange != null) {
      query = query
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_dateRange!.start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_dateRange!.end));
    }

    query.snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _allDocs = snapshot.docs;
          
          // Apply Currency Filter locally (Target Currency)
          if (_selectedTargetCurrency != 'All') {
            _allDocs = _allDocs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return data['target_currency'] == _selectedTargetCurrency;
            }).toList();
          }
          
          _isLoading = false;
        });
      }
    });
  }

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _isLoading = true;
      });
      _fetchData();
    }
  }

  void _clearFilters() {
    setState(() {
      _dateRange = null;
      _selectedTargetCurrency = 'All';
      _isLoading = true;
    });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Forex Management", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          DropdownButton<String>(
            value: _selectedTargetCurrency,
            underline: const SizedBox(),
            icon: const Icon(Icons.filter_list),
            items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) {
              setState(() {
                _selectedTargetCurrency = v!;
                _isLoading = true;
              });
              _fetchData();
            },
          ),
          const SizedBox(width: 8),
          IconButton(onPressed: _pickDateRange, icon: const Icon(Icons.calendar_month), tooltip: "Filter Date"),
          IconButton(onPressed: _clearFilters, icon: const Icon(Icons.filter_alt_off), tooltip: "Clear Filters"),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
            children: [
              // 1. Analytics Dashboard (Multi-Currency Support)
              _ForexDashboard(docs: _allDocs),
              
              // 2. Transaction List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _allDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _ForexCard(
                      doc: _allDocs[index], 
                      onEdit: () => _showEditor(context, _allDocs[index]),
                    );
                  },
                ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context, null),
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Exchange", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showEditor(BuildContext context, DocumentSnapshot? doc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ForexEditorDialog(existingDoc: doc),
    );
  }
}

// ==========================================
// 1. ANALYTICS DASHBOARD
// ==========================================

class _ForexDashboard extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  const _ForexDashboard({required this.docs});

  @override
  Widget build(BuildContext context) {
    // Aggregate Profits by BASE Currency
    final Map<String, double> profits = {};
    int txnCount = docs.length;
    
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Compatibility: If 'base_currency' missing, assume IDR. 
      // Compatibility: If 'profit_amount' missing, use 'profit_idr'.
      String base = data['base_currency'] ?? 'IDR';
      double profit = (data['profit_amount'] ?? data['profit_idr'] ?? 0).toDouble();

      profits[base] = (profits[base] ?? 0) + profit;
    }

    if (profits.isEmpty) {
      // Default empty state
      return Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: const _KpiCard("Net Profit", "0", Icons.trending_up, Colors.grey),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Profit Summary", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              Text("$txnCount Txns", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: profits.entries.map((e) {
              final fmt = NumberFormat.simpleCurrency(name: e.key, decimalDigits: 0);
              return _KpiCard(
                "Profit (${e.key})", 
                fmt.format(e.value), 
                Icons.trending_up, 
                e.value >= 0 ? Colors.green : Colors.red
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String displayValue;
  final IconData icon;
  final Color color;

  const _KpiCard(this.title, this.displayValue, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 8), Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          Text(displayValue, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

// ==========================================
// 2. TRANSACTION LIST CARD
// ==========================================

class _ForexCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final VoidCallback onEdit;

  const _ForexCard({required this.doc, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['date'] as Timestamp).toDate();
    
    // Currency Logic
    final String base = data['base_currency'] ?? 'IDR';
    final String target = data['target_currency'] ?? 'RMB';
    
    final fmtBase = NumberFormat.simpleCurrency(name: '$base ', decimalDigits: 0);
    final fmtTarget = NumberFormat.simpleCurrency(name: '$target ', decimalDigits: 0);
    
    final double profit = (data['profit_amount'] ?? data['profit_idr'] ?? 0).toDouble();
    final double amountForeign = (data['amount_foreign'] as num).toDouble();
    final receipts = List<String>.from(data['receipts'] ?? []);
    
    // Determine Transaction Type
    final String type = data['txn_type'] ?? 'SELL'; 
    final bool isWeSellingForeign = type == 'SELL';
    
    final Color typeColor = isWeSellingForeign ? Colors.blue : Colors.amber;
    final String typeLabel = isWeSellingForeign ? "WE SOLD $target" : "WE BOUGHT $target";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(isWeSellingForeign ? Icons.arrow_outward : Icons.arrow_downward, color: typeColor),
              ),
              const SizedBox(width: 16),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Badge(typeLabel, typeColor),
                        const SizedBox(width: 8),
                        Expanded(child: Text(data['customer_name'] ?? 'Unknown', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(DateFormat('dd MMM yyyy, HH:mm').format(date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Badge("Client Rate: ${isWeSellingForeign ? data['sell_rate'] : data['buy_rate']}", Colors.black87),
                        const SizedBox(width: 8),
                        Text(
                          "Base Rate: ${isWeSellingForeign ? data['buy_rate'] : data['sell_rate']}", 
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              
              // Numbers
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmtTarget.format(amountForeign), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Container(
                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                     decoration: BoxDecoration(
                       color: profit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                       borderRadius: BorderRadius.circular(4)
                     ),
                     child: Text(
                       "Profit: ${fmtBase.format(profit)}", 
                       style: TextStyle(fontWeight: FontWeight.bold, color: profit >= 0 ? Colors.green : Colors.red, fontSize: 11)
                     ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              
              // Menu
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (ctx) => [
                  if (data['id'] != null) // Only show print if ID exists for now, or pass full logic
                  const PopupMenuItem(value: 'print', child: Row(children: [Icon(Icons.print, size: 18), SizedBox(width: 8), Text("Receipt")])),
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
                ],
                onSelected: (v) {
                  if (v == 'print') {
                    // Make sure you have the receipt page logic
                    // Navigator.push(context, MaterialPageRoute(builder: (_) => ForexReceiptPdfPage(transactionData: data, docId: doc.id)));
                  }
                  if (v == 'edit') onEdit();
                  if (v == 'delete') _confirmDelete(context); 
                },
              )
            ],
          ),
          
          if (receipts.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: receipts.length,
                separatorBuilder: (_,__) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => showDialog(context: context, builder: (_) => Dialog(child: Image.network(receipts[i]))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(receipts[i], width: 50, height: 50, fit: BoxFit.cover),
                  ),
                ),
              ),
            )
          ]
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Transaction"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (shouldDelete == true) {
      await FirebaseFirestore.instance.collection('currency').doc(doc.id).delete();
    }
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

// ==========================================
// 3. EDITOR DIALOG (UPDATED FOR MULTI-CURRENCY)
// ==========================================

class _ForexEditorDialog extends StatefulWidget {
  final DocumentSnapshot? existingDoc;
  const _ForexEditorDialog({this.existingDoc});

  @override
  State<_ForexEditorDialog> createState() => _ForexEditorDialogState();
}

class _ForexEditorDialogState extends State<_ForexEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Fields
  String _txnType = 'SELL'; 
  String _customerName = '';
  String _targetCurrency = 'RMB';
  String _baseCurrency = 'IDR'; // NEW: The currency we profit in

  final List<String> _currencies = [
  'IDR', 'RMB', 'EUR', 'USD', 'SGD', 'MYR',
  'JPY', 'CHF', 'KRW', 'TWD', 'HKD', 'MOP', 'AUD',
];
  
  final _amountForeignCtrl = TextEditingController();
  final _buyRateCtrl = TextEditingController(); 
  final _sellRateCtrl = TextEditingController(); 
  
  // Calculated
  double _profit = 0;
  double _totalBase_Client = 0; 
  double _totalBase_Market = 0;   

  // Images
  final List<XFile> _newImages = [];
  final List<String> _existingImages = [];
  bool _isUploading = false;
  
  // Customer Dropdown
  List<String> _customerList = [];
  bool _isManualCustomer = false;
  final _manualCustomerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    
    if (widget.existingDoc != null) {
      final d = widget.existingDoc!.data() as Map<String, dynamic>;
      _txnType = d['txn_type'] ?? 'SELL';
      _customerName = d['customer_name'] ?? '';
      _isManualCustomer = true; 
      _manualCustomerCtrl.text = _customerName;
      
      _targetCurrency = d['target_currency'] ?? 'RMB';
      _baseCurrency = d['base_currency'] ?? 'IDR'; // Load base currency
      
      _amountForeignCtrl.text = d['amount_foreign'].toString();
      _buyRateCtrl.text = d['buy_rate'].toString();
      _sellRateCtrl.text = d['sell_rate'].toString();
      
      _existingImages.addAll(List<String>.from(d['receipts'] ?? []));
      _calculate();
    }

    _amountForeignCtrl.addListener(_calculate);
    _buyRateCtrl.addListener(_calculate);
    _sellRateCtrl.addListener(_calculate);
  }

  Future<void> _fetchCustomers() async {
    final snap = await FirebaseFirestore.instance.collection('customers').orderBy('name').get();
    setState(() {
      _customerList = snap.docs.map((d) => d['name'] as String).toList();
    });
  }

  void _calculate() {
    double qty = double.tryParse(_amountForeignCtrl.text) ?? 0;
    double buyRate = double.tryParse(_buyRateCtrl.text) ?? 0;
    double sellRate = double.tryParse(_sellRateCtrl.text) ?? 0;

    // Logic: 
    // SELL Foreign: We receive Base (Sell Rate) from Client, We pay Base (Buy Rate) to Market.
    // BUY Foreign: We pay Base (Buy Rate) to Client, We receive Base (Sell Rate) from Market.
    
    setState(() {
      _profit = (sellRate - buyRate) * qty;

      if (_txnType == 'SELL') {
        _totalBase_Client = qty * sellRate; 
        _totalBase_Market = qty * buyRate;
      } else {
        _totalBase_Client = qty * buyRate;
        _totalBase_Market = qty * sellRate;
      }
    });
  }

  Future<void> _pickImages() async {
    final List<XFile> picked = await ImagePicker().pickMultiImage();
    if (picked.isNotEmpty) setState(() => _newImages.addAll(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUploading = true);

    String finalCustomer = _isManualCustomer ? _manualCustomerCtrl.text : _customerName;
    if (finalCustomer.isEmpty) finalCustomer = "Unknown";

    List<String> finalImageUrls = [..._existingImages];
    for (var img in _newImages) {
      final ref = FirebaseStorage.instance.ref().child('forex_receipts/${DateTime.now().millisecondsSinceEpoch}_${img.name}');
      if (kIsWeb) {
        await ref.putData(await img.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(img.path));
      }
      finalImageUrls.add(await ref.getDownloadURL());
    }

    // UPDATED SCHEMA FOR MULTI-CURRENCY SUPPORT
    final data = {
      'txn_type': _txnType,
      'date': widget.existingDoc?['date'] ?? Timestamp.now(),
      'customer_name': finalCustomer,
      'target_currency': _targetCurrency,
      'base_currency': _baseCurrency,   // NEW FIELD
      'amount_foreign': double.parse(_amountForeignCtrl.text),
      'buy_rate': double.parse(_buyRateCtrl.text),
      'sell_rate': double.parse(_sellRateCtrl.text),
      'profit_amount': _profit,         // NEW FIELD (Generic)
      'profit_idr': _baseCurrency == 'IDR' ? _profit : 0, // Legacy support
      'receipts': finalImageUrls,
    };

    if (widget.existingDoc != null) {
      await FirebaseFirestore.instance.collection('currency').doc(widget.existingDoc!.id).update(data);
    } else {
      await FirebaseFirestore.instance.collection('currency').add(data);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final baseFmt = NumberFormat.simpleCurrency(name: '$_baseCurrency ', decimalDigits: 0);
    final bool isSell = _txnType == 'SELL';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  const Text("Forex Transaction", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ]),
                const Divider(height: 24),

                // 1. Transaction Type Toggle
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Expanded(
                        child: _typeButton("Client Buys $_targetCurrency", "We Sell", isSell, () => setState(() => _txnType = 'SELL')),
                      ),
                      Expanded(
                        child: _typeButton("Client Sells $_targetCurrency", "We Buy", !isSell, () => setState(() => _txnType = 'BUY')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Customer
                Row(
                  children: [
                    Expanded(
                      child: _isManualCustomer 
                        ? TextFormField(controller: _manualCustomerCtrl, decoration: const InputDecoration(labelText: "Customer Name", border: OutlineInputBorder()))
                        : DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: "Select Customer", border: OutlineInputBorder()),
                            items: _customerList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setState(() => _customerName = v!),
                          ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _isManualCustomer = !_isManualCustomer),
                      child: Text(_isManualCustomer ? "Select List" : "Manual Input"),
                    )
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Currencies (Base & Target)
                Row(
                  children: [
                     Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _targetCurrency,
                        decoration: const InputDecoration(labelText: "Traded Currency", border: OutlineInputBorder()),
                        items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _targetCurrency = v!),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.swap_horiz, color: Colors.grey),
                    ),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _baseCurrency,
                        decoration: const InputDecoration(labelText: "Base Currency (Payment)", border: OutlineInputBorder()),
                        items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _baseCurrency = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Amount
                _input(_amountForeignCtrl, "Amount ($_targetCurrency)", icon: Icons.money),
                const SizedBox(height: 16),

                // 5. Rates (Base per Target)
                Row(
                  children: [
                    Expanded(
                      child: _input(
                        _buyRateCtrl, 
                        isSell ? "Cost / Supplier Rate" : "Rate to Customer (We Pay)", 
                        icon: Icons.arrow_downward, 
                        color: Colors.red
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _input(
                        _sellRateCtrl, 
                        isSell ? "Rate to Customer (We Receive)" : "Market / Liquidation Rate", 
                        icon: Icons.arrow_upward, 
                        color: Colors.green
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 6. Calculations
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: isSell ? Colors.blue.shade50 : Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      _calcRow("Total $_baseCurrency with Client:", baseFmt.format(_totalBase_Client), isBold: true),
                      _calcRow("Total $_baseCurrency Base/Market:", baseFmt.format(_totalBase_Market)),
                      const Divider(),
                      _calcRow("Net Profit", baseFmt.format(_profit), isBold: true, color: _profit >= 0 ? Colors.green : Colors.red),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 7. Receipts
                const Text("Payment Receipts", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    InkWell(
                      onTap: _pickImages,
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                        child: const Icon(Icons.add_a_photo, color: Colors.grey),
                      ),
                    ),
                    ..._existingImages.map((url) => Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, width: 70, height: 70, fit: BoxFit.cover)), Positioned(right: 0, top: 0, child: InkWell(onTap: () => setState(() => _existingImages.remove(url)), child: const Icon(Icons.cancel, size: 16, color: Colors.red)))])),
                    ..._newImages.map((file) => Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(file.path, width: 70, height: 70, fit: BoxFit.cover)), Positioned(right: 0, top: 0, child: InkWell(onTap: () => setState(() => _newImages.remove(file)), child: const Icon(Icons.cancel, size: 16, color: Colors.red)))])),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _save,
                    child: _isUploading ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Transaction"),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeButton(String title, String subtitle, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.grey)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black54 : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String label, {IconData? icon, Color? color}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color, fontSize: 13),
        prefixIcon: icon != null ? Icon(icon, size: 16, color: color) : null,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: (v) => v!.isEmpty ? "Req" : null,
    );
  }

  Widget _calcRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isBold ? 16 : 14, color: color ?? Colors.black87)),
        ],
      ),
    );
  }
}