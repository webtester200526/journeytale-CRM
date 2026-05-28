import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ==========================================
// 1. FLIGHT DETAILS EDITOR (FULL CODE)
// ==========================================

class FlightDetailsEditor extends StatefulWidget {
  final String orderId;
  const FlightDetailsEditor({super.key, required this.orderId});

  @override
  State<FlightDetailsEditor> createState() => _FlightDetailsEditorState();
}

class _FlightDetailsEditorState extends State<FlightDetailsEditor> {
  bool _isExpanded = true;
  List<String> _availableCities = [];

  @override
  void initState() {
    super.initState();
    _fetchCities();
  }

  Future<void> _fetchCities() async {
    final snap = await FirebaseFirestore.instance.collection('destinations').orderBy('name').get();
    if(mounted) setState(() => _availableCities = snap.docs.map((doc) => doc['name'] as String).toList());
  }

   Future<void> _addFlight() async {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .collection('flights')
          .add({
        'flight_number': '',
        'departure_city': 'none',
        'arrival_city': 'none',
        'departure_airport': '', 
        'arrival_airport': '',   
        'departure_time': null, 
        'arrival_time': null,
        
        // Pricing Fields
        'internal_price': 0.0,
        'markup': 0.0,
        'client_price': 0.0,
        'currency': 'RMB', // Default Currency
        
        'signboard': '',
        'pickup_time': '',
        'transfer_note': '',
        'created_at': FieldValue.serverTimestamp(),
      });
      if(mounted) setState(() => _isExpanded = true);
    }

  @override
  Widget build(BuildContext context) {
    return _BaseEditorContainer(
      isExpanded: _isExpanded,
      onExpandToggle: () => setState(() => _isExpanded = !_isExpanded),
      onAddPressed: _addFlight,
      addButtonLabel: "Add Flight",
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).collection('flights').orderBy('departure_time').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const _EmptyPlaceholder(text: "No flights added.");
          
          return ListView.separated(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 20),
            itemBuilder: (context, index) => _FlightRowEditor(key: ValueKey(docs[index].id), docId: docs[index].id, data: docs[index].data() as Map<String, dynamic>, orderId: widget.orderId, availableCities: _availableCities),
          );
        },
      ),
    );
  }
}

class _FlightRowEditor extends StatefulWidget {
  final String orderId, docId;
  final Map<String, dynamic> data;
  final List<String> availableCities;
  const _FlightRowEditor({super.key, required this.orderId, required this.docId, required this.data, required this.availableCities});

  @override
  State<_FlightRowEditor> createState() => _FlightRowEditorState();
}

class _FlightRowEditorState extends State<_FlightRowEditor> {
  // Flight Controllers
  final _flightNoCtrl = TextEditingController();
  
  // Pricing Controllers
  final _internalPriceCtrl = TextEditingController();
  final _markupCtrl = TextEditingController();

  // Transfer Controllers
  final _signBoardCtrl = TextEditingController();
  final _pickupTimeCtrl = TextEditingController();
  final _transferNoteCtrl = TextEditingController();

  Timer? _debounce;
  DateTime? _depTime, _arrTime;
  String? _depCity, _arrCity;
  
  // Local state for calculation display
  double _clientPrice = 0.0;
  String _selectedCurrency = 'RMB'; // Default
  
  bool _showTransferDetails = false;

  @override
  void initState() {
    super.initState();
    _flightNoCtrl.text = widget.data['flight_number'] ?? '';
    _signBoardCtrl.text = widget.data['signboard'] ?? '';
    _pickupTimeCtrl.text = widget.data['pickup_time'] ?? '';
    _transferNoteCtrl.text = widget.data['transfer_note'] ?? '';

    // Initialize Pricing
    double internal = (widget.data['internal_price'] ?? 0).toDouble();
    double markup = (widget.data['markup'] ?? 0).toDouble();
    _clientPrice = (widget.data['client_price'] ?? 0).toDouble();
    _selectedCurrency = widget.data['currency'] ?? 'RMB';
    
    // Set text controls
    _internalPriceCtrl.text = internal == 0 ? '' : internal.toStringAsFixed(2);
    _markupCtrl.text = markup == 0 ? '' : markup.toStringAsFixed(2);

    if (widget.data['departure_time'] != null) _depTime = (widget.data['departure_time'] as Timestamp).toDate();
    if (widget.data['arrival_time'] != null) _arrTime = (widget.data['arrival_time'] as Timestamp).toDate();
    _depCity = widget.data['departure_city'];
    _arrCity = widget.data['arrival_city'];
    
    if (_signBoardCtrl.text.isNotEmpty || _pickupTimeCtrl.text.isNotEmpty) _showTransferDetails = true;
  }

  void _updateField(Map<String, dynamic> updates) {
    FirebaseFirestore.instance.collection('orders').doc(widget.orderId).collection('flights').doc(widget.docId).update(updates);
  }

