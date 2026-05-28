import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/pdfEditor/orderFinances_editor.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FinancialReportSection extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const FinancialReportSection({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').doc(orderId).collection('services').snapshots(),
      builder: (context, serviceSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('orders').doc(orderId).collection('transport').snapshots(),
          builder: (context, transportSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('orders').doc(orderId).collection('tickets').snapshots(),
              builder: (context, ticketSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('orders').doc(orderId).collection('flights').snapshots(),
                  builder: (context, flightSnap) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('orders').doc(orderId).collection('trains').snapshots(),
                      builder: (context, trainSnap) {
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('orders').doc(orderId).collection('tourguides').snapshots(),
                          builder: (context, guideSnap) {
                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('orders').doc(orderId).collection('additional').snapshots(),
                              builder: (context, feeSnap) {
                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance.collection('orders').doc(orderId).collection('hotels').snapshots(),
                                  builder: (context, hotelSnap) {
                                    
                                    // Check if all streams have data
                                    if (!serviceSnap.hasData || !transportSnap.hasData || 
                                        !ticketSnap.hasData || !flightSnap.hasData || 
                                        !trainSnap.hasData || !guideSnap.hasData || 
                                        !feeSnap.hasData || !hotelSnap.hasData) {
                                      return Container(
                                        height: 200,
                                        decoration: _cardDecoration(),
                                        child: const Center(child: CircularProgressIndicator(color: Colors.black)),
                                      );
                                    }

                                    // --- 1. AGGREGATION LOGIC (Per Currency) ---
                                    // Map<CurrencyCode, _CurrencyStats>
                                    final Map<String, _CurrencyStats> totals = {};
                                    final List<Widget> rows = [];

                                    void addToTotals(String currency, double revenue, double cost) {
                                      // Normalize RMB -> RMB
                                      String code = (currency == 'RMB') ? 'RMB' : currency.toUpperCase();
                                      if (code.isEmpty) code = 'RMB';

                                      if (!totals.containsKey(code)) {
                                        totals[code] = _CurrencyStats();
                                      }
                                      totals[code]!.revenue += revenue;
                                      totals[code]!.cost += cost;
                                    }

                                    void processItem({
                                      required String label,
                                      required String subLabel,
                                      required double cost,
                                      required double price,
                                      required String currency,
                                      VoidCallback? onDelete
                                    }) {
                                      addToTotals(currency, price, cost);
                                      rows.add(_buildRow(
                                        label: label,
                                        subLabel: subLabel,
                                        cost: cost,
                                        price: price,
                                        currency: currency,
                                        onDelete: onDelete
                                      ));
                                    }

                                    // --- PROCESSING COLLECTIONS ---

                                    // A. Services
                                    if (serviceSnap.data!.docs.isNotEmpty) {
                                      rows.add(_buildSectionHeader("Services"));
                                      for (var doc in serviceSnap.data!.docs) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        final p = (data['price_per_day'] as num?)?.toDouble() ?? 0;
                                        final c = (data['modal_per_day'] as num?)?.toDouble() ?? 0;
                                        final d = (data['days'] as num?)?.toInt() ?? 1;
                                        final disc = (data['discount'] as num?)?.toDouble() ?? 0;
                                        processItem(
                                          label: data['name'] ?? 'Service', subLabel: "$d days",
                                          cost: c * d, price: (p * d) - disc, currency: data['currency'] ?? 'RMB'
                                        );
                                      }
                                    }

                                    // B. Transport
                                    if (transportSnap.data!.docs.isNotEmpty) {
                                      rows.add(_buildSectionHeader("Transport"));
                                      for (var doc in transportSnap.data!.docs) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        processItem(
                                          label: data['route_title'] ?? 'Transport', subLabel: data['vehicle'] ?? '',
                                          cost: (data['cost'] as num?)?.toDouble() ?? 0,
                                          price: (data['fee'] as num?)?.toDouble() ?? 0,
                                          currency: data['currency'] ?? 'RMB'
                                        );
                                      }
                                    }

                                    // C. Hotels
                                    if (hotelSnap.data!.docs.isNotEmpty) {
                                      rows.add(_buildSectionHeader("Hotels"));
                                      for (var doc in hotelSnap.data!.docs) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        double base = (data['base_price'] as num?)?.toDouble() ?? 0;
                                        int nights = (data['nights'] as num?)?.toInt() ?? 1;
                                        processItem(
                                          label: data['name'] ?? 'Hotel', subLabel: "${data['room_type']} ($nights nights)",
                                          cost: base * nights, price: (data['client_price'] as num?)?.toDouble() ?? 0,
                                          currency: data['currency'] ?? 'RMB'
                                        );
                                      }
                                    }

                                    // D. Flights & Trains
                                    if (flightSnap.data!.docs.isNotEmpty) {
                                      rows.add(_buildSectionHeader("Flights"));
                                      for (var doc in flightSnap.data!.docs) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        processItem(
                                          label: "Flight ${data['flight_number'] ?? ''}", subLabel: "${data['departure_city']} > ${data['arrival_city']}",
                                          cost: (data['internal_price'] as num?)?.toDouble() ?? 0, price: (data['client_price'] as num?)?.toDouble() ?? 0,
                                          currency: data['currency'] ?? 'RMB'
                                        );
                                      }
                                    }
                                    if (trainSnap.data!.docs.isNotEmpty) {
                                      rows.add(_buildSectionHeader("Trains"));
                                      for (var doc in trainSnap.data!.docs) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        processItem(
                                          label: "Train ${data['train_number'] ?? ''}", subLabel: "${data['departure_city']} > ${data['arrival_city']}",
                                          cost: (data['internal_price'] as num?)?.toDouble() ?? 0, price: (data['client_price'] as num?)?.toDouble() ?? 0,
                                          currency: data['currency'] ?? 'RMB'
                                        );
                                      }
                                    }

                                    // E. Tickets & Guides
                                    if (ticketSnap.data!.docs.isNotEmpty) {
                                      rows.add(_buildSectionHeader("Tickets"));
                                      for (var doc in ticketSnap.data!.docs) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        processItem(
                                          label: data['spot_name'] ?? 'Ticket', subLabel: "Entry Fee",
                                          cost: (data['total_cost'] as num?)?.toDouble() ?? 0, price: (data['total_price'] as num?)?.toDouble() ?? 0,
                                          currency: data['currency'] ?? 'RMB'
                                        );
                                      }
                                    }
                                    if (guideSnap.data!.docs.isNotEmpty) {
                                      rows.add(_buildSectionHeader("Tour Guides"));
                                      for (var doc in guideSnap.data!.docs) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        double r = (data['client_price'] as num?)?.toDouble() ?? 0;
                                        double c = (data['internal_price'] as num?)?.toDouble() ?? 0;
                                        if (c == 0 && data['fee_per_day'] != null) {
                                           double daily = (data['fee_per_day'] as num?)?.toDouble() ?? 0;
                                           double ot = (data['ot_fee'] as num?)?.toDouble() ?? 0;
                                           double otHours = (data['total_ot_hours'] as num?)?.toDouble() ?? 0;
                                           int days = 1;
                                           if (data['start_date'] != null && data['end_date'] != null) {
                                              final s = (data['start_date'] as Timestamp).toDate();
                                              final e = (data['end_date'] as Timestamp).toDate();
                                              days = e.difference(s).inDays + 1;
                                           }
                                           c = (daily * days) + (ot * otHours);
                                           if (r == 0) r = c; 
                                        }
                                        processItem(
                                          label: data['name'] ?? 'Guide', subLabel: data['area'] ?? 'Guide Service',
                                          cost: c, price: r, currency: data['currency'] ?? 'RMB'
                                        );
                                      }
                                    }

                                    // F. Additional
                                    rows.add(_buildSectionHeader("Additional Items"));
                                    for (var doc in feeSnap.data!.docs) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      processItem(
                                        label: data['description'] ?? 'Fee', subLabel: data['note'] ?? 'Manual Entry',
                                        cost: (data['cost'] as num?)?.toDouble() ?? 0, price: (data['amount'] as num?)?.toDouble() ?? 0,
                                        currency: data['currency'] ?? 'RMB',
                                        onDelete: () => _deleteFee(doc.id),
                                      );
                                    }

                                    // Add Button
                                    rows.add(Padding(padding: const EdgeInsets.only(top: 12.0), child: InkWell(onTap: () => _showAddFeeDialog(context), child: DottedContainer(child: const Center(child: Text("+ Add Adjustment / Fee", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))))));

                                    // --- 2. UI RENDER ---
                                    return Container(
                                      padding: const EdgeInsets.all(32),
                                      decoration: _cardDecoration(),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // HEADER
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("Financial Breakdown", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                                                  SizedBox(height: 4),
                                                  Text("Revenue, Expenses & Profit per Currency", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                                ],
                                              ),
                                            ],
                                          ),
                                           const SizedBox(height: 10),
                                           ElevatedButton.icon(
                                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InternalReportPdfEditor(orderId: orderId))),
                                            icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                                            label: const Text('PDF Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), shape: const StadiumBorder(), elevation: 0),
                                          ),

                                          const SizedBox(height: 32),

                                          // ITEM LIST
                                          Row(
                                            children: [
                                              Expanded(flex: 4, child: Text("ITEM", style: _headerStyle())),
                                              Expanded(flex: 2, child: Text("COST", style: _headerStyle(), textAlign: TextAlign.right)),
                                              Expanded(flex: 2, child: Text("PRICE", style: _headerStyle(), textAlign: TextAlign.right)),
                                            ],
                                          ),
                                          const Divider(height: 24),
                                          ...rows,
                                          
                                          const SizedBox(height: 32),
                                          const Divider(thickness: 1, color: Colors.black),
                                          const SizedBox(height: 16),
                                          
                                          // TOTALS SUMMARY GRID
                                          const Text("CURRENCY TOTALS", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12, color: Colors.black54)),
                                          const SizedBox(height: 12),
                                          
                                          if (totals.isEmpty)
                                            const Text("No financial data available", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
                                          else
                                            Wrap(
                                              spacing: 16,
                                              runSpacing: 16,
                                              children: totals.entries.map((e) => _CurrencySummaryCard(
                                                currency: e.key,
                                                revenue: e.value.revenue,
                                                cost: e.value.cost,
                                              )).toList(),
                                            )
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // --- ACTIONS ---

  Future<void> _deleteFee(String docId) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).collection('additional').doc(docId).delete();
  }

  void _showAddFeeDialog(BuildContext context) {
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedCurrency = 'RMB'; 

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Add Additional Fee"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description (e.g. Visa Fee)")),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Client Price"), keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: costCtrl, decoration: const InputDecoration(labelText: "Internal Price"), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedCurrency,
                  decoration: const InputDecoration(labelText: "Currency"),
                  items: [
                      'IDR', 'RMB', 'EUR', 'USD', 'SGD', 'MYR',
                      'JPY', 'CHF', 'KRW', 'TWD', 'HKD', 'MOP', 'AUD',
                    ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => selectedCurrency = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: "Note (Optional)")),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  if (descCtrl.text.isEmpty) return;
                  await FirebaseFirestore.instance.collection('orders').doc(orderId).collection('additional').add({
                    'description': descCtrl.text,
                    'amount': double.tryParse(priceCtrl.text) ?? 0.0,
                    'cost': double.tryParse(costCtrl.text) ?? 0.0,
                    'currency': selectedCurrency,
                    'note': noteCtrl.text,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text("Add"),
              )
            ],
          );
        }
      ),
    );
  }

  // --- STYLING & WIDGETS ---

  BoxDecoration _cardDecoration() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]);
  TextStyle _headerStyle() => TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w700, letterSpacing: 0.5);
  Widget _buildSectionHeader(String title) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 10), child: Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.5)));
  
  Widget _buildRow({required String label, required String subLabel, required double cost, required double price, required String currency, VoidCallback? onDelete}) {
    final format = NumberFormat.simpleCurrency(name: currency, decimalDigits: 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Row(children: [
            if (onDelete != null) Padding(padding: const EdgeInsets.only(right: 8.0), child: InkWell(onTap: onDelete, child: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.red))),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), if (subLabel.isNotEmpty) Text(subLabel, style: TextStyle(fontSize: 11, color: Colors.grey[500]))]))
          ])),
          Expanded(flex: 2, child: Text(cost > 0 ? format.format(cost) : "-", style: TextStyle(color: Colors.red[300], fontSize: 13), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(price > 0 ? format.format(price) : "-", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

// Helper Class for Stats
class _CurrencyStats {
  double revenue = 0;
  double cost = 0;
}

// Summary Card Widget
class _CurrencySummaryCard extends StatelessWidget {
  final String currency;
  final double revenue;
  final double cost;

  const _CurrencySummaryCard({required this.currency, required this.revenue, required this.cost});

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.simpleCurrency(name: currency, decimalDigits: 0);
    final profit = revenue - cost;
    
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(currency, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          _row("Rev", format.format(revenue), Colors.black),
          _row("Cost", format.format(cost), Colors.red[300]!),
          const Divider(height: 12),
          _row("Profit", format.format(profit), profit >= 0 ? Colors.green : Colors.red, isBold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}

class DottedContainer extends StatelessWidget {
  final Widget child;
  const DottedContainer({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid)),
      child: child,
    );
  }
}