import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderAnalyticsDashboard extends StatefulWidget {
  const OrderAnalyticsDashboard({super.key});

  @override
  State<OrderAnalyticsDashboard> createState() => _OrderAnalyticsDashboardState();
}

class _OrderAnalyticsDashboardState extends State<OrderAnalyticsDashboard> {
  // Brand Colors
  static const Color _primaryBlue = Color(0xFF00A0E9);
  static const Color _accentOrange = Color(0xFFF5A623);
  static const Color _textDark = Color(0xFF1F2937);
  
  // Time Filter
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('startDate')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 150, 
            child: Center(child: CircularProgressIndicator(color: _primaryBlue))
          );
        }

        final docs = snapshot.data!.docs;
        final metrics = _calculateMetrics(docs);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- COMPACT HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                //const Text("Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark)),
                DropdownButton<int>(
                  value: _selectedYear,
                  underline: const SizedBox(),
                  isDense: true,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryBlue, fontSize: 14),
                  items: [2023, 2024, 2025, 2026].map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                  onChanged: (v) => setState(() => _selectedYear = v!),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // --- 1. COMPACT KPI GRID ---
            LayoutBuilder(
              builder: (context, constraints) {
                // If wide > 600, show 4 in a row. Else show 2x2.
                final int crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
                final double aspectRatio = constraints.maxWidth > 800 ? 2.2 : 1.6;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: aspectRatio,
                  children: [
                    _KpiCard(
                      title: "Total Orders",
                      value: metrics.totalOrders.toString(),
                      icon: Icons.assignment,
                      color: _primaryBlue,
                      trend: "+${metrics.ordersThisMonth} this month",
                    ),
                    _KpiCard(
                      title: "Upcoming",
                      value: metrics.upcomingTrips.length.toString(),
                      icon: Icons.flight_takeoff,
                      color: Colors.purple,
                      trend: "View Details >",
                      isClickable: true,
                      onTap: () => _showUpcomingOrdersDialog(context, metrics.upcomingTrips),
                    ),
                    _KpiCard(
                      title: "Unpaid",
                      value: metrics.unpaidCount.toString(),
                      icon: Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      trend: "Action needed",
                      isAlert: true,
                    ),
                    _KpiCard(
                      title: "Top Spot",
                      value: metrics.topDestination.isEmpty ? "-" : metrics.topDestination,
                      icon: Icons.place,
                      color: _accentOrange,
                      trend: "${metrics.topDestCount} visits",
                    ),
                  ],
                );
              }
            ),

            const SizedBox(height: 16),

            // --- 2. COMPACT CHARTS ---
            SizedBox(
              height: 220, // Reduced height for compactness
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Trend Chart
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      decoration: _boxDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Volume Trend", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Expanded(child: _buildLineChart(metrics.monthlyCounts)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Pie Chart
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _boxDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Destinations", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          Expanded(child: _buildPieChart(metrics.destinationCounts)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // --- LOGIC: DIALOG ---

  void _showUpcomingOrdersDialog(BuildContext context, List<QueryDocumentSnapshot> orders) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Upcoming Trips"),
        content: SizedBox(
          width: 400,
          height: 400,
          child: orders.isEmpty 
            ? const Center(child: Text("No upcoming trips found."))
            : ListView.separated(
                itemCount: orders.length,
                separatorBuilder: (_,__) => const Divider(),
                itemBuilder: (context, index) {
                  final data = orders[index].data() as Map<String, dynamic>;
                  final date = (data['startDate'] as Timestamp).toDate();
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.shade50,
                      child: Icon(Icons.flight, color: Colors.purple, size: 20),
                    ),
                    title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${data['destination'] ?? ''} • ${DateFormat('dd MMM').format(date)}"),
                    trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  );
                },
              ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  // --- LOGIC: METRICS ---

  _Metrics _calculateMetrics(List<QueryDocumentSnapshot> docs) {
    int total = 0;
    List<QueryDocumentSnapshot> upcomingList = [];
    int unpaid = 0;
    int thisMonth = 0;
    Map<String, int> dests = {};
    Map<int, int> monthly = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0, 8:0, 9:0, 10:0, 11:0, 12:0};
    
    final now = DateTime.now();
    // Normalize "now" to midnight for accurate day comparison if needed
    final today = DateTime(now.year, now.month, now.day); 

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final Timestamp? ts = data['startDate'] as Timestamp?;
      if (ts == null) continue;
      
      final date = ts.toDate();
      
      // Filter by selected year
      if (date.year == _selectedYear) {
        total++;
        monthly[date.month] = (monthly[date.month] ?? 0) + 1;
        if (date.month == now.month) thisMonth++;

        // Status Stats
        // Check if date is in the future (Upcoming)
        if (date.isAfter(today)) {
          upcomingList.add(doc);
        }

        if ((data['payment_status'] ?? '').toString().toLowerCase() == 'unpaid') unpaid++;

        String dest = data['destination'] ?? 'Unknown';
        dests[dest] = (dests[dest] ?? 0) + 1;
      }
    }

    // Sort upcoming list by date
    upcomingList.sort((a, b) {
      final d1 = (a['startDate'] as Timestamp).toDate();
      final d2 = (b['startDate'] as Timestamp).toDate();
      return d1.compareTo(d2);
    });

    // Top Destination
    String topDest = "";
    int topCount = 0;
    if (dests.isNotEmpty) {
      var entry = dests.entries.reduce((a, b) => a.value > b.value ? a : b);
      topDest = entry.key;
      topCount = entry.value;
    }

    return _Metrics(
      totalOrders: total,
      upcomingTrips: upcomingList,
      unpaidCount: unpaid,
      ordersThisMonth: thisMonth,
      topDestination: topDest,
      topDestCount: topCount,
      destinationCounts: dests,
      monthlyCounts: monthly,
    );
  }

  // --- CHARTS ---

  Widget _buildLineChart(Map<int, int> data) {
    List<FlSpot> spots = [];
    data.forEach((month, count) {
      spots.add(FlSpot(month.toDouble(), count.toDouble()));
    });

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                const months = ['J','F','M','A','M','J','J','A','S','O','N','D'];
                int index = val.toInt() - 1;
                if (index >= 0 && index < 12) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(months[index], style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  );
                }
                return const SizedBox();
              },
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _primaryBlue,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: _primaryBlue.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(Map<String, int> data) {
    if (data.isEmpty) return const Center(child: Text("No Data", style: TextStyle(fontSize: 10)));

    var sortedKeys = data.keys.toList()..sort((a, b) => data[b]!.compareTo(data[a]!));
    if (sortedKeys.length > 3) sortedKeys = sortedKeys.sublist(0, 3);

    List<Color> colors = [_primaryBlue, _accentOrange, Colors.teal, Colors.grey];
    int colorIdx = 0;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 20,
              sections: sortedKeys.map((key) {
                final color = colors[colorIdx++ % colors.length];
                return PieChartSectionData(
                  color: color,
                  value: data[key]!.toDouble(),
                  title: '',
                  radius: 25,
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sortedKeys.map((key) {
              final color = colors[sortedKeys.indexOf(key) % colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _textDark))),
                  ],
                ),
              );
            }).toList(),
          ),
        )
      ],
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    );
  }
}

