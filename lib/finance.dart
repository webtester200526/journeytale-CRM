import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// Ensure this import points to your actual file location
import 'package:crmx/pdfEditor/orderFinances_editor.dart'; 

// ==========================================
// 1. DATA MODELS & CACHING
// ==========================================

enum TimeRange { week, month, year, all }

/// Helper to calculate revenue vs cost per currency for a single order
class OrderCurrencyStats {
  double revenue = 0;
  double cost = 0;
  double get profit => revenue - cost;
}

/// Helper to aggregate totals for the Overview Tab
class MultiCurrencyData {
  final Map<String, double> revenue = {};
  final Map<String, double> operationalExpenses = {};
  final Map<String, double> fixedExpenses = {};
  final Map<String, double> forexProfit = {}; 

  void addRevenue(String currency, double amount) {
    final c = _normalize(currency);
    revenue[c] = (revenue[c] ?? 0) + amount;
  }
   void addForexProfit(String currency, double amount) {
    final c = _normalize(currency);
    forexProfit[c] = (forexProfit[c] ?? 0) + amount;
  }


  void addOpExpense(String currency, double amount) {
    final c = _normalize(currency);
    operationalExpenses[c] = (operationalExpenses[c] ?? 0) + amount;
  }

  void addFixedExpense(String currency, double amount) {
    final c = _normalize(currency);
    fixedExpenses[c] = (fixedExpenses[c] ?? 0) + amount;
  }

  List<String> getAllCurrencies() {
    final Set<String> all = {};
    all.addAll(revenue.keys);
    all.addAll(operationalExpenses.keys);
    all.addAll(fixedExpenses.keys);
    all.addAll(forexProfit.keys);
    var list = all.toList();
    list.sort((a, b) {
      if (a == 'IDR') return -1; // IDR first
      if (b == 'IDR') return 1;
      return a.compareTo(b);
    });
    return list;
  }

  String _normalize(String c) {
    String res = c.toUpperCase().trim();
    if (res.isEmpty) return 'IDR';
    // Normalization for common variations
    if (res == 'CNY') return 'RMB';
    return res;
  }
}

class FinanceItem {
  final String id;
  final String title;
  final String subtitle;
  final DateTime date;
  final double amount;
  final String currency;
  final String type; // 'Income', 'Expense', 'Fixed'
  final String? receiptUrl;
  final String? orderId; 

  FinanceItem({
    required this.id, required this.title, required this.subtitle,
    required this.date, required this.amount, required this.currency,
    required this.type, this.receiptUrl,required this.orderId
  });
}

class FinanceSnapshot {
  // Actuals
  List<FinanceItem> incomes = [];
  List<FinanceItem> expenses = [];
  List<FinanceItem> fixedExpenses = [];
  
  // Projected Orders
  List<Map<String, dynamic>> orderProfitability = [];

  // Aggregated Totals
  MultiCurrencyData totals = MultiCurrencyData();
}

// Simple In-Memory Cache
class FinanceCache {
  static final Map<String, FinanceSnapshot> _cache = {};
  static String _getKey(TimeRange range, DateTime anchor) => "${range.index}_${anchor.year}_${anchor.month}_${anchor.day}";
  static FinanceSnapshot? get(TimeRange range, DateTime anchor) => _cache[_getKey(range, anchor)];
  static void set(TimeRange range, DateTime anchor, FinanceSnapshot data) => _cache[_getKey(range, anchor)] = data;
  static void invalidate() => _cache.clear();
}

// ==========================================
// 2. MAIN DASHBOARD PAGE
// ==========================================

class FinanceDashboardPage extends StatefulWidget {
  const FinanceDashboardPage({super.key});

  @override
  State<FinanceDashboardPage> createState() => _FinanceDashboardPageState();
}

class _FinanceDashboardPageState extends State<FinanceDashboardPage> with SingleTickerProviderStateMixin {
  //late TabController _tabController;
  int _selectedIndex = 0; 
  
  DateTime _anchorDate = DateTime.now();
  TimeRange _timeRange = TimeRange.month;
  
  // SEPARATE LOADING STATES
  bool _isMainLoading = true;   // For Overview, Cashflow, Fixed
  bool _isOrdersLoading = false; // For the heavy Orders tab
  
  FinanceSnapshot _data = FinanceSnapshot();

