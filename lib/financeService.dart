
import 'package:cloud_firestore/cloud_firestore.dart';
class OrderFinancials {
  // Maps: Key = Currency Code (e.g., "USD"), Value = Total Amount
  final Map<String, double> income;
  final Map<String, double> expenses;
  final List<TransactionItem> history;

  OrderFinancials({
    required this.income,
    required this.expenses,
    required this.history,
  });

  factory OrderFinancials.fromMap(Map<String, dynamic> data) {
    return OrderFinancials(
      // Safely convert JSON Map to Map<String, double>
      income: _parseCurrencyMap(data['income']),
      expenses: _parseCurrencyMap(data['expenses']),
      
      // Parse the log array
      history: (data['transactionLog'] as List<dynamic>? ?? [])
          .map((item) => TransactionItem.fromMap(item))
          .toList(),
    );
  }

  // Helper to safely parse the currency maps
  static Map<String, double> _parseCurrencyMap(dynamic mapData) {
    if (mapData == null) return {};
    final Map<String, dynamic> map = mapData as Map<String, dynamic>;
    // Convert all values to double (handles int/double from Firestore)
    return map.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }
}

class TransactionItem {
  final String type;
  final double amount;
  final String currency;
  final String description;
  final DateTime timestamp;

  TransactionItem({
    required this.type,
    required this.amount,
    required this.currency,
    required this.description,
    required this.timestamp,
  });

  factory TransactionItem.fromMap(Map<String, dynamic> data) {
    return TransactionItem(
      type: data['type'] ?? '',
      amount: (data['amount'] as num).toDouble(),
      currency: data['currency'] ?? '',
      description: data['description'] ?? '',
      timestamp: DateTime.parse(data['timestamp']),
    );
  }
}




class FinancialService {
  final CollectionReference _ordersRef =
      FirebaseFirestore.instance.collection('orders');

  /// Adds an INCOME transaction.
  /// Updates the total for the specific currency and adds a log entry.
  Future<void> addIncome({
    required String orderId,
    required String currency,
    required double amount,
    String description = "Income adjustment",
  }) async {
    await _recordTransaction(
      orderId: orderId,
      fieldCategory: 'income', // Matches your map field name
      currency: currency,
      amount: amount,
      description: description,
    );
  }

  /// Adds an EXPENSE transaction.
  /// Updates the total for the specific currency and adds a log entry.
  Future<void> addExpense({
    required String orderId,
    required String currency,
    required double amount,
    String description = "Expense adjustment",
  }) async {
    await _recordTransaction(
      orderId: orderId,
      fieldCategory: 'expenses', // Matches your map field name
      currency: currency,
      amount: amount,
      description: description,
    );
  }

  /// Private helper method to reduce code duplication
  Future<void> _recordTransaction({
    required String orderId,
    required String fieldCategory, // 'income' or 'expenses'
    required String currency,
    required double amount,
    required String description,
  }) async {
    // Normalize currency to uppercase to prevent "usd" vs "USD" duplicates
    final String isoCurrency = currency.toUpperCase();

    try {
      // 1. Target the specific document
      final docRef = _ordersRef.doc(orderId);

      // 2. Atomic Update
      await docRef.update({
        // TARGET SPECIFIC MAP KEY: e.g., "income.USD" or "expenses.EUR"
        // If the currency key doesn't exist, Firebase creates it automatically.
        '$fieldCategory.$isoCurrency': FieldValue.increment(amount),

        // OPTIONAL: Add a detailed log to an array so you have a history
        'transactionLog': FieldValue.arrayUnion([
          {
            'type': fieldCategory, // 'income' or 'expenses'
            'amount': amount,
            'currency': isoCurrency,
            'description': description,
            'timestamp': DateTime.now().toIso8601String(),
          }
        ])
      });
    } catch (e) {
      // Handle errors (e.g., document doesn't exist)
      print("Error recording transaction: $e");
      rethrow;
    }
  }

  /// Get a Stream of the financials for real-time UI updates
  Stream<OrderFinancials> getFinancialsStream(String orderId) {
    return _ordersRef.doc(orderId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception("Order not found");
      }
      return OrderFinancials.fromMap(snapshot.data() as Map<String, dynamic>);
    });
  }
}