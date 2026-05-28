import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/components_ORDER_DETAILS/flightEditor.dart';
import 'package:crmx/components_ORDER_DETAILS/trainEditor.dart';
import 'package:crmx/components_ORDER_DETAILS/transportManager.dart';
import 'package:crmx/service_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Import your existing models/pdf editors if needed



// ==========================================
// 1. SUPER WIDGET: LOGISTICS MANAGER
// ==========================================

class LogisticsManager extends StatefulWidget {
  final String orderId;
  final OrderModel orderModel;

  const LogisticsManager({
    super.key,
    required this.orderId,
    required this.orderModel,
  });

  @override
  State<LogisticsManager> createState() => _LogisticsManagerState();
}

class _LogisticsManagerState extends State<LogisticsManager> {
  // Selection State
  bool _showAirportTransfer = false;
  bool _showRailwayTransfer = false;
  bool _showCityTour = true; // Default on
  bool _showInterCity = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //const Text("Logistics & Services Checklist", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        //const SizedBox(height: 12),
        
        // --- CHECKLIST (Filter Chips) ---
        Wrap(
          spacing: 10,
          children: [
            _buildChip("Airport Transfer", Icons.flight, _showAirportTransfer, (v) => setState(() => _showAirportTransfer = v)),
            _buildChip("Railway Transfer", Icons.train, _showRailwayTransfer, (v) => setState(() => _showRailwayTransfer = v)),
            _buildChip("City Tour", Icons.location_city, _showCityTour, (v) => setState(() => _showCityTour = v)),
            _buildChip("Inter-City Tour", Icons.map_outlined, _showInterCity, (v) => setState(() => _showInterCity = v)),
          ],
        ),
        
        const SizedBox(height: 24),

        // --- 1. AIRPORT TRANSFERS (Flights) ---
        if (_showAirportTransfer) ...[
          _SectionHeader("Airport Transfers & Flights", Icons.flight_takeoff, Colors.blue),
          FlightDetailsEditor(orderId: widget.orderId),
          const SizedBox(height: 32),
        ],

        // --- 2. RAILWAY TRANSFERS (Trains) ---
        if (_showRailwayTransfer) ...[
          _SectionHeader("Railway Transfers", Icons.train, Colors.teal),
          TrainDetailsEditor(orderId: widget.orderId),
          const SizedBox(height: 32),
        ],

        // --- 3. GROUND TRANSPORT (City & Inter-City) ---
        // We use the same Transport Manager for both, as they are essentially daily car bookings
        if (_showCityTour || _showInterCity) ...[
          _SectionHeader(
            _showCityTour && _showInterCity ? "City & Inter-City Transport" : (_showCityTour ? "City Tour Transport" : "Inter-City Transport"),
            Icons.directions_car, 
            Colors.amber
          ),
          // Re-using the robust Transport Manager you already have
          OrderTransportManager(orderId: widget.orderId, orderModel: widget.orderModel),
        ]
      ],
    );
  }

  Widget _buildChip(String label, IconData icon, bool selected, ValueChanged<bool> onSelected) {
    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : Colors.black87),
      selected: selected,
      onSelected: onSelected,
      selectedColor: Colors.blue,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade300)),
      showCheckmark: false,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}






