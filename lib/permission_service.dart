import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PermissionService {
  // Singleton Pattern
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// The Core Logic: Fetches fresh data every time you ask.
  Future<bool> _check(String pageId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      if (!doc.exists || doc.data() == null) return false;
      final data = doc.data()!;

     

      // 2. Check Permissions Array
      final List<dynamic> permissions = data['permissions'] ?? [];
      return permissions.contains(pageId);

    } catch (e) {
      // print("Permission Check Error: $e");
      return false;
    }
  }

  // =========================================================
  //  ASYNC GETTERS (Use these with 'await')
  // =========================================================

  Future<bool> get canAccessOrders       => _check('orders');
  Future<bool> get canAccessCalendar     => _check('calendar');
  Future<bool> get canAccessFinance      => _check('finance');
  Future<bool> get canAccessDestinations => _check('destinations');
  Future<bool> get canAccessTeam         => _check('team');
  Future<bool> get canAccessServices     => _check('services');
  Future<bool> get canAccessCustomers    => _check('customers');
  Future<bool> get canAccessForex        => _check('forex');
  Future<bool> get canAccessTourGuides   => _check('tourguides');
  Future<bool> get canAccessTransport    => _check('transport');
  Future<bool> get canAccessHotels       => _check('hotels');
  
  // Generic helper if you have dynamic keys
  Future<bool> hasAccess(String key)     => _check(key);
}