import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderMetaCard extends StatefulWidget {
  final String orderId;

  const OrderMetaCard({super.key, required this.orderId});

  @override
  State<OrderMetaCard> createState() => _OrderMetaCardState();
}

class _OrderMetaCardState extends State<OrderMetaCard> {
  // --- AUTOSAVE METHODS ---

  Future<void> _updateField(String field, dynamic value) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({field: value});
    } catch (e) {
      debugPrint("Autosave failed: $e");
    }
  }

  Future<void> _pickDateRange(DateTime start, DateTime end) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: start, end: end),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
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
      final int days = picked.end.difference(picked.start).inDays + 1;
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'startDate': Timestamp.fromDate(picked.start),
        'endDate': Timestamp.fromDate(picked.end),
        'durationDays': days,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
        
        final data = snapshot.data!.data() as Map<String, dynamic>;

        // 1. Parse Data
        final DateTime startDate = (data['startDate'] as Timestamp).toDate();
        final DateTime endDate = (data['endDate'] as Timestamp).toDate();
        // Calculate duration or use saved value
        final int durationDays = data['durationDays'] ?? (endDate.difference(startDate).inDays + 1);
        final String destination = data['destination'] ?? 'Unknown';
        
        // Handle Status naming differences (supports both snake_case and camelCase)
        final String tripStatus = data['trip_status'] ?? data['tripStatus'] ?? 'upcoming';
        
        // --- UPDATED PAYMENT STATUS LOGIC ---
        // Get raw value
        String rawPaymentStatus = data['payment_status'] ?? data['paymentStatus'] ?? 'unpaid';
        // Map 'pending' to 'DownPayment' for display/logic consistency
        if (rawPaymentStatus.toLowerCase() == 'pending') {
          rawPaymentStatus = 'DownPayment';
        }
        final String paymentStatus = rawPaymentStatus;
        
        // Handle Additional Destinations
        // We safely cast this to a List
        final List<dynamic> rawDestinations = data['additional_destinations'] ?? [];
        final List<String> additionalDestinations = rawDestinations.map((e) => e.toString()).toList();

        final dateStr = "${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}";

        // 2. Build UI (Exact match to original layout)
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
             boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- ROW 1: Destination & Duration ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Destination", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                      const SizedBox(height: 4),
                      Text(destination, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("$durationDays Days", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // --- ROW 2: Date Picker ---
              InkWell(
                onTap: () => _pickDateRange(startDate, endDate),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                    const SizedBox(width: 8),
                    Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    const Icon(Icons.edit, size: 14, color: Colors.grey),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- ROW 3: Status Dropdowns ---
              Row(
                children: [
                  Expanded(
                    child: _buildStatusDropdown(
                      label: "Payment",
                      value: paymentStatus,
                      // Ensure 'DownPayment' is in the list, removed 'pending'
                      items: ['unpaid', 'DownPayment', 'paid', 'refunded'], 
                      onChanged: (val) {
                        // If user selects DownPayment, we save it as such. 
                        // If your backend *requires* 'pending', change the value passed to _updateField here.
                        _updateField('payment_status', val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatusDropdown(
                      label: "Trip Status",
                      value: tripStatus,
                      items: ['upcoming', 'ongoing', 'completed', 'cancelled'],
                      onChanged: (val) => _updateField('trip_status', val),
                    ),
                  ),
                ],
              ),
              
              // --- ROW 4: Additional Destinations (Exact same logic as original) ---
              if (additionalDestinations.isNotEmpty) ...[
                const SizedBox(height: 16),
                 Text("Visiting Also", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                const SizedBox(height: 4),
                Text(
                  additionalDestinations.join(', '),
                  style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.bold),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusDropdown({
    required String label, 
    required String value, 
    required List<String> items, 
    required Function(String) onChanged
  }) {
    // Safety check: if the database has a value not in our list (e.g. legacy 'pending' wasn't caught), default to first item
    String safeValue = items.contains(value) ? value : items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300)
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, size: 18, color: Colors.black54),
              items: items.map((s) => DropdownMenuItem(
                value: s, 
                child: Text(
                  s.toUpperCase(), 
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)
                )
              )).toList(),
              onChanged: (val) {
                if(val != null) onChanged(val);
              },
            ),
          ),
        ),
      ],
    );
  }
}