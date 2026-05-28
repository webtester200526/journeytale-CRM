import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/components_ORDER_DETAILS/currencyExchange.dart';
import 'package:crmx/components_ORDER_DETAILS/entryFee_editor.dart';
import 'package:crmx/components_ORDER_DETAILS/flightEditor.dart';
import 'package:crmx/components_ORDER_DETAILS/flightTracker.dart';
import 'package:crmx/components_ORDER_DETAILS/hotelEditor.dart';
import 'package:crmx/components_ORDER_DETAILS/invoiceClientHandler.dart';
import 'package:crmx/components_ORDER_DETAILS/itineraryEditor.dart';
import 'package:crmx/components_ORDER_DETAILS/logisticManager.dart';
import 'package:crmx/components_ORDER_DETAILS/meta.dart';
import 'package:crmx/components_ORDER_DETAILS/orderFinanceDetails.dart';
import 'package:crmx/components_ORDER_DETAILS/orderNotes.dart';
import 'package:crmx/components_ORDER_DETAILS/orderServicesEditor.dart';
import 'package:crmx/components_ORDER_DETAILS/paymentToVendor.dart';
import 'package:crmx/components_ORDER_DETAILS/personEditor.dart';
import 'package:crmx/components_ORDER_DETAILS/paymentFromClient.dart';
import 'package:crmx/components_ORDER_DETAILS/tourguide_manager.dart';
import 'package:crmx/components_ORDER_DETAILS/trainEditor.dart';
import 'package:crmx/components_ORDER_DETAILS/transportManager.dart';
import 'package:crmx/itinerary_service.dart';
import 'package:crmx/pdfEditor/invoice_editor.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// --- IMPORTS ---
import 'database_service.dart';
import 'service_model.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;
  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final DatabaseService _db = DatabaseService();
  List<ServiceModel> _allAvailableServices = [];
  bool _isLoadingServices = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final services = await _db.getServicesFuture();
      if (mounted) {
        setState(() {
          _allAvailableServices = services;
          _isLoadingServices = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading services: $e");
    }
  }

  // --- ACTIONS ---

  Future<void> _addService(String serviceId, int duration, String serviceName) async {
    await _db.addServiceToOrder(serviceName: serviceName, orderId: widget.orderId, serviceId: serviceId, days: duration);
  }

  void _showAddServiceDialog(OrderModel order) {
    final unselectedServices = _allAvailableServices
        .where((s) => !order.serviceTypes.contains(s.name))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add Service", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (unselectedServices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text("All available services added.", style: TextStyle(color: Colors.grey[600]))),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: unselectedServices.map((service) => ActionChip(
                  label: Text(service.name),
                  backgroundColor: Colors.grey[100],
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _addService(service.id, order.durationDays, service.name);
                  },
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Order?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteOrder(widget.orderId);
      if (mounted) Navigator.pop(context);
    }
  }

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    // We stream the Order data so everything updates reactively when MetaCard saves changes
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!.exists) return const Scaffold(body: Center(child: Text("Order not found")));

        // Reconstruct OrderModel from Stream Data for children widgets
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final orderModel = OrderModel.fromMap(data, widget.orderId);

        // Responsive
        final isDesktop = MediaQuery.of(context).size.width > 900;

        return Scaffold(
          backgroundColor: const Color(0xFFF3F5F7),
          appBar: AppBar(
            title: Row(
              children: [
                Text("Order / ${widget.orderId.substring(0, 6).toUpperCase()}", 
                     style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.normal)),
                const SizedBox(width: 8),
                Text(orderModel.name, 
                     style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black, fontSize: 16)),
              ],
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: Colors.grey[200], height: 1),
            ),
            iconTheme: const IconThemeData(color: Colors.black),
            actions: [
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceEditorPage(orderId: widget.orderId))),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Invoice'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.black, side: const BorderSide(color: Colors.grey)),
              ),
              const SizedBox(width: 24),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: isDesktop 
                  ? _buildDesktopLayout(orderModel) 
                  : _buildMobileLayout(orderModel),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- LAYOUTS ---

  Widget _buildDesktopLayout(OrderModel order) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Main (Flex 7)
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. NEW META CARD REPLACING OLD ONE
              OrderMetaCard(orderId: widget.orderId),
              const SizedBox(height: 24),
              
              _buildSectionHeader("Transportation", Icons.directions_car),
              _wrapInCard(child: LogisticsManager(orderId: widget.orderId, orderModel: order)),
              const SizedBox(height: 24),

              _wrapInCard(child: TourGuideManager(orderId: widget.orderId, orderModel: order)),
              const SizedBox(height: 24),

              _buildSectionHeader("Accommodations", Icons.hotel),
              _wrapInCard(child: HotelDetailsEditor(
                orderId: widget.orderId,
                orderStartDate: order.startDate,
                orderEndDate: order.endDate,
              )),
              const SizedBox(height: 24),

              _buildSectionHeader("Tickets & Entry Fees", Icons.confirmation_number),
              _wrapInCard(child: OrderTicketManager(orderId: widget.orderId, orderModel: order)),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader("Extra Services", Icons.room_service),
                  IconButton(onPressed: () => _showAddServiceDialog(order), icon: const Icon(Icons.add_circle))
                ],
              ),
              _wrapInCard(child: OrderServicesEditor(
                orderId: widget.orderId,
                orderStartDate: order.startDate,
                orderEndDate: order.endDate,
                orderModel: order,
              )),
              const SizedBox(height: 24),

              _buildSectionHeader("Full Itinerary", Icons.map_outlined),
              _wrapInCard(child: ItineraryEditor(orderId: widget.orderId)),
              const SizedBox(height: 40),
            ],
          ),
        ),
        const SizedBox(width: 24),
        
        // Right Column: Sidebar (Flex 3)
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InvoiceClientHeader(clientName: order.name, orderId: order.id),
              const SizedBox(height: 16),
              
              //_buildSectionHeader("Flight Lookup", Icons.flight_takeoff),
              //_wrapInCard(child: FlightLookupWidget()),
              //_buildSectionHeader("Notes", Icons.flight_takeoff),
              OrderNotesWidget(orderId: widget.orderId, initialNotes:order.notes ),
              const SizedBox(height: 24),

              // 2. NEW PASSENGER MANAGER
              _wrapInCard(child: PassengerManager(orderId: widget.orderId), padding: 0),
              const SizedBox(height: 24),

              _buildSectionTitle("Financial Overview"),
              _wrapInCard(child: FinancialReportSection(orderId: widget.orderId, orderData: order.toMap())),
              const SizedBox(height: 24),

              _buildSectionTitle("Income"),
              _wrapInCard(child: PaymentFromClientWidget(orderId: widget.orderId)),
              const SizedBox(height: 40),

              _buildSectionTitle("Expenses"),
              _wrapInCard(child: PaymentToVendorWidget(orderId: widget.orderId)),
              const SizedBox(height: 40),

              //CurrencyExchangeManager(orderId: widget.orderId,),
              //const SizedBox(height: 40),

              Center(
                child: TextButton.icon(
                  onPressed: _confirmDeleteOrder,
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
                  label: const Text('Delete Order', style: TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(OrderModel order) {
    return Column(
      children: [
        // Sidebar content first on mobile? Or Meta first? Usually Meta first.
        OrderMetaCard(orderId: widget.orderId),
        const SizedBox(height: 24),
        // Then Sidebar items like Passengers
        _wrapInCard(child: PassengerManager(orderId: widget.orderId), padding: 0),
        const SizedBox(height: 24),
        // Then Main Content
        _buildSectionHeader("Transportation", Icons.directions_car),
        _wrapInCard(child: LogisticsManager(orderId: widget.orderId, orderModel: order)),
        // ... (Repeat structure from Desktop)
        // For brevity, you can duplicate the children list from Desktop or extract a widget
      ],
    );
  }

  // --- HELPERS ---

  Widget _wrapInCard({required Widget child, double padding = 24.0}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 2),
      child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 0.5)),
    );
  }
}