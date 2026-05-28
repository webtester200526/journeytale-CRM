import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/pdfEditor/ticket_editor.dart';
import 'package:crmx/service_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Import your models and PDF editor



class OrderTicketManager extends StatelessWidget {
  final String orderId;
  final OrderModel orderModel;

  const OrderTicketManager({
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
            const Text("Attraction Tickets", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TicketPdfEditorPage(
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
                  onPressed: () => _showTicketDialog(context, null),
                  icon: const Icon(Icons.confirmation_number_outlined, size: 16),
                  label: const Text("Add Ticket"),
                 
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
              .collection('tickets')
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
                return _TicketCard(
                  data: docs[index].data() as Map<String, dynamic>,
                  onEdit: () => _showTicketDialog(context, docs[index]),
                  onDelete: () => _deleteTicket(docs[index].id),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _deleteTicket(String id) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).collection('tickets').doc(id).delete();
  }

  void _showTicketDialog(BuildContext context, DocumentSnapshot? doc) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _TicketEditorDialog(
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
          Icon(Icons.local_activity_outlined, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text("No tickets added yet.", style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TicketCard({required this.data, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    // DATE RANGE LOGIC
    final start = (data['start_date'] as Timestamp?)?.toDate() ?? (data['date'] as Timestamp?)?.toDate();
    final end = (data['end_date'] as Timestamp?)?.toDate() ?? start;
    
    // Formatting for display
    String dateString;
    String dayDisplay;
    String monthDisplay;

    if (start != null) {
      dayDisplay = DateFormat('dd').format(start);
      monthDisplay = DateFormat('MMM').format(start);
      
      if (end != null && !isSameDay(start, end)) {
        dateString = "${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(end)}";
      } else {
        dateString = DateFormat('dd MMM yyyy').format(start);
      }
    } else {
      dateString = "No Date";
      dayDisplay = "--";
      monthDisplay = "---";
    }
    
    // Currency Logic
    final String currencyCode = data['currency'] ?? 'RMB';
    final currency = NumberFormat.simpleCurrency(name: currencyCode, decimalDigits: 0);
    
    // Financials
    final clientTotal = (data['total_price'] as num?)?.toDouble() ?? 0.0;
    final internalTotal = (data['total_cost'] as num?)?.toDouble() ?? 0.0;
    final profit = clientTotal - internalTotal;

    final qtys = data['quantities'] as Map<String, dynamic>? ?? {};
    final summaryList = <String>[];
    qtys.forEach((key, val) {
      if ((val as num) > 0) summaryList.add("$val $key");
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Text(dayDisplay, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                Text(monthDisplay.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['spot_name'] ?? 'Attraction', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(dateString, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87)),
                Text("${data['city_name'] ?? ''} • ${summaryList.join(", ")}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(currency.format(clientTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text("Cost: ${currency.format(internalTotal)}", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              Text("Profit: ${currency.format(profit)}", style: TextStyle(color: profit >= 0 ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, size: 16, color: Colors.grey), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              const SizedBox(height: 8),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ],
          )
        ],
      ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// --- EDITOR DIALOG ---

class _TicketEditorDialog extends StatefulWidget {
  final String orderId;
  final DocumentSnapshot? existingDoc;
  final DateTime defaultDate;

  const _TicketEditorDialog({required this.orderId, this.existingDoc, required this.defaultDate});

  @override
  State<_TicketEditorDialog> createState() => _TicketEditorDialogState();
}

class _TicketEditorDialogState extends State<_TicketEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late DateTimeRange _selectedDateRange;
  String? _selectedCityId;
  String? _selectedCityName;
  
  final _spotNameCtrl = TextEditingController();
  final _bookingRefCtrl = TextEditingController();
  
  // Input Controllers Map
  final _qtyCtrls = <String, TextEditingController>{};
  final _clientPriceCtrls = <String, TextEditingController>{};
  final _costCtrls = <String, TextEditingController>{};

  final List<String> _types = ['Adult', 'Child', 'Senior', 'Student'];

  double _totalClient = 0.0;
  double _totalCost = 0.0;
  bool _isSaving = false;
  
  // NEW: Currency State
  String _selectedCurrency = 'RMB';

  @override
  void initState() {
    super.initState();
    // Initialize Controllers
    for (var t in _types) {
      _qtyCtrls[t] = TextEditingController(text: '');
      _clientPriceCtrls[t] = TextEditingController(text: '');
      _costCtrls[t] = TextEditingController(text: '');
      
      _qtyCtrls[t]!.addListener(_calcTotal);
      _clientPriceCtrls[t]!.addListener(_calcTotal);
      _costCtrls[t]!.addListener(_calcTotal);
    }
    _initializeData();
  }

  void _initializeData() {
    final data = widget.existingDoc?.data() as Map<String, dynamic>?;
    
    // Date Range Initialization
    if (data != null) {
      final start = (data['start_date'] as Timestamp?)?.toDate() ?? (data['date'] as Timestamp?)?.toDate() ?? widget.defaultDate;
      final end = (data['end_date'] as Timestamp?)?.toDate() ?? start;
      _selectedDateRange = DateTimeRange(start: start, end: end);
    } else {
      _selectedDateRange = DateTimeRange(start: widget.defaultDate, end: widget.defaultDate);
    }

    _spotNameCtrl.text = data?['spot_name'] ?? '';
    _bookingRefCtrl.text = data?['booking_ref'] ?? '';
    _selectedCityId = data?['city_id'];
    _selectedCityName = data?['city_name'];
    _selectedCurrency = data?['currency'] ?? 'RMB';

    if (data != null) {
      final qtys = data['quantities'] as Map<String, dynamic>? ?? {};
      final prices = data['unit_prices'] as Map<String, dynamic>? ?? {}; // Client prices
      final costs = data['unit_costs'] as Map<String, dynamic>? ?? {};   // Internal prices

      for (var t in _types) {
        if(qtys.containsKey(t)) _qtyCtrls[t]!.text = qtys[t].toString();
        if(prices.containsKey(t)) _clientPriceCtrls[t]!.text = prices[t].toString();
        if(costs.containsKey(t)) _costCtrls[t]!.text = costs[t].toString();
      }
      _calcTotal();
    }
  }

  void _calcTotal() {
    double tempClient = 0;
    double tempCost = 0;
    
    for (var t in _types) {
      final qty = int.tryParse(_qtyCtrls[t]!.text) ?? 0;
      final price = double.tryParse(_clientPriceCtrls[t]!.text) ?? 0.0;
      final cost = double.tryParse(_costCtrls[t]!.text) ?? 0.0;
      
      tempClient += (qty * price);
      tempCost += (qty * cost);
    }

    if (mounted) setState(() {
      _totalClient = tempClient;
      _totalCost = tempCost;
    });
  }

  // Fetch prices from Spot Database
  Future<void> _fetchSpotPrice(String cityId, String spotId, String spotName) async {
    final doc = await FirebaseFirestore.instance
        .collection('destinations').doc(cityId)
        .collection('spots').doc(spotId)
        .get();
    
    if (doc.exists) {
      final data = doc.data()!;
      final prices = data['prices'] as Map<String, dynamic>? ?? {};
      final spotCurrency = data['currency'] as String? ?? 'RMB';
      
      _spotNameCtrl.text = spotName;
      setState(() {
        _selectedCurrency = spotCurrency; // Auto-set currency
        
        for (var t in _types) {
          if (prices.containsKey(t)) {
            _clientPriceCtrls[t]!.text = prices[t].toString();
            // Defaulting Cost to Price (Admin should manually adjust internal cost if different)
            _costCtrls[t]!.text = prices[t].toString(); 
          }
        }
      });
      _calcTotal();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final quantities = <String, int>{};
    final unitPrices = <String, double>{};
    final unitCosts = <String, double>{};

    for (var t in _types) {
      quantities[t] = int.tryParse(_qtyCtrls[t]!.text) ?? 0;
      unitPrices[t] = double.tryParse(_clientPriceCtrls[t]!.text) ?? 0.0;
      unitCosts[t] = double.tryParse(_costCtrls[t]!.text) ?? 0.0;
    }

    final data = {
      'date': Timestamp.fromDate(_selectedDateRange.start), // Kept for sorting compatibility
      'start_date': Timestamp.fromDate(_selectedDateRange.start),
      'end_date': Timestamp.fromDate(_selectedDateRange.end),
      'city_id': _selectedCityId,
      'city_name': _selectedCityName,
      'spot_name': _spotNameCtrl.text,
      'booking_ref': _bookingRefCtrl.text,
      'quantities': quantities,
      'unit_prices': unitPrices, // Client Rate
      'unit_costs': unitCosts,   // Internal Rate
      'total_price': _totalClient, // Total Revenue
      'total_cost': _totalCost,    // Total Expense
      'currency': _selectedCurrency, // Stored Currency
    };

    final ref = FirebaseFirestore.instance.collection('orders').doc(widget.orderId).collection('tickets');

    if (widget.existingDoc != null) {
      await ref.doc(widget.existingDoc!.id).update(data);
    } else {
      await ref.add(data);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = NumberFormat.simpleCurrency(name: _selectedCurrency).currencySymbol;
    
    // Format range string for display
    String dateRangeDisplay;
    if (_selectedDateRange.duration.inDays == 0) {
      dateRangeDisplay = DateFormat('dd MMM yyyy').format(_selectedDateRange.start);
    } else {
      dateRangeDisplay = "${DateFormat('dd MMM').format(_selectedDateRange.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange.end)}";
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 750, 
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Manage Ticket", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    
                    // CURRENCY SELECTOR
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCurrency,
                          items: [
                            'IDR', 'RMB', 'EUR', 'USD', 'SGD', 'MYR',
                            'JPY', 'CHF', 'KRW', 'TWD', 'HKD', 'MOP', 'AUD',
                          ].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                          onChanged: (val) => setState(() => _selectedCurrency = val!),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // 1. SELECTORS
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            initialDateRange: _selectedDateRange,
                            // --- START MODIFICATION ---
                            // This builder restricts the size, making it a compact modal
                            builder: (context, child) {
                              return Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 400.0, 
                                    maxHeight: 600.0
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            // --- END MODIFICATION ---
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDateRange = picked;
                            });
                          }
                        },
                        child: _readOnlyInput("Date Range", dateRangeDisplay, Icons.date_range),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('destinations').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const LinearProgressIndicator();
                          final cities = snapshot.data!.docs;
                          return DropdownButtonFormField<String>(
                            value: _selectedCityId,
                            decoration: _inputDecoration("City"),
                            items: cities.map((c) {
                              final d = c.data() as Map<String, dynamic>;
                              return DropdownMenuItem(
                                value: c.id, 
                                child: Text(d['name'] ?? 'Unknown'),
                                onTap: () => _selectedCityName = d['name'],
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedCityId = val),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. SPOT SELECTOR
                if (_selectedCityId != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('destinations').doc(_selectedCityId).collection('spots').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      return DropdownButtonFormField<String>(
                        decoration: _inputDecoration("Auto-Fill Attraction"),
                        hint: const Text("Choose from database..."),
                        items: snapshot.data!.docs.map((s) {
                          final d = s.data() as Map<String, dynamic>;
                          return DropdownMenuItem(value: s.id, child: Text(d['name']), onTap: () => _fetchSpotPrice(_selectedCityId!, s.id, d['name']));
                        }).toList(),
                        onChanged: (_) {},
                      );
                    },
                  ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _spotNameCtrl, decoration: _inputDecoration("Attraction Name"), validator: (v) => v!.isEmpty ? "Required" : null)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _bookingRefCtrl, decoration: _inputDecoration("Booking Ref"))),
                  ],
                ),

                const SizedBox(height: 24),
                
                // 3. PRICING TABLE HEADERS
                Row(
                  children: [
                    const SizedBox(width: 80, child: Text("Type", style: TextStyle(fontWeight: FontWeight.bold))),
                  
                    Expanded(child: Text("Internal Price ($currencySymbol)", style: const TextStyle(color: Colors.blue))),
                    const SizedBox(width: 10),
                    const Expanded(child: Text("Qty", style: TextStyle(color: Colors.grey))),
                    const SizedBox(width: 10),
                    Expanded(child: Text("Client Price ($currencySymbol)", style: const TextStyle(color: Colors.amber))),
                  ],
                ),
                const Divider(),

                // 4. PRICE ROWS
                ..._types.map((t) => _buildPriceRow(t)),

                const Divider(),
                
                // 5. TOTALS
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Total Revenue: $currencySymbol${_totalClient.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                        Text("Total Cost: $currencySymbol${_totalCost.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, color: Colors.amber)),
                        Text("Net Profit: $currencySymbol${(_totalClient - _totalCost).toStringAsFixed(0)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: (_totalClient - _totalCost) >= 0 ? Colors.green : Colors.red)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(),
                    child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Ticket"),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(type, style: const TextStyle(fontWeight: FontWeight.w600))),
          
          Expanded(child: _miniInput(_costCtrls[type]!, isPrice: true)),
          const SizedBox(width: 10),
          Expanded(child: _miniInput(_qtyCtrls[type]!)),
          const SizedBox(width: 10),
          Expanded(child: _miniInput(_clientPriceCtrls[type]!, isPrice: true)),
          
        ],
      ),
    );
  }

  Widget _miniInput(TextEditingController ctrl, {bool isPrice = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: isPrice ? TextAlign.right : TextAlign.center,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        filled: true, fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _readOnlyInput(String label, String value, IconData icon) {
    return InputDecorator(
      decoration: _inputDecoration(label).copyWith(prefixIcon: Icon(icon, size: 18)),
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}