  @override
  void initState() {
    super.initState();
    //_tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  DateTimeRange _getDateRange() {
    DateTime now = _anchorDate;
    DateTime start, end;
    switch (_timeRange) {
      case TimeRange.week:
        start = now.subtract(Duration(days: now.weekday - 1));
        end = start.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
        break;
      case TimeRange.month:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case TimeRange.year:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case TimeRange.all:
        start = DateTime(2000);
        end = DateTime(2050);
        break;
    }
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day, 23, 59, 59, 999),
    );
  }

  Future<void> _fetchData({bool forceRefresh = false})  async {
    // 1. START LOADING MAIN DATA
     if (!forceRefresh) {
      final cached = FinanceCache.get(_timeRange, _anchorDate);
      if (cached != null) {
        // Fix: Use _isMainLoading, not _isLoading
        if (mounted) setState(() { _data = cached; _isMainLoading = false; });
        return;
      }
    }

    setState(() => _isMainLoading = true);
    
    final snapshot = FinanceSnapshot();
    final range = _getDateRange();
    

    try {
      // Fetch Actuals (Fast)
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('income').get(),
        FirebaseFirestore.instance.collection('expenses').get(),
        FirebaseFirestore.instance.collection('fixed_expenses').get(),
         FirebaseFirestore.instance.collection('currency').get(),
      ]);

      bool inRange(DateTime d) => d.isAfter(range.start) && d.isBefore(range.end);

      // --- Process Income ---
      for (var doc in results[0].docs) {
        final d = doc.data();
        DateTime date = (d['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        if (inRange(date)) {
          double amt = (d['amount'] as num?)?.toDouble() ?? 0;
          String cur = d['currency'] ?? 'IDR';
          snapshot.totals.addRevenue(cur, amt);
          snapshot.incomes.add(FinanceItem(id: doc.id, title: "Income", subtitle: d['comment'] ?? '', date: date, amount: amt, currency: cur, type: 'Income', receiptUrl: d['receiptUrl'], orderId: d['orderId'],));
        }
      }

      // --- Process Expenses ---
      for (var doc in results[1].docs) {
        final d = doc.data();
        DateTime date = (d['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        if (inRange(date)) {
          double amt = (d['amount'] as num?)?.toDouble() ?? 0;
          String cur = d['currency'] ?? 'IDR';
          snapshot.totals.addOpExpense(cur, amt);
          snapshot.expenses.add(FinanceItem(id: doc.id, title: "Expense", subtitle: d['comment'] ?? '', date: date, amount: amt, currency: cur, type: 'Expense', receiptUrl: d['receiptUrl'],orderId: d['orderId'] ));
        }
      }

      // --- Process Fixed Expenses ---
      for (var doc in results[2].docs) {
        final d = doc.data();
        DateTime date = (d['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        if (inRange(date)) {
          double amt = (d['amount'] as num?)?.toDouble() ?? 0;
          String cur = d['currency'] ?? 'IDR';
          snapshot.totals.addFixedExpense(cur, amt);
          snapshot.fixedExpenses.add(FinanceItem(id: doc.id, title: d['name'] ?? 'Fixed', subtitle: d['category'] ?? '', date: date, amount: amt, currency: cur, type: 'Fixed',orderId: '-'));
        }
      }
      for (var doc in results[3].docs) {
        final d = doc.data();
        DateTime date = (d['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        if (inRange(date)) {
          // Use 'base_currency' (profit currency). Default to IDR for old data.
          String cur = d['base_currency'] ?? 'IDR';
          
          // Use 'profit_amount' (new). Default to 'profit_idr' for old data.
          double profit = (d['profit_amount'] ?? d['profit_idr'] ?? 0).toDouble();
          
          if (profit != 0) {
            snapshot.totals.addForexProfit(cur, profit);
          }
        }
      }

      // Sort Lists
      snapshot.incomes.sort((a, b) => b.date.compareTo(a.date));
      snapshot.expenses.sort((a, b) => b.date.compareTo(a.date));
      snapshot.fixedExpenses.sort((a, b) => b.date.compareTo(a.date));

      FinanceCache.set(_timeRange, _anchorDate, snapshot);
      // UPDATE UI WITH MAIN DATA IMMEDIATELY
      if (mounted) {
        setState(() {
          _data = snapshot;
          _isMainLoading = false; // STOP SPINNER FOR MAIN TABS
        });
      }

      // 2. TRIGGER HEAVY ORDER FETCHING IN BACKGROUND
      _fetchProjectedOrders(snapshot, range);

    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) setState(() => _isMainLoading = false);
    }
  }

 Future<void> _fetchProjectedOrders(FinanceSnapshot snapshot, DateTimeRange range) async {
    // 1. CLEAR LIST & START
    debugPrint("--- START FETCHING ORDERS ---");
    debugPrint("Filter Range: ${range.start} to ${range.end}");
    
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('orders').get();
      debugPrint("Found ${querySnapshot.docs.length} documents in 'orders' collection.");

      List<Map<String, dynamic>> orders = [];

      for (var doc in querySnapshot.docs) {
        final d = doc.data();
        debugPrint("Processing Doc ID: ${doc.id}");

        // --- 2. ROBUST DATE PARSING ---
        DateTime startDate;
        try {
          if (d['startDate'] is Timestamp) {
            startDate = (d['startDate'] as Timestamp).toDate();
          } else if (d['startDate'] is String) {
            // Handle case where date was entered as text manually
            startDate = DateTime.parse(d['startDate']);
          } else {
            debugPrint(" -> SKIPPING: 'startDate' is missing or invalid format.");
            continue;
          }
        } catch (e) {
          debugPrint(" -> SKIPPING: Date parsing error: $e");
          continue;
        }

        debugPrint(" -> Date: $startDate");

        // --- 3. FILTER CHECK ---
        if (startDate.isBefore(range.start) || startDate.isAfter(range.end)) {
          debugPrint(" -> SKIPPING: Date is outside selected TimeRange.");
          continue;
        }

        // --- 4. FETCH SUBCOLLECTIONS (SAFE MODE) ---
        // We use try-catch inside the wait so one bad collection doesn't crash the whole row
        List<QuerySnapshot> subs = [];
        try {
          subs = await Future.wait([
            doc.reference.collection('services').get(),      
            doc.reference.collection('transport').get(),     
            doc.reference.collection('hotels').get(),        
            doc.reference.collection('flights').get(),       
            doc.reference.collection('trains').get(),        
            doc.reference.collection('tickets').get(),       
            doc.reference.collection('tourguides').get(),    
            doc.reference.collection('additional').get(),    
          ]);
        } catch (e) {
          debugPrint(" -> ERROR reading subcollections: $e");
          // Proceed with empty lists so the order still shows up
          subs = List.generate(8, (_) =>  const _MockQuerySnapshot()); 
        }

        // --- 5. CALCULATE FINANCIALS ---
        final Map<String, OrderCurrencyStats> financials = {};

        void add(String? curr, double rev, double exp) {
          String c = (curr ?? 'RMB').toUpperCase().trim();
          if (c.isEmpty) c = 'RMB';
          if (!financials.containsKey(c)) financials[c] = OrderCurrencyStats();
          financials[c]!.revenue += rev;
          financials[c]!.cost += exp;
        }

        // Helper to safely get double from mixed number types
        double getDouble(dynamic val) {
          if (val == null) return 0.0;
          if (val is int) return val.toDouble();
          if (val is double) return val;
          if (val is String) return double.tryParse(val) ?? 0.0;
          return 0.0;
        }

        // Services
        for (var i in subs[0].docs) {
          final data = i.data() as Map<String, dynamic>;
          double days = getDouble(data['days'] ?? 1);
          double cost = getDouble(data['modal_per_day']);
          double price = getDouble(data['price_per_day']);
          double disc = getDouble(data['discount']);
          add(data['currency'], (price * days) - disc, cost * days);
        }
        // Transport
        for (var i in subs[1].docs) {
          final data = i.data() as Map<String, dynamic>;
          add(data['currency'], getDouble(data['fee']), getDouble(data['cost']));
        }
        // Hotels
        for (var i in subs[2].docs) {
          final data = i.data() as Map<String, dynamic>;
          double nights = getDouble(data['nights'] ?? 1);
          add(data['currency'], getDouble(data['client_price']), getDouble(data['base_price']) * nights);
        }
        // Flights
        for (var i in subs[3].docs) {
           final data = i.data() as Map<String, dynamic>;
           add(data['currency'], getDouble(data['client_price']), getDouble(data['internal_price']));
        }
        // Trains
        for (var i in subs[4].docs) {
           final data = i.data() as Map<String, dynamic>;
           add(data['currency'], getDouble(data['client_price']), getDouble(data['internal_price']));
        }
        // Tickets
        for (var i in subs[5].docs) {
           final data = i.data() as Map<String, dynamic>;
           add(data['currency'], getDouble(data['total_price']), getDouble(data['total_cost']));
        }
        // Tour Guides
        for (var i in subs[6].docs) {
           final data = i.data() as Map<String, dynamic>;
           add(data['currency'], getDouble(data['client_price']), getDouble(data['internal_price']));
        }
        // Additional
        for (var i in subs[7].docs) {
           final data = i.data() as Map<String, dynamic>;
           add(data['currency'], getDouble(data['amount']), getDouble(data['cost']));
        }

        orders.add({
          'id': doc.id,
          'name': d['name'] ?? 'Unnamed Order',
          'startDate': startDate,
          'status': d['payment_status'] ?? 'unpaid',
          'pax': d['pax'] ?? 0,
          'financials': financials, 
        });
        
        debugPrint(" -> ADDED: ${d['name']}");
      }

      // Sort
      orders.sort((a, b) => b['startDate'].compareTo(a['startDate']));

      snapshot.orderProfitability = orders;
      if (mounted) setState(() {}); 
      debugPrint("--- FINISHED: ${orders.length} orders added ---");

    } catch (e) {
      debugPrint("FATAL ERROR in _fetchProjectedOrders: $e");
    } finally {
      if (mounted) setState(() => _isOrdersLoading = false);
    }
  }



  void _onDatePicked() async {
    final picked = await showDatePicker(
      context: context, initialDate: _anchorDate,
      firstDate: DateTime(2020), lastDate: DateTime(2030)
    );
    if(picked != null) {
      setState(() => _anchorDate = picked);
      _fetchData();
    }
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      // Use a Row to put Sidebar next to Content
      body: Row(
        children: [
          // ==============================
          // 1. LEFT SIDEBAR
          // ==============================
          Container(
            width: 250,
            color: Colors.white,
            child: Column(
              children: [
                const SizedBox(height: 32),
                // App Logo / Title
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(Icons.pie_chart, color: Colors.blue, size: 28),
                      SizedBox(width: 12),
                      Text("Finance", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Menu Items
                _SidebarItem(
                  icon: Icons.dashboard_outlined,
                  label: "Overview",
                  isActive: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _SidebarItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: "Cash Flow",
                  isActive: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _SidebarItem(
                  icon: Icons.receipt_long_outlined,
                  label: "Fixed Costs",
                  isActive: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _SidebarItem(
                  icon: Icons.cases_outlined,
                  label: "Orders Finances",
                  isActive: _selectedIndex == 3,
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
              ],
            ),
          ),

          // ==============================
          // 2. RIGHT CONTENT AREA
          // ==============================
          Expanded(
            child: Scaffold(
              // The AppBar moves here so it sits on top of the content, not the sidebar
              backgroundColor: const Color(0xFFF3F4F6),
              appBar: AppBar(
                //title: Text(_getPageTitle(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black)),
                backgroundColor: Colors.white,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.black),
                actions: [
                  DropdownButton<TimeRange>(
                    value: _timeRange,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                    items: const [
                       DropdownMenuItem(value: TimeRange.week, child: Text("This Week")),
                       DropdownMenuItem(value: TimeRange.month, child: Text("This Month")),
                       DropdownMenuItem(value: TimeRange.year, child: Text("This Year")),
                       DropdownMenuItem(value: TimeRange.all, child: Text("All Time")),
                    ],
                    onChanged: (v) {
                      if(v != null) {
                        setState(() => _timeRange = v);
                        _fetchData();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(onPressed: _onDatePicked, icon: const Icon(Icons.calendar_month)),
                  IconButton(onPressed: () { FinanceCache.invalidate(); _fetchData(); }, icon: const Icon(Icons.refresh)),
                  const SizedBox(width: 16),
                ],
              ),
              // Switch the body based on index
              body: _isMainLoading 
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(0),
                    child: _getSelectedView(),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to switch views
 Widget _getSelectedView() {
    switch (_selectedIndex) {
      case 0: 
        return _OverviewTab(data: _data);
        
      case 1: 
        return _CashFlowTab(
          data: _data, 
          // FIX: Call _fetchData with forceRefresh: true
          onRefresh: () => _fetchData(forceRefresh: true)
        );
        
      case 2: 
        return _FixedCostsTab(
          items: _data.fixedExpenses, 
          // FIX: Call _fetchData with forceRefresh: true
          onRefresh: () => _fetchData(forceRefresh: true)
        );
        
      case 3: 
        return _ProjectedOrdersTab(
          orders: _data.orderProfitability, 
          isLoading: _isOrdersLoading
        );
        
      default: return Container();
    }
  }

  // Helper for Title
  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0: return "Financial Overview";
      case 1: return "Income & Expenses";
      case 2: return "Fixed Costs Management";
      case 3: return "Projected Order Profits";
      default: return "";
    }
  }
}

// ==========================================
// 3. TAB: OVERVIEW (Multi-Currency Cards)
// ==========================================

class _OverviewTab extends StatelessWidget {
  final FinanceSnapshot data;
  const _OverviewTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final currencies = data.totals.getAllCurrencies();

    if (currencies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monetization_on_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No financial data for this period", style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        //const Text("Currency Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        ...currencies.map((c) => _CurrencyOverviewCard(
            currency: c,
            revenue: data.totals.revenue[c] ?? 0,
            opExp: data.totals.operationalExpenses[c] ?? 0,
            fixedExp: data.totals.fixedExpenses[c] ?? 0,
            forexProfit: data.totals.forexProfit[c] ?? 0, 
        )),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.amberAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isActive ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 12),
            Text(
              label, 
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[700],
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 14
              )
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyOverviewCard extends StatelessWidget {
  final String currency;
  final double revenue;
  final double opExp;
  final double fixedExp;
  final double forexProfit;

  const _CurrencyOverviewCard({
    required this.currency,
    required this.revenue,
    required this.opExp,
    required this.fixedExp,
    required this.forexProfit,
  });

  @override
  Widget build(BuildContext context) {
    final double totalExp = opExp + fixedExp;
    final double profit = (revenue + forexProfit) - totalExp;
    
    // Formatting
    final fmt = NumberFormat.currency(
      symbol: currency == 'IDR' ? 'Rp ' : (currency == 'RMB' ? '¥ ' : '\$ '),
      decimalDigits: 0,
      locale: 'en_US', 
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 15, 
            offset: const Offset(0, 5)
          )
        ],
      ),
      child: Column(
        children: [
          // 1. HEADER ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                    child: Text(
                      currency.substring(0, 1), 
                      style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(currency, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
              // Net Profit Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: profit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: profit >= 0 ? Colors.green.shade100 : Colors.red.shade100)
                ),
                child: Row(
                  children: [
                    Text(
                      "NET: ", 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: profit >= 0 ? Colors.green.shade800 : Colors.red.shade800)
                    ),
                    Text(
                      "${profit >= 0 ? '+' : ''}${fmt.format(profit)}",
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: profit >= 0 ? Colors.green.shade800 : Colors.red.shade800),
                    ),
                  ],
                ),
              )
            ],
          ),
          
          const SizedBox(height: 24),

          // 2. MAIN CONTENT SPLIT (Stats Left | Chart Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT SIDE: STATS LIST
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Income Section
                    _StatRow(
                      icon: Icons.attach_money, 
                      color: Colors.green, 
                      label: "Revenue", 
                      value: fmt.format(revenue)
                    ),
                    const SizedBox(height: 12),
                    _StatRow(
                      icon: Icons.currency_exchange, 
                      color: Colors.teal, 
                      label: "Forex Gain", 
                      value: fmt.format(forexProfit)
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                    
                    // Expenses Section
                    _StatRow(
                      icon: Icons.work_outline, 
                      color: Colors.amber, 
                      label: "Op. Expenses", 
                      value: fmt.format(opExp)
                    ),
                    const SizedBox(height: 12),
                    _StatRow(
                      icon: Icons.business, 
                      color: Colors.purple, 
                      label: "Fixed Costs", 
                      value: fmt.format(fixedExp)
                    ),
                    
                    const SizedBox(height: 16),
                    // Total Costs Summary
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total Outgoing (Expenses)", style: TextStyle(color: Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(fmt.format(totalExp), style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(width: 32),

              // RIGHT SIDE: CHART & LEGEND
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    if (totalExp > 0 || revenue > 0 || forexProfit > 0)
                      SizedBox(
                        height: 160,
                        child: Stack(
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 4,
                                centerSpaceRadius: 40,
                                sections: [
                                  if (opExp > 0) PieChartSectionData(color: Colors.amber, value: opExp, radius: 15, showTitle: false),
                                  if (fixedExp > 0) PieChartSectionData(color: Colors.purple, value: fixedExp, radius: 15, showTitle: false),
                                  if (forexProfit > 0) PieChartSectionData(color: Colors.teal, value: forexProfit, radius: 15, showTitle: false),
                                  if ((profit - forexProfit) > 0) PieChartSectionData(color: Colors.grey.shade300, value: (profit - forexProfit), radius: 15, showTitle: false),
                                ],
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Profit Margin", style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                  Text(
                                    "${((profit / (revenue + forexProfit + 0.001)) * 100).clamp(-100, 100).toStringAsFixed(1)}%",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      )
                    else 
                       const SizedBox(height: 160, child: Center(child: Text("No Data", style: TextStyle(color: Colors.grey)))),

                    const SizedBox(height: 16),
                    // Legend
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _LegendDot("Rev", Colors.green),
                        _LegendDot("Forex", Colors.teal),
                        _LegendDot("Op", Colors.amber),
                        _LegendDot("Fixed", Colors.purple),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Helper Widget for Stats Rows
class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatRow({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        )
      ],
    );
  }
}

// Helper Widget for Legend
class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
// ==========================================
// 4. TAB: CASH FLOW 
// ==========================================

class _CashFlowTab extends StatelessWidget {
  final FinanceSnapshot data;
  final VoidCallback onRefresh; // Added callback

  const _CashFlowTab({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    // Combine all lists
    final all = [...data.incomes, ...data.expenses, ...data.fixedExpenses];
    
    // Sort by Date (Newest first)
    all.sort((a,b) => b.date.compareTo(a.date));

    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text("No transactions found", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: all.length,
      itemBuilder: (ctx, i) => _DetailCashFlowCard(
        item: all[i],
        onRefresh: onRefresh,
      ),
    );
  }
}

// ==========================================
// NEW DETAILED CARD UI
// ==========================================

class _DetailCashFlowCard extends StatelessWidget {
  final FinanceItem item;
  final VoidCallback onRefresh;

  const _DetailCashFlowCard({required this.item, required this.onRefresh});

  Future<void> _deleteItem(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Record"),
        content: const Text("Are you sure? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    String collection = item.type == 'Income' ? 'income' : (item.type == 'Fixed' ? 'fixed_expenses' : 'expenses');

    try {
      await FirebaseFirestore.instance.collection(collection).doc(item.id).delete();
      onRefresh();
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isIncome = item.type == 'Income';
    final fmt = NumberFormat.currency(
      symbol: item.currency == 'IDR' ? 'Rp ' : (item.currency == 'RMB' ? '¥ ' : '\$ '),
      decimalDigits: 0,
    );
    final dateStr = DateFormat('dd MMM, HH:mm').format(item.date);

    // GENERATE INVOICE ID STRING
    String? invoiceLabel;
    if (item.orderId != null && item.orderId!.length >= 6) {
      invoiceLabel = "INV-${item.orderId!.substring(0, 6).toUpperCase()}";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ICON BOX
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isIncome ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward, 
                  color: isIncome ? Colors.green : Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // 2. TEXT DETAILS
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Invoice Badge Row
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          item.title.isNotEmpty ? item.title : (isIncome ? "Income" : "Expense"),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (invoiceLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey[300]!)
                            ),
                            child: Text(
                              invoiceLabel, 
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)
                            ),
                          )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(dateStr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    
                    // COMMENT FIELD (Subtitle)
                    if (item.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(6)
                        ),
                        child: Text(
                          item.subtitle, 
                          style: TextStyle(color: Colors.grey[800], fontSize: 13, fontStyle: FontStyle.italic)
                        ),
                      ),
                    ]
                  ],
                ),
              ),

              // 3. AMOUNT
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt.format(item.amount), 
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[100], 
                      borderRadius: BorderRadius.circular(4)
                    ),
                    child: Text(
                      item.currency, 
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)
                    ),
                  )
                ],
              )
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // FOOTER: RECEIPT & DELETE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (item.receiptUrl != null && item.receiptUrl!.isNotEmpty)
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: InteractiveViewer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(item.receiptUrl!),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt, size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text("View Receipt", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                      ],
                    ),
                  ),
                )
              else
                const Text("No receipt", style: TextStyle(fontSize: 12, color: Colors.grey)),

              InkWell(
                onTap: () => _deleteItem(context),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
                      const SizedBox(width: 4),
                      Text("Delete", style: TextStyle(fontSize: 12, color: Colors.red.shade300, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
// ==========================================
// 5. TAB: FIXED COSTS
// ==========================================

class _FixedCostsTab extends StatelessWidget {
  final List<FinanceItem> items;
  final VoidCallback onRefresh;
  const _FixedCostsTab({required this.items, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () => showDialog(context: context, builder: (ctx) => _AddFixedExpenseDialog(onSuccess: onRefresh)),
        child: const Icon(Icons.add),
      ),
      body: items.isEmpty ? _emptyState() : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _FinanceListCard(
          item: items[i], isFixed: true,
         onDelete: () async {
          final bool? confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirm Deletion'),
              content: const Text(
                'Are you sure you want to delete this item? This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );

          if (confirmed != true) return;

          await FirebaseFirestore.instance
              .collection('fixed_expenses')
              .doc(items[i].id)
              .delete();

          onRefresh();
        },

        ),
      ),
    );
  }
}

// ==========================================
// 6. TAB: PROJECTED ORDERS (With Filter & Multi-Currency)
// ==========================================



class _ProjectedOrdersTab extends StatefulWidget {
  final List<Map<String, dynamic>> orders;
  final bool isLoading;

  const _ProjectedOrdersTab({required this.orders, required this.isLoading});

  @override
  State<_ProjectedOrdersTab> createState() => _ProjectedOrdersTabState();
}

class _ProjectedOrdersTabState extends State<_ProjectedOrdersTab> {
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Analyzing orders...", style: TextStyle(color: Colors.grey)),
        ],
      ));
    }

    // 1. FILTER LOGIC: Treat 'downpayment' exactly like 'pending'
    final filtered = widget.orders.where((o) {
      if (_statusFilter == 'All') return true;
      String s = (o['status'] ?? 'unpaid').toString().toLowerCase();
      
      if (_statusFilter == 'Down Payment') {
        return s == 'pending' || s == 'downpayment';
      }
      return s == _statusFilter.toLowerCase();
    }).toList();

    return Column(
      children: [
        // Status Filter Bar

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // More vertical padding
          child: Row(
            children: ['All', 'Paid', 'Down Payment', 'Unpaid', 'Refunded'].map((f) {
              final isSel = _statusFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f),
                  selected: isSel,
                  onSelected: (v) => setState(() => _statusFilter = f),
                  backgroundColor: Colors.white,
                  selectedColor: Colors.blue,
                  labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.black12)),
                ),
              );
            }).toList(),
          ),
        ),
        
        // Orders List
        Expanded(
          child: filtered.isEmpty 
          ? Center(child: Text("No $_statusFilter orders found in this range", style: TextStyle(color: Colors.grey[400]))) 
          : ListView.builder(
              padding: const EdgeInsets.all(20), // Increased outer padding
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                 final o = filtered[i];
                 final rawStatus = (o['status'] ?? 'unpaid').toString().toLowerCase();
                 final statusDisplay = rawStatus.toUpperCase();
                 final financials = o['financials'] as Map<String, OrderCurrencyStats>;
                 
                 // 2. COLOR LOGIC: Downpayment gets Orange
                 Color sColor = Colors.red;
                 if (rawStatus == 'paid') sColor = Colors.green;
                 else if (rawStatus == 'pending' || rawStatus == 'downpayment') sColor = Colors.amber;
                 else if (rawStatus == 'refunded') sColor = Colors.grey;

                 return Card(
                  margin: const EdgeInsets.only(bottom: 20), // More space between cards
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 3, // Slightly higher shadow
                  shadowColor: Colors.black12,
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InternalReportPdfEditor(orderId: o['id']))),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(24), // BIGGER PADDING INSIDE CARD
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(o['name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), // Bigger Title
                                    const SizedBox(height: 6),
                                    Text("${DateFormat('dd MMM yyyy').format(o['startDate'])} • ${o['pax']} Pax", style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: sColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text(statusDisplay, style: TextStyle(color: sColor, fontSize: 11, fontWeight: FontWeight.w800)),
                              )
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          const Divider(height: 1, color: Colors.black12),
                          const SizedBox(height: 16),

                          // FINANCIAL BREAKDOWN GRID
                          if (financials.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text("No financial data available", style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey)),
                            )
                          else
                            Wrap(
                              spacing: 12, // More space between chips
                              runSpacing: 12,
                              children: financials.entries.map((e) {
                                return _OrderCurrencyChip(currency: e.key, stats: e.value);
                              }).toList(),
                            )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        )
      ],
    );
  }
}

