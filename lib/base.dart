import 'package:crmx/calendar.dart';
import 'package:crmx/customers.dart';
import 'package:crmx/destinations.dart';
import 'package:crmx/finance.dart';
import 'package:crmx/forex.dart';
import 'package:crmx/hotels.dart';
import 'package:crmx/orders.dart';
import 'package:crmx/permission_service.dart'; // Import your new Service
import 'package:crmx/services_page.dart';
import 'package:crmx/teams.dart';
import 'package:crmx/tourguides.dart';
import 'package:crmx/transport.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Helper class to link ID, Title, Icon and the Widget Page
class _AppPageDef {
  final String id;
  final String title;
  final IconData icon;
  final Widget page;

  _AppPageDef(this.id, this.title, this.icon, this.page);
}

class Base extends StatefulWidget {
  const Base({super.key});

  @override
  State<Base> createState() => _BaseState();
}

class _BaseState extends State<Base> {
  int currentPageIndex = 0;
  bool _isLoadingPermissions = true;

  // 1. Define ALL possible pages here
  // IMPORTANT: The 'id' here must match the keys in PermissionService and Firestore exactly.
  final List<_AppPageDef> _allPages = [
    _AppPageDef('orders', 'Orders', Icons.chat_bubble_outline_rounded, Orders()),
    _AppPageDef('calendar', 'Calendar', Icons.calendar_today_rounded, CalendarPage()),
    _AppPageDef('finance', 'Finance', Icons.attach_money_rounded, FinanceDashboardPage()),
    _AppPageDef('destinations', 'Destinations', Icons.map_outlined, DestinationsDashboard()),
    _AppPageDef('team', 'Team', Icons.people_outline_rounded, TeamManagerPage()),
    _AppPageDef('services', 'Services', Icons.grid_view_rounded, ServicesPage()),
    _AppPageDef('customers', 'Customer', Icons.people, CustomersPage()),
    _AppPageDef('forex', 'Forex', Icons.currency_exchange, ForexPage()),
    _AppPageDef('tourguides', 'Tourguides', Icons.travel_explore, TourGuideProfilesPage()),
    _AppPageDef('transport', 'Transport', Icons.car_rental, TransportSuppliersPage()),
    _AppPageDef('hotels', 'Hotels', Icons.hotel, HotelDatabasePage()),
  ];

  // These lists will be populated based on permissions
  List<_AppPageDef> _authorizedPages = [];
  List<NavigationDestination> _destinations = [];

  @override
  void initState() {
    super.initState();
    _initPermissions();
  }

 Future<void> _initPermissions() async {
    // We create a temporary list to hold allowed pages
    List<_AppPageDef> allowed = [];

    // Loop through every page defined in your list
    for (var page in _allPages) {
      // AWAIT the check for each page
      bool hasAccess = await PermissionService().hasAccess(page.id);
      
      if (hasAccess) {
        allowed.add(page);
      }
    }

    if (!mounted) return;

    setState(() {
      _authorizedPages = allowed;
       print(_authorizedPages);
      // If no pages are allowed, handle empty state
      if (_authorizedPages.isEmpty) {
        // Optional: Log them out or show specific empty page
      }

      _generateDestinations();
      _isLoadingPermissions = false;
    });
  }

  void _generateDestinations() {
    _destinations = _authorizedPages.map((item) {
      return NavigationDestination(
        icon: Icon(item.icon),
        label: item.title,
      );
    }).toList();
  }

  Future<void> _handleLogout(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) context.go('/login'); // Assuming you use GoRouter
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error logging out: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPermissions) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Safety check: if user has no permissions
    if (_authorizedPages.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("Access Restricted", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Text("You do not have permission to view any pages."),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => _handleLogout(context), child: const Text("Log Out"))
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double mobileBreakpoint = 900;
        
        // Ensure index doesn't go out of bounds if permissions changed
        if (currentPageIndex >= _authorizedPages.length) {
          currentPageIndex = 0;
        }

        final currentPage = _authorizedPages[currentPageIndex].page;

        if (constraints.maxWidth < mobileBreakpoint) {
          // --- MOBILE LAYOUT ---
          return Scaffold(
            appBar: _narrowAppBar(),
            body: currentPage,
            bottomNavigationBar: NavigationBarTheme(
              data: NavigationBarThemeData(
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                indicatorColor: Theme.of(context).colorScheme.inverseSurface,
                labelTextStyle: WidgetStateProperty.all(
                  TextStyle(
                    color: Theme.of(context).colorScheme.inverseSurface,
                  ),
                ),
              ),
              child: NavigationBar(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                selectedIndex: currentPageIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    currentPageIndex = index;
                  });
                },
                destinations: _destinations,
              ),
            ),
          );
        } else {
          // --- DESKTOP LAYOUT ---
          return Scaffold(
            body: Row(
              children: [
                if (!kIsWeb)
                  Container(
                    width: 40,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                _buildSideMenu(context),
                Expanded(child: currentPage),
              ],
            ),
          );
        }
      },
    );
  }

  PreferredSizeWidget _narrowAppBar() {
    return AppBar(
      title: Text(_authorizedPages[currentPageIndex].title),
      backgroundColor: Theme.of(context).colorScheme.secondary,
      leading: IconButton(
        onPressed: () => context.replace('/'),
        icon: Icon(Icons.navigate_before,
            color: Theme.of(context).colorScheme.inversePrimary),
      ),
    );
  }

  Widget _buildSideMenu(BuildContext context) {
    return Container(
      width: 250,
      color: Theme.of(context).colorScheme.secondary,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Image.asset('assets/1.png', height: 80),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _authorizedPages.length,
              itemBuilder: (context, index) {
                final item = _authorizedPages[index];
                return _buildMenuItem(
                  title: item.title,
                  icon: item.icon,
                  isSelected: currentPageIndex == index,
                  onTap: () {
                    setState(() {
                      currentPageIndex = index;
                    });
                  },
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: () => _handleLogout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.logout),
              label: const Text("Log Out"),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Version 1.0.0'),
          )
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final textColor = isSelected
        ? Colors.white
        : Theme.of(context).colorScheme.inverseSurface;
    final iconColor = isSelected
        ? Colors.white
        : Theme.of(context).colorScheme.inverseSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}