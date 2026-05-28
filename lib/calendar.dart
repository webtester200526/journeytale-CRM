import 'package:crmx/components_ORDER_DETAILS/itineraryEditorDialog.dart';
import 'package:crmx/order_detail.dart';
import 'package:crmx/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crmx/service_model.dart';
import 'database_service.dart';

enum CalendarMode { list, timeline, month }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final DatabaseService _db = DatabaseService();
  
  // State variables
  CalendarMode _viewMode = CalendarMode.list;
  DateTime _focusedDate = DateTime.now();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7), // Professional Gray Background
      appBar: AppBar(
        title: Text(
          _getTitle().toUpperCase(), 
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black, letterSpacing: 0.5)
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
        actions: [
          // Styled View Switcher
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  _buildViewIconButton(Icons.format_list_bulleted, CalendarMode.list, "List"),
                  Container(width: 1, height: 20, color: Colors.grey[300]),
                  _buildViewIconButton(Icons.view_timeline_outlined, CalendarMode.timeline, "Timeline"),
                  Container(width: 1, height: 20, color: Colors.grey[300]),
                  _buildViewIconButton(Icons.calendar_today, CalendarMode.month, "Month"),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Navigator (Only for Timeline and Month)
          if (_viewMode != CalendarMode.list) 
            _buildDateNavigator(),

          Expanded(
            child: StreamBuilder<List<OrderModel>>(
              stream: _db.getOrders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.black));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text("No orders found", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      ],
                    )
                  );
                }
                
                List<OrderModel> orders = snapshot.data!;
                orders.sort((a, b) => a.startDate.compareTo(b.startDate));

                switch (_viewMode) {
                  case CalendarMode.list:
                    return _buildListView(orders);
                  case CalendarMode.timeline:
                    return _buildTimelineView(orders);
                  case CalendarMode.month:
                    return _buildMonthView(orders);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_viewMode) {
      case CalendarMode.list: return 'Schedule List';
      case CalendarMode.timeline: return 'Project Timeline';
      case CalendarMode.month: return 'Master Calendar';
    }
  }

  Widget _buildViewIconButton(IconData icon, CalendarMode mode, String tooltip) {
    final isSelected = _viewMode == mode;
    return IconButton(
      icon: Icon(icon, size: 20, color: isSelected ? Colors.black : Colors.grey[500]),
      tooltip: tooltip,
      onPressed: () => setState(() => _viewMode = mode),
      splashRadius: 20,
    );
  }

  // ===========================================================================
  // NAVIGATION & CONTROLS
  // ===========================================================================
  
  Widget _buildDateNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Controls
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => setState(() {
                    _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1, 1);
                  }),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _focusedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDatePickerMode: DatePickerMode.year,
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: const ColorScheme.light(primary: Colors.black, onPrimary: Colors.white),
                        ),
                        child: child!,
                      );
                    }
                  );
                  if (picked != null) {
                    setState(() => _focusedDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('MMMM yyyy').format(_focusedDate),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: Colors.grey[600], size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => setState(() {
                    _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1, 1);
                  }),
                ),
              ),
            ],
          ),

          // Right Controls
          TextButton.icon(
            onPressed: () => setState(() => _focusedDate = DateTime.now()),
            icon: const Icon(Icons.today, size: 16),
            label: const Text("Today"),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.grey[100],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // VIEW 1: LIST
  // ===========================================================================
 double _calculateProgress(OrderModel order) {
    final now = DateTime.now();
    if (now.isAfter(order.endDate)) return 1.0;
    if (now.isAfter(order.startDate)) {
      final total = order.endDate.difference(order.startDate).inMinutes;
      final current = now.difference(order.startDate).inMinutes;
      return total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  // --- MAIN LIST BUILDER ---
Widget _buildListView(List<OrderModel> allOrders) {
  
  // --- A. FILTERING LOGIC ---
  // We filter the raw list first, based on the search query
  final filteredOrders = allOrders.where((order) {
    if (_searchQuery.isEmpty) return true;
    
    final query = _searchQuery.toLowerCase();
    
    // 1. Name Match
    final nameMatch = order.name.toLowerCase().contains(query);
    
    // 2. Invoice Match (INV + first 6 chars of ID)
    final shortId = order.id.length >= 6 ? order.id.substring(0, 6) : order.id;
    final invoiceRef = "inv-$shortId"; // Lowercase for comparison
    final invoiceMatch = invoiceRef.contains(query);

    return nameMatch || invoiceMatch;
  }).toList();

  // --- B. BUCKET SORTING (Using filteredOrders) ---
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final ongoingActive = <OrderModel>[];
  final readyToArchive = <OrderModel>[];
  final upcoming = <OrderModel>[];
  final history = <OrderModel>[];

  for (var order in filteredOrders) {
    final start = DateTime(order.startDate.year, order.startDate.month, order.startDate.day);
    final end = DateTime(order.endDate.year, order.endDate.month, order.endDate.day);
    
    final progress = _calculateProgress(order);

    if (today.isAfter(end)) {
      history.add(order);
    } else if (today.isBefore(start)) {
      upcoming.add(order);
    } else {
      if (progress >= 1.0) {
        readyToArchive.add(order);
      } else {
        ongoingActive.add(order);
      }
    }
  }

  // Sorting
  ongoingActive.sort((a, b) => a.endDate.compareTo(b.endDate));
  readyToArchive.sort((a, b) => b.endDate.compareTo(a.endDate));
  upcoming.sort((a, b) => a.startDate.compareTo(b.startDate));
  history.sort((a, b) => b.endDate.compareTo(a.endDate));

  // --- C. BUILD UI (Search Bar + List) ---
  return Column(
    children: [
      // 1. Search Bar Header
      Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        color: const Color(0xFFF3F5F7), // Background color
        child: TextField(
          controller: _searchCtrl,
          onChanged: (val) {
            setState(() {
              _searchQuery = val.trim();
            });
          },
          decoration: InputDecoration(
            hintText: "Search Name or Invoice (INV-123...)",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchQuery.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = "");
                  },
                ) 
              : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),

      // 2. The List
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            
            // ONGOING
            if (ongoingActive.isNotEmpty) ...[
              _CollapsibleSection(
                title: "Ongoing Trips",
                count: ongoingActive.length,
                color: Colors.blue,
                initiallyExpanded: true,
                children: ongoingActive.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildOrderCard(o),
                )).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // COMPLETED
            if (readyToArchive.isNotEmpty) ...[
              _CollapsibleSection(
                title: "Completed",
                count: readyToArchive.length,
                color: Colors.green,
                initiallyExpanded: false,
                children: readyToArchive.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildOrderCard(o),
                )).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // UPCOMING
            if (upcoming.isNotEmpty) ...[
              _CollapsibleSection(
                title: "Upcoming",
                count: upcoming.length,
                color: Colors.amber,
                initiallyExpanded: false,
                children: upcoming.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildOrderCard(o),
                )).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // HISTORY
            if (history.isNotEmpty) ...[
              _CollapsibleSection(
                title: "History",
                count: history.length,
                color: Colors.grey,
                initiallyExpanded: false,
                children: history.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildOrderCard(o),
                )).toList(),
              ),
            ],

            // EMPTY STATE
            if (filteredOrders.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 80.0),
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty ? "No orders found" : "No results for '$_searchQuery'", 
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              )
          ],
        ),
      ),
    ],
  );
}
  // --- CARD BUILDER ---

  Widget _buildOrderCard(OrderModel order) {
    final progress = _calculateProgress(order);

    Color statusColor = progress == 1.0 
        ? const Color(0xFF10B981) // Green
        : (progress > 0 ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B)); // Blue : Orange

    if (progress <= 0) statusColor = const Color(0xFFF59E0B);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1))
        ],
      ),
      child: InkWell(
        onTap: () async {

           bool granted = await PermissionService().canAccessOrders;

            if (granted) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailPage(orderId: order.id)));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You do not have permission to manage orders.'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 3),
                ),
              );
            }
           
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        order.name.isNotEmpty ? order.name[0].toUpperCase() : "?",
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                "${order.destination} ${order.additionalDestinations.isNotEmpty ? '+${order.additionalDestinations.length}' : ''}",
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text("•", style: TextStyle(color: Colors.grey[300])),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "${DateFormat('MMM dd').format(order.startDate)} - ${DateFormat('MMM dd').format(order.endDate)}",
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("${(progress * 100).toInt()}%", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 24, width: 24,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.edit_note, size: 20),
                          color: Colors.grey[400],
                          onPressed: () {
                             showDialog(context: context, builder: (context) => ItineraryEditorDialog(orderId: order.id));
                          },
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
            if (progress < 1.0)
              LinearProgressIndicator(value: progress, minHeight: 3, backgroundColor: Colors.grey[50], valueColor: AlwaysStoppedAnimation<Color>(statusColor))
            else 
              Container(height: 3, color: statusColor),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // VIEW 2: TIMELINE
  // ===========================================================================
  Widget _buildTimelineView(List<OrderModel> orders) {
    const double dayWidth = 60.0;
    const double rowHeight = 64.0;
    const double headerHeight = 56.0;

    DateTime startDate = DateTime(_focusedDate.year, _focusedDate.month, 1);
    int daysInMonth = DateUtils.getDaysInMonth(_focusedDate.year, _focusedDate.month);
    
    List<OrderModel> activeOrders = orders.where((o) {
       return o.endDate.isAfter(startDate) && o.startDate.isBefore(startDate.add(Duration(days: daysInMonth)));
    }).toList();

    if (activeOrders.isEmpty) {
      return Center(child: Text("No schedules for ${DateFormat('MMMM').format(_focusedDate)}", style: const TextStyle(color: Colors.grey)));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: const BoxDecoration(color: Colors.white),
          width: daysInMonth * dayWidth,
          height: (activeOrders.length * rowHeight) + headerHeight + 20, // Extra padding at bottom
          child: Stack(
            children: [
              // Grid Background
              for (int i = 0; i < daysInMonth; i++) ...[
                Positioned(
                  left: i * dayWidth,
                  top: 0, bottom: 0, width: dayWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.grey.shade100)),
                      color: (startDate.add(Duration(days: i)).weekday >= 6) ? const Color(0xFFFAFAFA) : Colors.white,
                    ),
                  ),
                ),
                // Header Row
                Positioned(
                  left: i * dayWidth, top: 0, height: headerHeight, width: dayWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200), right: BorderSide(color: Colors.grey.shade100)),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(startDate.add(Duration(days: i))).toUpperCase(), 
                          style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${i + 1}", 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: (startDate.add(Duration(days: i)).weekday >= 6) ? Colors.grey[400] : Colors.black)
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              // Gantt Bars
              for (int i = 0; i < activeOrders.length; i++) 
                _buildGanttBar(activeOrders[i], i, startDate, dayWidth, rowHeight, headerHeight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGanttBar(OrderModel order, int rowIndex, DateTime monthStart, double dayWidth, double rowHeight, double headerOffset) {
    int startOffset = order.startDate.difference(monthStart).inDays;
    double visualStart = (startOffset < 0) ? 0 : (startOffset * dayWidth);
    
    int duration = order.endDate.difference(order.startDate).inDays + 1;
    if (startOffset < 0) duration += startOffset; 

    double width = duration * dayWidth;

    return Positioned(
      left: visualStart + 4, // slight padding
      top: headerOffset + (rowIndex * rowHeight) + 12,
      width: (width - 8).clamp(10, double.infinity), // slight padding and min width
      height: rowHeight - 24,
      child: Tooltip(
        message: "${order.name}\n${DateFormat('MMM dd').format(order.startDate)} - ${DateFormat('MMM dd').format(order.endDate)}",
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2C3E50), Color(0xFF000000)]), // Professional dark gradient
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  order.name,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // VIEW 3: MONTH GRID
  // ===========================================================================
Widget _buildMonthView(List<OrderModel> orders) {
    final firstDay = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final int daysInMonth = DateUtils.getDaysInMonth(_focusedDate.year, _focusedDate.month);
    
    int firstWeekday = firstDay.weekday; 
    int offset = firstWeekday - 1; 

    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
      ),
      child: Column(
        children: [
          // Weekday Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200))
            ),
            child: Row(
              children: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
                .map((d) => Expanded(
                  child: Center(
                    child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1))
                  )
                )).toList(),
            ),
          ),
          
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.5, // Made taller to fit 8 items
              ),
              itemCount: 42, 
              itemBuilder: (context, index) {
                int dayNum = index - offset + 1;
                
                // Empty slots for prev/next month
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade50)));
                }

                DateTime currentDay = DateTime(_focusedDate.year, _focusedDate.month, dayNum);
                bool isToday = DateUtils.isSameDay(currentDay, DateTime.now());
                
                // Filter orders active on this day
                var daysOrders = orders.where((o) => 
                  (o.startDate.isBefore(currentDay.add(const Duration(days: 1))) && 
                   o.endDate.isAfter(currentDay.subtract(const Duration(days: 1))))
                ).toList();

                return InkWell(
                  onTap: () => _showDayDetails(context, currentDay, daysOrders),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade100),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Day Number
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 24, height: 24,
                              alignment: Alignment.center,
                              decoration: isToday ? const BoxDecoration(color: Colors.black, shape: BoxShape.circle) : null,
                              child: Text(
                                "$dayNum", 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 12,
                                  color: isToday ? Colors.white : Colors.grey[700]
                                )
                              ),
                            ),
                          ),
                        ),
                        
                        // Order List (Mini Chips)
                        Expanded(
                          child: ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            // Show up to 8 items. If more, the 9th slot becomes the "+X more" text
                            itemCount: daysOrders.length > 8 ? 9 : daysOrders.length,
                            itemBuilder: (ctx, i) {
                               // Overflow indicator
                               if (i == 8) {
                                 return Center(
                                   child: Padding(
                                     padding: const EdgeInsets.only(top: 2.0),
                                     child: Text(
                                       "+${daysOrders.length - 8} more...", 
                                       style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)
                                     ),
                                   )
                                 );
                               }
                               
                               // Order Chip
                               return Container(
                                 margin: const EdgeInsets.only(bottom: 2),
                                 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                 decoration: BoxDecoration(
                                   color: Colors.blue[50],
                                   border: Border.all(color: Colors.blue.withOpacity(0.1)),
                                   borderRadius: BorderRadius.circular(3),
                                 ),
                                 child: Text(
                                   daysOrders[i].name,
                                   style: TextStyle(fontSize: 9, color: Colors.blue[900], fontWeight: FontWeight.w500),
                                   maxLines: 1, 
                                   overflow: TextOverflow.ellipsis,
                                 ),
                               );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- POPUP DIALOG FOR FULL LIST ---
  void _showDayDetails(BuildContext context, DateTime date, List<OrderModel> orders) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titlePadding: const EdgeInsets.all(20),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMMM d, yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 4),
                  Text("${orders.length} Scheduled Trips", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
            ],
          ),
          content: SizedBox(
            width: 400, // Fixed width for desktop look
            height: 500,
            child: orders.isEmpty 
              ? const Center(child: Text("No orders for this day."))
              : ListView.separated(
                  itemCount: orders.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final order = orders[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      title: Text(order.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        "${order.destination} • ${DateFormat('MMM d').format(order.startDate)} - ${DateFormat('MMM d').format(order.endDate)}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[50],
                        child: Text(order.name.isNotEmpty ? order.name[0] : "?", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.chevron_right, size: 18),
                        onPressed: () {
                          // Close dialog and navigate
                          Navigator.pop(context); 
                          showDialog(
                            context: context,
                            builder: (context) {
                              return ItineraryEditorDialog(orderId: order.id);
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
          ),
        );
      },
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final int count;
  final Color color;
  final List<Widget> children;
  final bool initiallyExpanded;
  final bool isSubSection;

  const _CollapsibleSection({
    required this.title,
    required this.count,
    required this.color,
    required this.children,
    this.initiallyExpanded = true,
    this.isSubSection = false,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                  size: widget.isSubSection ? 18 : 20,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: widget.isSubSection ? 11 : 12, 
                    fontWeight: FontWeight.w800, 
                    color: Colors.grey[600], 
                    letterSpacing: 1.0
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${widget.count}",
                    style: TextStyle(
                      fontSize: widget.isSubSection ? 10 : 11, 
                      fontWeight: FontWeight.bold, 
                      color: widget.color
                    ),
                  ),
                ),
                const Spacer(),
                if (!_isExpanded)
                  Expanded(child: Container(height: 1, color: Colors.grey[200], margin: const EdgeInsets.only(left: 16))),
              ],
            ),
          ),
        ),
        // Body
        AnimatedCrossFade(
          firstChild: Container(),
          secondChild: Column(children: widget.children),
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}