class _OrderCurrencyChip extends StatelessWidget {
  final String currency;
  final OrderCurrencyStats stats;

  const _OrderCurrencyChip({required this.currency, required this.stats});

  @override
  Widget build(BuildContext context) {
    // 3. NUMBER FORMATTING: No more 'K'. Use commas.
    final fmt = NumberFormat.decimalPattern('en_US'); 
    final profit = stats.profit;
    final isProfitable = profit >= 0;

    return Container(
      width: 150, // MUCH WIDER to fit full numbers
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50], 
        borderRadius: BorderRadius.circular(10), 
        border: Border.all(color: Colors.grey[200]!)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currency, 
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black45)
          ),
          const SizedBox(height: 8),
          _row("Revenue", fmt.format(stats.revenue), Colors.black87),
          const SizedBox(height: 4),
          _row("Cost", fmt.format(stats.cost), Colors.red[300]!),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(height: 1, color: Colors.black12),
          ),
          _row("Net Profit", fmt.format(profit), isProfitable ? Colors.green[700]! : Colors.red[700]!, isBold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String val, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        Flexible( // Ensures large numbers don't overflow, they scale down slightly if needed
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              val, 
              style: TextStyle(
                fontSize: 12, // Bigger font
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, 
                color: color
              )
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 7. SHARED: LIST CARD & DIALOG
// ==========================================

class _FinanceListCard extends StatelessWidget {
  final FinanceItem item;
  final bool isFixed;
  final VoidCallback? onDelete;

  const _FinanceListCard({required this.item, this.isFixed = false, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final bool isInc = item.type == 'Income';
    final fmt = NumberFormat.currency(
      symbol: item.currency == 'IDR' ? 'Rp ' : (item.currency == 'RMB' ? '¥ ' : '\$ '),
      decimalDigits: 0
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: isInc ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: Icon(isInc ? Icons.arrow_downward : Icons.arrow_upward, color: isInc ? Colors.green : Colors.red, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("${item.subtitle} • ${DateFormat('dd MMM').format(item.date)}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt.format(item.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
              if (isFixed && onDelete != null)
                InkWell(onTap: onDelete, child: const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.delete, size: 16, color: Colors.red)))
          ])
        ],
      ),
    );
  }
}

