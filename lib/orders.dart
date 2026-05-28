import 'package:crmx/components_ORDER/orderAnalytics.dart';
import 'package:crmx/createOrder.dart';
import 'package:crmx/order_detail.dart';
import 'package:crmx/service_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';

class Orders extends StatefulWidget {
  const Orders({super.key});

  @override
  State<Orders> createState() => _OrdersState();
}

class _OrdersState extends State<Orders> {
  final DatabaseService _db = DatabaseService();

  // State Variables
  final TextEditingController _searchController = TextEditingController();
  late Stream<List<OrderModel>> _ordersStream;

  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _ordersStream = _db.getOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  String _generateInvoiceCode(String id) {
    if (id.length < 6) return id.toUpperCase();
    return "INV-${id.substring(0, 6).toUpperCase()}";
  }

  List<OrderModel> _filterOrders(List<OrderModel> allOrders) {
    return allOrders.where((order) {
      // 1. Search Filter (Name, Destination, Invoice Code)
      final invoiceCode = _generateInvoiceCode(order.id).toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      final matchesSearch = order.name.toLowerCase().contains(query) || 
                            order.destination.toLowerCase().contains(query) ||
                            invoiceCode.contains(query); // Now searches by generated ID

      // 2. Date Filter (Orders starting within the range)
      bool matchesDate = true;
      if (_selectedDateRange != null) {
        // We check if the Order Start Date falls within the selected filter range
        // You can adjust this logic to check for overlaps if preferred
        matchesDate = order.startDate.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) && 
                      order.startDate.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }

      return matchesSearch && matchesDate;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange,
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
      setState(() => _selectedDateRange = picked);
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7), // Professional Admin Gray
      body: StreamBuilder<List<OrderModel>>(
        stream: _ordersStream, 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }
          
          if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}"));
          }

          final rawOrders = snapshot.data ?? [];
          final filteredOrders = _filterOrders(rawOrders);
          
          // Sort by date (newest first)
          filteredOrders.sort((a, b) => b.startDate.compareTo(a.startDate));

          return SingleChildScrollView(
            child: Column(
              children: [
                // Sticky Header & Filters
                Container(
                  color: const Color(0xFFF3F5F7),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    children: [
                       _buildModernHeader(context),
                      OrderAnalyticsDashboard(),
                      
                     
                      const SizedBox(height: 24),
                      _buildFilterBar(context),
                    ],
                  ),
                ),
            
                // Scrollable List
                
                filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          return _buildProfessionalOrderRow(
                            filteredOrders[index],
                            key: ValueKey(filteredOrders[index].id),
                          );
                        },
                      ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Orders',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1C20),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage bookings and financial status',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateOrderPage()));
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text("Create Order"),
          style: FilledButton.styleFrom(
        
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 2,
          ),
        )
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Row(
      children: [
        // Search Bar
        Expanded(
          flex: 2,
          child: Container(
            height: 48, 
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: Colors.black87, fontSize: 14), 
              cursorColor: Colors.black,
              decoration: InputDecoration(
                hintText: 'Search ID, Client, or City...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // Date Filter Button
        Expanded(
          child: InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _selectedDateRange != null ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _selectedDateRange != null ? Colors.black : Colors.grey.shade300),
                boxShadow: [
                   BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined, 
                    size: 16, 
                    color: _selectedDateRange != null ? Colors.white : Colors.grey[600]
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _selectedDateRange == null 
                        ? "Filter Date" 
                        : "${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}",
                      style: TextStyle(
                        fontSize: 13, 
                        fontWeight: FontWeight.w600,
                        color: _selectedDateRange != null ? Colors.white : Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Clear Filter Button (Conditional)
        if (_selectedDateRange != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => setState(() => _selectedDateRange = null),
            icon: const Icon(Icons.close, color: Colors.grey),
            tooltip: "Clear Date Filter",
          )
        ]
      ],
    );
  }

  Widget _buildProfessionalOrderRow(OrderModel order, {Key? key}) {
    final invoiceId = _generateInvoiceCode(order.id);

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailPage(orderId: order.id)));
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // 1. Invoice ID & Icon
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade100)
                  ),
                  child: Center(
                    child: Text(
                      order.name.isNotEmpty ? order.name[0].toUpperCase() : "#",
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.black54),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                
                // 2. Main Details (Client & ID)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1C20)),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4)
                        ),
                        child: Text(
                          invoiceId,
                          style: TextStyle(
                            fontFamily: 'Courier', // Monospace for ID
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600]
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Destination & Date (Hidden on very small screens if needed, but flex handles it)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                        children: [
                          Icon(Icons.flight_land, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            order.destination,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            "${DateFormat('dd MMM yyyy').format(order.startDate)} - ${DateFormat('dd MMM yyyy').format(order.endDate)}",
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 4. Statuses
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusBadge(order.paymentStatus),
                    const SizedBox(height: 8),
                    _buildTripStatusText(order.tripStatus),
                  ],
                ),
                
                const SizedBox(width: 16),
                Icon(Icons.chevron_right, color: Colors.grey[300], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(PaymentStatus status) {
    Color bg;
    Color text;
    String label = status.name.toUpperCase();

    switch (status) {
      case PaymentStatus.paid: 
        bg = const Color(0xFFDCFCE7); // Soft Green
        text = const Color(0xFF166534); // Dark Green
        break;
      case PaymentStatus.DownPayment: 
        bg = const Color(0xFFFEF3C7); // Soft Orange
        text = const Color(0xFFB45309); // Dark Orange
        break;
      case PaymentStatus.unpaid: 
        bg = const Color(0xFFFEE2E2); // Soft Red
        text = const Color(0xFF991B1B); // Dark Red
        break;
      default: 
        bg = Colors.grey[100]!;
        text = Colors.grey[600]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildTripStatusText(TripStatus status) {
    Color color;
    switch(status) {
      case TripStatus.upcoming: color = Colors.blue; break;
      case TripStatus.ongoing: color = Colors.purple; break;
      case TripStatus.finished: color = Colors.grey; break;
      case TripStatus.cancelled: color = Colors.red; break;
      default: color = Colors.grey;
    }
    
    // Capitalize first letter
    String label = status.name;
    label = label[0].toUpperCase() + label.substring(1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200)
            ),
            child: Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text("No orders found", style: TextStyle(fontSize: 16, color: Colors.grey[800], fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            "Try adjusting your search or filters", 
            style: TextStyle(fontSize: 14, color: Colors.grey[500])
          ),
          if (_selectedDateRange != null || _searchQuery.isNotEmpty) ...[
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _selectedDateRange = null;
                });
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text("Clear all filters"),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
            )
          ]
        ],
      ),
    );
  }
}