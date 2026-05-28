import 'package:cloud_firestore/cloud_firestore.dart';

// --- ENUMS ---
enum PaymentStatus { paid, unpaid, DownPayment }
enum TripStatus { upcoming, ongoing, finished, cancelled }

// --- SERVICE MODEL ---
// service_model.dart
class ServiceModel {
  final String id;
  final String name;
  final String category; // <--- NEW FIELD
  final double pricePerDay;
  final double costPerDay;
  final String description;
  final String currency;

  ServiceModel({
    required this.id,
    required this.name,
    required this.category, // <--- Add to constructor
    required this.pricePerDay,
    required this.costPerDay,
    required this.description,
    required this.currency,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category, // <--- Add to map
      'pricePerDay': pricePerDay,
      'costPerDay': costPerDay,
      'description': description,
      'currency':currency,
    };
  }

  factory ServiceModel.fromMap(Map<String, dynamic> map, String id) {
    return ServiceModel(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? 'Uncategorized', // <--- Add from map (default if null)
      pricePerDay: (map['pricePerDay'] ?? 0).toDouble(),
      costPerDay: (map['costPerDay'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      currency: map['currency'] ?? 'IDR'
    );
  }
}



// --- ITINERARY ITEM MODEL ---
class ItineraryItem {
  final String id;

  final String description;
  final String location;

  ItineraryItem({required this.id, required this.description, required this.location});

  Map<String, dynamic> toMap() => {
   
    'description': description,
    'location': location,
  };
}


// --- DESTINATION MODEL (The City) ---
class DestinationModel {
  final String id;
  final String name; // e.g., "Tokyo"
  final String description; // e.g., "The capital of Japan"
  final String imageUrl; // Optional: for future use
  final String country;

  DestinationModel({
    required this.id,
    required this.name,
    required this.description,
    required this.country,
    this.imageUrl = '',
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'image_url': imageUrl,
    'country': country,
  };

  factory DestinationModel.fromMap(Map<String, dynamic> data, String id) {
    return DestinationModel(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['image_url'] ?? '',
      country: data['country']
    );
  }
}

// --- SPOT MODEL (Specific attraction in the city) ---


class SpotModel {
  final String id;
  final String name;
  final List<String> categories; // Changed from String to List<String>
  final String description;
  final String imageUrl;
  final Map<String, double> prices; // {adult: 100, child: 50...}
  final String locationUrl;
  final String duration; // e.g., "2 hours"
  final String currency;

  SpotModel({
    required this.id, 
    required this.name, 
    required this.categories, 
    required this.description,
    required this.currency,
    this.imageUrl = '',
    this.prices = const {},
    this.locationUrl = '',
    this.duration = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'categories': categories, // Stored as a list in Firestore
      'description': description,
      'imageUrl': imageUrl,
      'prices': prices,
      'locationUrl': locationUrl,
      'duration': duration,
      'createdAt': FieldValue.serverTimestamp(),
      'currency':currency
    };
  }

  factory SpotModel.fromMap(Map<String, dynamic> map, String id) {
    // Helper to safely parse categories, handling backward compatibility
    // where old documents might still have a single string 'category' field.
    List<String> parsedCategories = [];
    
    if (map['categories'] != null && map['categories'] is List) {
      parsedCategories = List<String>.from(map['categories']);
    } else if (map['category'] != null && map['category'] is String) {
      parsedCategories = [map['category']];
    } else {
      parsedCategories = ['Scenery']; // Default fallback
    }

    return SpotModel(
      id: id,
      name: map['name'] ?? '',
      categories: parsedCategories,
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      // Safely convert dynamic map numbers to doubles
      prices: (map['prices'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ) ?? {},
      locationUrl: map['locationUrl'] ?? '',
      duration: map['duration'] ?? '',
      currency: map['currency']
    );
  }
}



class OrderModel {
  final String id;
  final String name;
  final String destination;
  final List<String> additionalDestinations;
  final List<String> serviceTypes;
  final DateTime startDate;
  final DateTime endDate;
  final String notes;
  
 

  final double manualIncome;
  final PaymentStatus paymentStatus;
  final TripStatus tripStatus;
  
  final Map<String, dynamic>? generatedItinerary;

  OrderModel({
    required this.id,
    required this.name,
    required this.destination,
    required this.serviceTypes,
    required this.startDate,
    required this.endDate,

    this.additionalDestinations = const [],
    this.manualIncome = 0.0,
    this.paymentStatus = PaymentStatus.unpaid,
    this.tripStatus = TripStatus.upcoming,
    this.generatedItinerary,
    this.notes =''
  });

  // Getter is still useful if you want to double-check, 
  // but now we rely on the stored field
  int get calculatedDuration => endDate.difference(startDate).inDays + 1;

  factory OrderModel.fromSnapshot(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return OrderModel.fromMap(map, doc.id);
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String documentId) {
    return OrderModel(
      id: documentId,
      name: map['name'] ?? '',
      destination: map['destination'] ?? '',
      serviceTypes: List<String>.from(map['service_types'] ?? []),
      additionalDestinations: List<String>.from(map['additional_destinations'] ?? []),
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      manualIncome: (map['manual_income'] ?? 0).toDouble(),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == map['payment_status'],
        orElse: () => PaymentStatus.unpaid,
      ),
      tripStatus: TripStatus.values.firstWhere(
        (e) => e.name == map['trip_status'],
        orElse: () => TripStatus.upcoming,
      ),
      generatedItinerary: map['generated_itinerary'],
      notes: map['notes'] ?? '', 
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'destination': destination,
      'additional_destinations': additionalDestinations,
      'service_types': serviceTypes,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'manual_income': manualIncome,
      'payment_status': paymentStatus.name,
      'trip_status': tripStatus.name,
      'notes':notes,
      if (generatedItinerary != null) 'generated_itinerary': generatedItinerary,
    };
  }
  int get durationDays => endDate.difference(startDate).inDays + 1;
}

class OrderServiceItem {
  final String id;
  final String name;
  final double pricePerDay;
  final double costPerDay;
  final int daysUsed;

  OrderServiceItem({
    required this.id,
    required this.name,
    required this.pricePerDay,
    required this.costPerDay,
    required this.daysUsed,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price_per_day': pricePerDay,
      'cost_per_day': costPerDay,
      'days_used': daysUsed,
    };
  }

  factory OrderServiceItem.fromMap(Map<String, dynamic> map, String id) {
    return OrderServiceItem(
      id: id,
      name: map['name'] ?? '',
      pricePerDay: (map['price_per_day'] ?? 0).toDouble(),
      costPerDay: (map['cost_per_day'] ?? 0).toDouble(),
      daysUsed: map['days_used'] ?? 1,
    );
  }
}