// --- COMPACT KPI CARD ---

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final IconData icon;
  final Color color;
  final bool isAlert;
  final bool isClickable;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.icon,
    required this.color,
    this.isAlert = false,
    this.isClickable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isClickable ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12), // Reduced padding
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isAlert ? Border.all(color: Colors.red.shade200) : Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 18),
                if (isAlert) const Icon(Icons.circle, size: 6, color: Colors.red),
              ],
            ),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
              trend, 
              style: TextStyle(
                fontSize: 10, 
                color: isAlert ? Colors.red : (isClickable ? Colors.blue : Colors.green[700]), 
                fontWeight: FontWeight.bold
              ),
              maxLines: 1, 
              overflow: TextOverflow.ellipsis
            ),
          ],
        ),
      ),
    );
  }
}

// --- DATA CLASS ---

class _Metrics {
  final int totalOrders;
  final List<QueryDocumentSnapshot> upcomingTrips; // Changed to List
  final int unpaidCount;
  final int ordersThisMonth;
  final String topDestination;
  final int topDestCount;
  final Map<String, int> destinationCounts;
  final Map<int, int> monthlyCounts;

  _Metrics({
    required this.totalOrders,
    required this.upcomingTrips,
    required this.unpaidCount,
    required this.ordersThisMonth,
    required this.topDestination,
    required this.topDestCount,
    required this.destinationCounts,
    required this.monthlyCounts,
  });
}