  void _onTextChanged(String field, String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () => _updateField({field: val}));
  }

  // UPDATED: Calculates Client Price = Internal * (1 + Markup%)
  void _onPriceChanged() {
    double internal = double.tryParse(_internalPriceCtrl.text) ?? 0.0;
    double markupPercent = double.tryParse(_markupCtrl.text) ?? 0.0;
    
    // Calculation: Internal Cost * (1 + Percentage/100)
    double newClientPrice = internal * (1 + (markupPercent / 100));

    // Update UI immediately
    setState(() {
      _clientPrice = newClientPrice;
    });

    // Save to Firestore with debounce
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _updateField({
        'internal_price': internal,
        'markup': markupPercent,
        'client_price': newClientPrice,
      });
    });
  }

  void _onCurrencyChanged(String? val) {
    if (val != null) {
      setState(() => _selectedCurrency = val);
      _updateField({'currency': val});
    }
  }

  Future<void> _pickDateTime(bool isDep) async {
    final initial = (isDep ? _depTime : _arrTime) ?? DateTime.now();
    final date = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    initialEntryMode: TimePickerEntryMode.input,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          alwaysUse24HourFormat: true,
        ),
        child: child!,
      );
    },
  );

    if (time == null) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => isDep ? _depTime = combined : _arrTime = combined);
    _updateField({isDep ? 'departure_time' : 'arrival_time': Timestamp.fromDate(combined)});
  }

  String _getCurrencySymbol(String code) {
    final format = NumberFormat.simpleCurrency(name: code);
    return format.currencySymbol;
  }

  @override
  Widget build(BuildContext context) {
    return _RowContainer(
      onDelete: () => FirebaseFirestore.instance.collection('orders').doc(widget.orderId).collection('flights').doc(widget.docId).delete(),
      child: Column(
        children: [
          // 1. Basic Flight Info
          Row(children: [
            Expanded(child: _DropdownField(label: "From", value: _depCity, items: widget.availableCities, onChanged: (v) { setState(() => _depCity = v); _updateField({'departure_city': v}); })),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey)),
            Expanded(child: _DropdownField(label: "To", value: _arrCity, items: widget.availableCities, onChanged: (v) { setState(() => _arrCity = v); _updateField({'arrival_city': v}); })),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(flex: 2, child: _TextFieldInput(controller: _flightNoCtrl, label: "Flight No.", icon: Icons.tag, onChanged: (v) => _onTextChanged('flight_number', v))),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: _DateTimeInput(label: "Departure", time: _depTime, onTap: () => _pickDateTime(true))),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: _DateTimeInput(label: "Arrival", time: _arrTime, onTap: () => _pickDateTime(false))),
          ]),
          
          const SizedBox(height: 12),
          
          // 2. Pricing Section (Green Box - UPDATED)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Flight Pricing", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _TextFieldInput(
                        controller: _internalPriceCtrl, 
                        label: "Internal Price", 
                        icon: Icons.currency_yuan, 
                        isNumber: true,
                        onChanged: (v) => _onPriceChanged(),
                      ),
                    ),
                    // Visual separator: Internal + (Mark%) -> Client
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                      child: Text("+", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      flex: 2,
                      child: _TextFieldInput(
                        controller: _markupCtrl, 
                        label: "Markup (%)", // Changed Label
                        icon: Icons.percent, // Changed Icon
                        isNumber: true,
                        onChanged: (v) => _onPriceChanged(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Currency Dropdown
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCurrency,
                            isExpanded: true,
                            items: [
                              'IDR', 'RMB', 'EUR', 'USD', 'SGD', 'MYR',
                              'JPY', 'CHF', 'KRW', 'TWD', 'HKD', 'MOP', 'AUD',
                            ].map((c) => 
                              DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))
                            ).toList(),
                            onChanged: _onCurrencyChanged,
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                      child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Client Price", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text("${_getCurrencySymbol(_selectedCurrency)}${_clientPrice.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Transfer Detail Toggle
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _showTransferDetails = !_showTransferDetails),
            child: Row(
              children: [
                Icon(_showTransferDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(_showTransferDetails ? "Hide Additional Details" : "Show Additional Details (Signboard, Pickup)", style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // 4. Transfer Details Section
          if (_showTransferDetails) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Additional info", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _TextFieldInput(controller: _signBoardCtrl, label: "Sign Board Name", icon: Icons.person_pin, onChanged: (v) => _onTextChanged('signboard', v))),
                    const SizedBox(width: 12),
                    Expanded(child: _TextFieldInput(controller: _pickupTimeCtrl, label: "Pickup Time", icon: Icons.access_time, onChanged: (v) => _onTextChanged('pickup_time', v))),
                  ]),
                  const SizedBox(height: 8),
                  _TextFieldInput(controller: _transferNoteCtrl, label: "Driver Notes / Meeting Point", icon: Icons.note, onChanged: (v) => _onTextChanged('transfer_note', v)),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }
}

// ==========================================
// SHARED UI HELPERS
// ==========================================

class _BaseEditorContainer extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onExpandToggle;
  final VoidCallback onAddPressed;
  final String addButtonLabel;
  final Widget child;

  const _BaseEditorContainer({
    required this.isExpanded, required this.onExpandToggle,
    required this.onAddPressed, required this.addButtonLabel, required this.child
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          if (isExpanded) ...[
            child,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: OutlinedButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add, size: 16),
                label: Text(addButtonLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.transparent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class _RowContainer extends StatelessWidget {
  final Widget child;
  final VoidCallback onDelete;
  const _RowContainer({required this.child, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: child,
        ),
        Positioned(
          top: 4, right: 4,
          child: IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.grey), onPressed: onDelete),
        )
      ],
    );
  }
}

class _TextFieldInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final bool isNumber;

  const _TextFieldInput({
    required this.controller, 
    required this.label, 
    required this.icon, 
    required this.onChanged,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13),
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: isNumber ? [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ] : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 16, color: Colors.grey),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: items.contains(value) ? value : null,
              hint: const Text("Select", style: TextStyle(fontSize: 13, color: Colors.grey)),
              items: items.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateTimeInput extends StatelessWidget {
  final String label;
  final DateTime? time;
  final VoidCallback onTap;

  const _DateTimeInput({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.blue[800]),
              const SizedBox(width: 4),
              Expanded(child: Text(time != null ? DateFormat('dd MMM yyyy, HH:mm').format(time!) : "--", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final String text;
  final IconData? icon;
  const _EmptyPlaceholder({required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        Icon(icon ?? Icons.flight, size: 40, color: Colors.grey[300]),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(color: Colors.grey)),
      ]),
    );
  }
}