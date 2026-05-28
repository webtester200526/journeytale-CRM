import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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


class HotelDetailsEditor extends StatefulWidget {
  final String orderId;
  final DateTime orderStartDate;
  final DateTime orderEndDate;

  const HotelDetailsEditor({
    super.key,
    required this.orderId,
    required this.orderStartDate,
    required this.orderEndDate,
  });

  @override
  State<HotelDetailsEditor> createState() => _HotelDetailsEditorState();
}

class _HotelDetailsEditorState extends State<HotelDetailsEditor> {
  bool _isExpanded = true;
  late DateTime _currentWeekStart;

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _normalizeDate(widget.orderStartDate);
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .collection('hotels')
          .orderBy('check_in')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        final bookedNights = _getBookedNights(docs);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CALENDAR HEADER ---
            _buildCalendarHeader(),
            _buildWeeklyStrip(bookedNights),
            
            const SizedBox(height: 24),
            const Divider(height: 1),

            // --- HEADER ---
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Hotel Bookings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        // Quick Add Button
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.black),
                          onPressed: () => _showHotelForm(context, null, null, docs),
                        ),
                        Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // --- LIST ---
            if (_isExpanded)
              Column(
                children: [
                  if (docs.isEmpty) 
                    _buildEmptyState(),
                  
                  ...docs.map((doc) => _HotelTile(
                    orderId: widget.orderId,
                    doc: doc,
                    onEdit: () => _showHotelForm(context, doc.id, doc.data() as Map<String, dynamic>, docs),
                  )),
                  
                  const SizedBox(height: 20),
                ],
              ),
          ],
        );
      },
    );
  }

  // --- HELPERS ---

  Set<DateTime> _getBookedNights(List<QueryDocumentSnapshot> docs) {
    final Set<DateTime> booked = {};
    for (var doc in docs) {
      final start = (doc['check_in'] as Timestamp).toDate();
      final nights = doc['nights'] as int;
      for (int i = 0; i < nights; i++) {
        booked.add(_normalizeDate(start.add(Duration(days: i))));
      }
    }
    return booked;
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Text("No hotels booked yet.", style: TextStyle(color: Colors.grey)),
    );
  }

  void _showHotelForm(BuildContext context, String? docId, Map<String, dynamic>? data, List<QueryDocumentSnapshot> existingDocs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _HotelForm(
        orderId: widget.orderId,
        docId: docId,
        initialData: data,
        orderStart: widget.orderStartDate,
        orderEnd: widget.orderEndDate,
        existingDocs: existingDocs,
      ),
    );
  }

  Widget _buildCalendarHeader() {
    final endOfWeek = _currentWeekStart.add(const Duration(days: 6));
    String text = "${DateFormat('MMM d').format(_currentWeekStart)} - ${DateFormat('d').format(endOfWeek)}";
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7)))),
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _currentWeekStart = _currentWeekStart.add(const Duration(days: 7)))),
      ],
    );
  }

  Widget _buildWeeklyStrip(Set<DateTime> bookedNights) {
    return Row(
      children: List.generate(7, (index) {
        final date = _currentWeekStart.add(Duration(days: index));
        final isBooked = bookedNights.contains(date);
        final isTrip = !date.isBefore(_normalizeDate(widget.orderStartDate)) && !date.isAfter(_normalizeDate(widget.orderEndDate).subtract(const Duration(days: 1)));
        
        Color bg = Colors.transparent;
        if (isTrip) bg = isBooked ? Colors.green.shade100 : Colors.red.shade50;
        
        return Expanded(
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Text(DateFormat('E').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(DateFormat('d').format(date), style: TextStyle(fontWeight: FontWeight.bold, color: isTrip ? Colors.black : Colors.grey)),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// -----------------------------------------------------------------------------
// HOTEL FORM (SMART EDITOR)
// -----------------------------------------------------------------------------

class _HotelForm extends StatefulWidget {
  final String orderId;
  final String? docId;
  final Map<String, dynamic>? initialData;
  final DateTime orderStart;
  final DateTime orderEnd;
  final List<QueryDocumentSnapshot> existingDocs;

  const _HotelForm({
    required this.orderId,
    this.docId,
    this.initialData,
    required this.orderStart,
    required this.orderEnd,
    required this.existingDocs,
  });

  @override
  State<_HotelForm> createState() => _HotelFormState();
}

class _HotelFormState extends State<_HotelForm> {
  final _nameCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _prefCtrl = TextEditingController();
  final _nightsCtrl = TextEditingController(text: "1");
  
  // Financials
  final _basePriceCtrl = TextEditingController(text: "0");
  final _markupCtrl = TextEditingController(text: "0");
  final _clientPriceCtrl = TextEditingController(text: "0");

  String _currency = 'RMB'; // Default
  String get _symbol => kCurrencies[_currency] ?? _currency;

  late DateTime _checkIn;
  
  // Visuals
  String? _hotelImageUrl;
  String? _roomImageUrl;
  String? _address;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final d = widget.initialData!;
      _nameCtrl.text = d['name'] ?? '';
      _roomCtrl.text = d['room_type'] ?? '';
      _prefCtrl.text = d['preferences'] ?? '';
      _nightsCtrl.text = (d['nights'] ?? 1).toString();
      _checkIn = (d['check_in'] as Timestamp).toDate();
      
      _basePriceCtrl.text = (d['base_price'] ?? 0).toString();
      _markupCtrl.text = (d['markup'] ?? 0).toString();
      _clientPriceCtrl.text = (d['client_price'] ?? 0).toString();

      _hotelImageUrl = d['hotel_image'];
      _roomImageUrl = d['room_image'];
      _address = d['address'];
      _currency = d['currency'] ?? 'RMB';
    } else {
      _checkIn = widget.orderStart;
    }
  }

  void _calculatePrice() {
    double base = double.tryParse(_basePriceCtrl.text) ?? 0;
    double markup = double.tryParse(_markupCtrl.text) ?? 0;
    int nights = int.tryParse(_nightsCtrl.text) ?? 1;
    
    // Logic: Base * Nights * Markup
    double totalBase = base * nights;
    double totalClient = totalBase * (1 + markup/100);

    setState(() {
      _clientPriceCtrl.text = totalClient.toStringAsFixed(0);
    });
  }

  void _openDbSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _HotelDbSelector(
          scrollController: scrollController,
          onSelected: (hData, rData) {
            setState(() {
              _nameCtrl.text = hData['name'];
              _address = hData['address'];
              _hotelImageUrl = hData['image_url'];

              _roomCtrl.text = rData['name'];
              _roomImageUrl = rData['image_url'];
              
              _basePriceCtrl.text = rData['price'].toString();
              _markupCtrl.text = rData['markup'].toString();
              
              _currency = rData['currency'] ?? 'RMB';

              _calculatePrice();
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() => _isSaving = true);
    
    final nights = int.tryParse(_nightsCtrl.text) ?? 1;
    final end = _checkIn.add(Duration(days: nights));

    final data = {
      'name': _nameCtrl.text,
      'address': _address,
      'room_type': _roomCtrl.text,
      'preferences': _prefCtrl.text,
      'nights': nights,
      'check_in': Timestamp.fromDate(_checkIn),
      'check_out_calculated': Timestamp.fromDate(end),
      
      'base_price': double.tryParse(_basePriceCtrl.text) ?? 0,
      'markup': double.tryParse(_markupCtrl.text) ?? 0,
      'client_price': double.tryParse(_clientPriceCtrl.text) ?? 0,
      'currency': _currency,

      'hotel_image': _hotelImageUrl,
      'room_image': _roomImageUrl,
    };

    final col = FirebaseFirestore.instance.collection('orders').doc(widget.orderId).collection('hotels');
    if (widget.docId != null) {
      await col.doc(widget.docId).update(data);
    } else {
      await col.add(data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Hotel Booking", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                OutlinedButton.icon(
                  onPressed: _openDbSelector,
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text("Select from DB"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Visual Card
            
            // Form
            _ModernInput(controller: _nameCtrl, label: "Hotel Name"),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(flex: 3, child: _ModernInput(controller: _roomCtrl, label: "Room Type")),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _ModernInput(controller: _nightsCtrl, label: "Nights", isNumber: true, onChanged: (_) => _calculatePrice())),
            ]),
            const SizedBox(height: 12),
            
            // Date Picker
            InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _checkIn, firstDate: widget.orderStart, lastDate: widget.orderEnd);
                if (d != null) setState(() => _checkIn = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Check-In Date", style: TextStyle(color: Colors.grey)),
                    Text(DateFormat('EEE, dd MMM yyyy').format(_checkIn), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Financials
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Pricing Structure", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                      Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade200)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currency,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.green),
                            items: kCurrencies.keys.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)))).toList(),
                            onChanged: (v) => setState(() => _currency = v!),
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _ModernInput(controller: _basePriceCtrl, label: "Base/Night ($_symbol)", isNumber: true, onChanged: (_) => _calculatePrice())),
                      const SizedBox(width: 12),
                      Expanded(child: _ModernInput(controller: _markupCtrl, label: "Markup %", isNumber: true, onChanged: (_) => _calculatePrice())),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total Client Price:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      Text("$_symbol${_clientPriceCtrl.text}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.green)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ModernInput(controller: _prefCtrl, label: "Preferences / Notes", maxLines: 2),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                //style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Booking", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// DATABASE SELECTOR
// -----------------------------------------------------------------------------

class _HotelDbSelector extends StatelessWidget {
  final ScrollController scrollController;
  final Function(Map<String, dynamic> hotel, Map<String, dynamic> room) onSelected;

  const _HotelDbSelector({required this.scrollController, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Container(height: 4, width: 40, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const Text("Select Hotel & Room", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('hotels_db').orderBy('city').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;
                // Group by City
                Map<String, List<DocumentSnapshot>> grouped = {};
                for (var d in docs) {
                  final city = d['city'] ?? 'Other';
                  if (!grouped.containsKey(city)) grouped[city] = [];
                  grouped[city]!.add(d);
                }

                return ListView.builder(
                  controller: scrollController,
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, index) {
                    final city = grouped.keys.elementAt(index);
                    final hotels = grouped[city]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(city.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1)),
                        ),
                        ...hotels.map((h) => _HotelSelectorItem(doc: h, onSelected: onSelected)),
                        const SizedBox(height: 12),
                      ],
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

class _HotelSelectorItem extends StatelessWidget {
  final DocumentSnapshot doc;
  final Function(Map<String, dynamic>, Map<String, dynamic>) onSelected;

  const _HotelSelectorItem({required this.doc, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final h = doc.data() as Map<String, dynamic>;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ExpansionTile(
        shape: const Border(),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: h['image_url'] != null && h['image_url'].isNotEmpty
              ? Image.network(h['image_url'], width: 48, height: 48, fit: BoxFit.cover)
              : Container(width: 48, height: 48, color: Colors.grey[100], child: const Icon(Icons.hotel, color: Colors.grey)),
        ),
        title: Text(h['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(h['address'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: doc.reference.collection('rooms').orderBy('price').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return Column(
                children: snapshot.data!.docs.map((r) {
                  final rd = r.data() as Map<String, dynamic>;
                  final cur = rd['currency'] ?? 'RMB';
                  final sym = kCurrencies[cur] ?? cur;

                  return ListTile(
                    contentPadding: const EdgeInsets.only(left: 20, right: 16),
                    tileColor: Colors.grey[50],
                    leading: const Icon(Icons.bed, size: 18),
                    title: Text(rd['name']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("$sym${rd['price']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        const Icon(Icons.add_circle, color: Colors.black, size: 20),
                      ],
                    ),
                    onTap: () => onSelected(h, rd),
                  );
                }).toList(),
              );
            },
          )
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LIST TILE (VIEW)
// -----------------------------------------------------------------------------

class _HotelTile extends StatelessWidget {
  final String orderId;
  final QueryDocumentSnapshot doc;
  final VoidCallback onEdit;

  const _HotelTile({required this.orderId, required this.doc, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final start = (data['check_in'] as Timestamp).toDate();
    final end = (data['check_out_calculated'] as Timestamp).toDate();
    final nights = data['nights'] ?? 1;
    final img = data['hotel_image'];
    final pref = data['preferences'];
    
    final currency = data['currency'] ?? 'RMB';
    final symbol = kCurrencies[currency] ?? currency;

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(alignment: Alignment.centerRight, color: Colors.red, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
      confirmDismiss: (_) => showDialog(context: context, builder: (c) => AlertDialog(
        title: const Text("Delete Booking?"), actions: [
          TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ])),
      onDismissed: (_) => FirebaseFirestore.instance.collection('orders').doc(orderId).collection('hotels').doc(doc.id).delete(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 70, height: 70,
                    color: Colors.grey[100],
                    child: (img != null && img.isNotEmpty) ? Image.network(img, fit: BoxFit.cover) : const Icon(Icons.hotel, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(data['room_type'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(pref, style: const TextStyle(color: Colors.redAccent, fontSize: 13,fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.blue[800]),
                          const SizedBox(width: 4),
                          Text("${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(end)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)), child: Text("$nights Nights", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                        ],
                      )
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("$symbol${data['client_price']}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.green)),
                    Text(currency, style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isNumber;
  final int maxLines;
  final Function(String)? onChanged;

  const _ModernInput({required this.controller, required this.label, this.isNumber = false, this.maxLines = 1, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      onChanged: onChanged,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))] : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
    );
  }
}