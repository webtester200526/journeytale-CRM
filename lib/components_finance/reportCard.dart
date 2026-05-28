import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/pdfEditor/orderFinances_editor.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CompactFinancialReportCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const CompactFinancialReportCard({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  // --- EXCHANGE RATES (Base: RMB) ---
  // In a real app, fetch this from a 'settings' collection
  static const Map<String, double> rates = {
  
    'RMB': 1.0,
    'USD': 7.20,
    'IDR': 0.00046,
    'EUR': 7.80,
    'SGD': 5.35,
    'JPY': 0.048,
  };

  double _convertToBase(double amount, String? currency) {
    if (amount == 0) return 0;
    String code = (currency ?? 'RMB').toUpperCase();
    double rate = rates[code] ?? 1.0;
    return amount * rate;
  }

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.simpleCurrency(decimalDigits: 0, name: '¥'); // Report in RMB
    final String invoiceCode = "INV-${orderId.substring(0, 6).toUpperCase()}";

    // 1. Nested Streams (Added Hotels)
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
                                // --- NEW: HOTEL STREAM ---
                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance.collection('orders').doc(orderId).collection('hotels').snapshots(),
                                  builder: (context, hotelSnap) {

                                    if (!serviceSnap.hasData || !transportSnap.hasData || !ticketSnap.hasData || 
                                        !flightSnap.hasData || !trainSnap.hasData || !guideSnap.hasData || 
                                        !feeSnap.hasData || !hotelSnap.hasData) {
                                      return const Card(child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator(strokeWidth: 2))));
                                    }

                                    // 2. Aggregation Logic
                                    double totalRevenue = 0;
                                    double totalCost = 0;
                                    
                                    // Helper to process docs with Currency Conversion
                                    void processDocs(QuerySnapshot snap, {
                                      bool isTransport = false, 
                                      bool isService = false, 
                                      bool isFlightTrain = false, 
                                      bool isGuide = false,
                                      bool isHotel = false, // New flag
                                    }) {
                                      for (var doc in snap.docs) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        final String currency = data['currency'] ?? 'RMB'; // Get Doc Currency

                                        double rawRev = 0;
                                        double rawCost = 0;

                                        if (isService) {
                                          final p = (data['price_per_day'] as num?)?.toDouble() ?? 0;
                                          final c = (data['modal_per_day'] as num?)?.toDouble() ?? 0;
                                          final d = (data['days'] as num?)?.toInt() ?? 1;
                                          final disc = (data['discount'] as num?)?.toDouble() ?? 0;
                                          rawRev = (p * d) - disc;
                                          rawCost = c * d;
                                        } else if (isTransport) {
                                          rawRev = (data['fee'] as num?)?.toDouble() ?? 0;
                                          rawCost = (data['cost'] as num?)?.toDouble() ?? 0;
                                        } else if (isFlightTrain) {
                                          rawRev = (data['client_price'] as num?)?.toDouble() ?? 0;
                                          rawCost = (data['internal_price'] as num?)?.toDouble() ?? 0;
                                        } else if (isGuide) {
                                          // Guides might have complex calc, usually simplified here
                                          rawRev = (data['client_price'] as num?)?.toDouble() ?? 0;
                                          // Guide fallback logic handled in editor, usually 'client_price' is total
                                          // If manual calculation needed:
                                          if (rawRev == 0) {
                                             double daily = (data['fee_per_day'] as num?)?.toDouble() ?? 0;
                                             // Guide days calculation would require date parsing, assume pre-calced field 'total_fee' exists or simpler logic
                                             rawRev = daily; 
                                          }
                                          // Internal cost often same as client price unless markup
                                          rawCost = (data['internal_price'] as num?)?.toDouble() ?? rawRev; 
                                        } else if (isHotel) {
                                          // Hotels: Base * Nights = Cost | Client Price = Revenue
                                          // Note: Hotel Editor saves 'client_price' as total, 'base_price' as per night
                                          rawRev = (data['client_price'] as num?)?.toDouble() ?? 0;
                                          
                                          double base = (data['base_price'] as num?)?.toDouble() ?? 0;
                                          int nights = (data['nights'] as num?)?.toInt() ?? 1;
                                          rawCost = base * nights;
                                        } else {
                                          // Tickets & Additional
                                          rawRev = (data['total_price'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0;
                                          rawCost = (data['total_cost'] as num?)?.toDouble() ?? (data['cost'] as num?)?.toDouble() ?? 0;
                                        }

                                        // Convert and Add
                                        totalRevenue += _convertToBase(rawRev, currency);
                                        totalCost += _convertToBase(rawCost, currency);
                                      }
                                    }

                                    processDocs(serviceSnap.data!, isService: true);
                                    processDocs(transportSnap.data!, isTransport: true);
                                    processDocs(flightSnap.data!, isFlightTrain: true);
                                    processDocs(trainSnap.data!, isFlightTrain: true);
                                    processDocs(guideSnap.data!, isGuide: true);
                                    processDocs(hotelSnap.data!, isHotel: true); // Added Hotels
                                    processDocs(ticketSnap.data!);
                                    processDocs(feeSnap.data!);

                                    final double profit = totalRevenue - totalCost;
                                    final double margin = totalRevenue > 0 ? (profit / totalRevenue) * 100 : 0;

                                    // 3. Build UI
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                                      child: ExpansionTile(
                                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: Border.all(color: Colors.transparent),
                                        title: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                                              child: Text(invoiceCode, style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(orderData['client_name'] ?? 'Unknown Client', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                  Text(orderData['trip_title'] ?? 'Trip Details', style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 12.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              _headerStat("Revenue", format.format(totalRevenue), Colors.black),
                                              _headerStat("Cost", format.format(totalCost), Colors.red[300]!),
                                              _headerStat("Profit", format.format(profit), profit >= 0 ? Colors.green : Colors.red),
                                            ],
                                          ),
                                        ),
                                        children: [
                                          const Divider(),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                            child: Column(
                                              children: [
                                                // Category Breakdowns
                                                _buildCategorySummary("Services", serviceSnap.data!, format, isService: true),
                                                _buildCategorySummary("Transport", transportSnap.data!, format, isTransport: true),
                                                _buildCategorySummary("Hotels", hotelSnap.data!, format, isHotel: true), // New Row
                                                _buildCategorySummary("Flights", flightSnap.data!, format, isFlightTrain: true),
                                                _buildCategorySummary("Trains", trainSnap.data!, format, isFlightTrain: true),
                                                _buildCategorySummary("Guides", guideSnap.data!, format, isGuide: true),
                                                _buildCategorySummary("Tickets", ticketSnap.data!, format),
                                                _buildCategorySummary("Additional", feeSnap.data!, format),
                                                
                                                const SizedBox(height: 16),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text("Margin: ${margin.toStringAsFixed(1)}%", style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
                                                    ElevatedButton.icon(
                                                      onPressed: () {
                                                        Navigator.push(context, MaterialPageRoute(builder: (context) => InternalReportPdfEditor(orderId: orderId)));
                                                      },
                                                      icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.white),
                                                      label: const Text("PDF Report"),
                                                      
                                                    ),
                                                  ],
                                                )
                                              ],
                                            ),
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

  Widget _headerStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildCategorySummary(String title, QuerySnapshot snap, NumberFormat format, {
    bool isService = false, 
    bool isTransport = false, 
    bool isFlightTrain = false, 
    bool isGuide = false,
    bool isHotel = false,
  }) {
    if (snap.docs.isEmpty) return const SizedBox.shrink();

    double catRev = 0;
    double catCost = 0;

    for (var doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String currency = data['currency'] ?? 'RMB';

      double r = 0;
      double c = 0;

      if (isService) {
        final p = (data['price_per_day'] as num?)?.toDouble() ?? 0;
        final cost = (data['modal_per_day'] as num?)?.toDouble() ?? 0;
        final d = (data['days'] as num?)?.toInt() ?? 1;
        final disc = (data['discount'] as num?)?.toDouble() ?? 0;
        r = (p * d) - disc;
        c = cost * d;
      } else if (isTransport) {
        r = (data['fee'] as num?)?.toDouble() ?? 0;
        c = (data['cost'] as num?)?.toDouble() ?? 0;
      } else if (isFlightTrain) {
        r = (data['client_price'] as num?)?.toDouble() ?? 0;
        c = (data['internal_price'] as num?)?.toDouble() ?? 0;
      } else if (isGuide) {
        r = (data['client_price'] as num?)?.toDouble() ?? 0;
        c = (data['internal_price'] as num?)?.toDouble() ?? 0;
        if (c == 0 && data['fee_per_day'] != null) {
           // Fallback if internal_price not explicit
           double daily = (data['fee_per_day'] as num?)?.toDouble() ?? 0;
           double ot = (data['ot_fee'] as num?)?.toDouble() ?? 0; 
           // If 'client_price' is stored, we assume internal is raw cost without markup.
           // Simplified:
           c = daily + ot; 
        }
      } else if (isHotel) {
        r = (data['client_price'] as num?)?.toDouble() ?? 0;
        double base = (data['base_price'] as num?)?.toDouble() ?? 0;
        int nights = (data['nights'] as num?)?.toInt() ?? 1;
        c = base * nights;
      } else {
        r = (data['total_price'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0;
        c = (data['total_cost'] as num?)?.toDouble() ?? (data['cost'] as num?)?.toDouble() ?? 0;
      }

      catRev += _convertToBase(r, currency);
      catCost += _convertToBase(c, currency);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey))),
          Expanded(flex: 2, child: Text(format.format(catCost), textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: Colors.red[200]))),
          Expanded(flex: 2, child: Text(format.format(catRev), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}