class _AddFixedExpenseDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const _AddFixedExpenseDialog({required this.onSuccess});

  @override
  State<_AddFixedExpenseDialog> createState() => _AddFixedExpenseDialogState();
}

class _AddFixedExpenseDialogState extends State<_AddFixedExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _customCategoryCtrl = TextEditingController(); // NEW: Controller for custom input

  String _currency = 'IDR';
  String _category = 'Office'; // Default selection
  DateTime _selectedDate = DateTime.now();
  
  bool _isSubmitting = false;
  bool _isCustomCategory = false; // NEW: Toggle state

  final List<String> _categories = ['Office', 'Rent', 'Salaries', 'Marketing', 'Software', 'Utilities', 'Other'];
  final List<String> _currencies = [
  'IDR', // Indonesian Rupiah
  'RMB', // Chinese Yuan
  'EUR', // Euro
  'USD', // US Dollar
  'SGD', // Singapore Dollar
  'MYR', // Malaysian Ringgit
  'JPY', // Japanese Yen
  'CHF', // Swiss Franc
  'KRW', // South Korean Won
  'TWD', // New Taiwan Dollar
  'HKD', // Hong Kong Dollar
  'MOP', // Macanese Pataca
  'AUD', // Australian Dollar
];


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    // Logic to determine final category
    String finalCategory = _isCustomCategory ? _customCategoryCtrl.text.trim() : _category;
    if (finalCategory.isEmpty) finalCategory = "General";

    try {
      await FirebaseFirestore.instance.collection('fixed_expenses').add({
        'name': _nameCtrl.text.trim(),
        'amount': double.parse(_amountCtrl.text.replaceAll(',', '')),
        'currency': _currency,
        'category': finalCategory, // Use the resolved category
        'date': Timestamp.fromDate(_selectedDate),
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        widget.onSuccess();
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 5,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("New Fixed Expense", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 20, color: Colors.grey),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),

              // AMOUNT INPUT
              const Text("AMOUNT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: _dec("0.00", icon: Icons.attach_money),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              
              const SizedBox(height: 16),

              // CURRENCY CHIPS
          
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _currencies.map((c) {
                  final bool isSelected = _currency == c;
                  return InkWell(
                    onTap: () => setState(() => _currency = c),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        c,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),


              const SizedBox(height: 20),
              const Text("DETAILS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
              const SizedBox(height: 8),

              // DESCRIPTION
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: _dec("Description", icon: Icons.description_outlined),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              
              const SizedBox(height: 12),

              // CATEGORY (With Toggle)
              Row(
                children: [
                  Expanded(
                    child: _isCustomCategory
                      // CUSTOM TEXT INPUT
                      ? TextFormField(
                          controller: _customCategoryCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _dec("Type Custom Category", icon: Icons.category),
                          validator: (v) => _isCustomCategory && v!.isEmpty ? 'Required' : null,
                        )
                      // DROPDOWN LIST
                      : DropdownButtonFormField<String>(
                          value: _category,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                          decoration: _dec("Category", icon: Icons.category_outlined),
                          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (v) => setState(() => _category = v!),
                        ),
                  ),
                  const SizedBox(width: 8),
                  // TOGGLE BUTTON
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isCustomCategory = !_isCustomCategory;
                        if (_isCustomCategory) {
                          _customCategoryCtrl.text = ""; // Clear when switching to custom
                        }
                      });
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                      child: Icon(
                        _isCustomCategory ? Icons.list : Icons.edit, 
                        size: 18, 
                        color: Colors.black87
                      ),
                    ),
                    tooltip: _isCustomCategory ? "Select from list" : "Type custom category",
                  )
                ],
              ),

              const SizedBox(height: 12),

              // DATE PICKER
              InkWell(
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Colors.black)),
                      child: child!,
                    ),
                  );
                  if (p != null) setState(() => _selectedDate = p);
                },
                child: InputDecorator(
                  decoration: _dec("", icon: Icons.calendar_today_outlined),
                  child: Text(DateFormat('MMM dd, yyyy').format(_selectedDate), style: const TextStyle(fontSize: 14)),
                ),
              ),

              const SizedBox(height: 32),

              // SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                 
                  child: _isSubmitting 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("Save Expense", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, {required IconData icon}) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 20, color: Colors.grey[500]),
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12, width: 1)),
  );
}

Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox, size: 40, color: Colors.grey[300]), const Text("No records", style: TextStyle(color: Colors.grey))]));


// Helper class to prevent crashes if subcollection fetch fails
class _MockQuerySnapshot implements QuerySnapshot {
  const _MockQuerySnapshot();
  @override
  List<QueryDocumentSnapshot> get docs => [];
  @override
  int get size => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}