import 'dart:io'; // Needed for your existing methods
import 'package:crmx/customers.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Needed for new Web methods
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/service_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart'; 



class DatabaseService {

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------
  // SERVICES METHODS
  // ---------------------------------------------------------

  Stream<List<ServiceModel>> getServices() {
    return _db.collection('services').snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => ServiceModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> addService(ServiceModel service) {
    return _db.collection('services').add(service.toMap());
  }

  // --- NEWLY ADDED METHOD ---
  Future<void> deleteService(String serviceId) {
    return _db.collection('services').doc(serviceId).delete();
  }
  
  
  // --------------------------

  Future<List<ServiceModel>> getServicesFuture() async {
    final snapshot = await _db.collection('services').get();
    return snapshot.docs.map((doc) => ServiceModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<void> updateService(ServiceModel service) {
    // Uses the service.id to find the document and update it
   return _db.collection('services').doc(service.id).update(service.toMap());
  }

  // ---------------------------------------------------------
  // ORDER METHODS
  // ---------------------------------------------------------

 Stream<List<OrderModel>> getOrders() {
  print("getting orders");
  return _db
      .collection('orders')
      .orderBy('startDate', descending: true)
      .snapshots()
      .map((snapshot) {
        try {
          return snapshot.docs
              .map((doc) => OrderModel.fromSnapshot(doc))
              .toList();
        } catch (e, stackTrace) {
          print('Error mapping orders: $e');
          print(stackTrace);
          return <OrderModel>[];
        }
      }).handleError((error) {
        print('Firestore stream error: $error');
      });
  }


    // Add this method inside your DatabaseService class
    Future<void> updateServiceDays({
      required String orderId,
      required String serviceId,
      required int days,
    }) async {
      try {
        final serviceRef = _db
            .collection('orders')
            .doc(orderId)
            .collection('services')
            .doc(serviceId);

        await serviceRef.update({'days': days});
      } catch (e, stackTrace) {
        print('Error updating service days: $e');
        print(stackTrace);
        rethrow;
      }
    }

    Future<void> addServiceToOrder({
      required String orderId,
      required String serviceId,
      required String serviceName,
      required int days,
    }) async {
      try {
        print("trying");
        final orderRef = _db.collection('orders').doc(orderId);
        final serviceDoc =
            await _db.collection('services').doc(serviceId).get();

        if (!serviceDoc.exists) {
          throw Exception('Service does not exist');
        }

        final WriteBatch batch = _db.batch();

        // Add service to subcollection
        batch.set(
          orderRef.collection('services').doc(serviceId),
          {
            ...serviceDoc.data() as Map<String, dynamic>,
            'days': days,
          },
        );

        // Add serviceId to serviceTypes
        batch.update(orderRef, {
          'serviceTypes': FieldValue.arrayUnion([serviceName]),
        });

        await batch.commit();
      } catch (e, stackTrace) {
        print('Error adding service to order: $e');
        print(stackTrace);
        rethrow;
      }
    }

    Future<void> removeServiceFromOrder({
      required String orderId,
      required String serviceId,
    }) async {
      try {
        final orderRef = _db.collection('orders').doc(orderId);

        final WriteBatch batch = _db.batch();

        // Delete service from subcollection
        batch.delete(
          orderRef.collection('services').doc(serviceId),
        );

        // Remove serviceId from serviceTypes
        batch.update(orderRef, {
          'serviceTypes': FieldValue.arrayRemove([serviceId]),
        });

        await batch.commit();
      } catch (e, stackTrace) {
        print('Error removing service from order: $e');
        print(stackTrace);
        rethrow;
      }
    }



  Future<void> addAdditionalFees(String orderId,String description, double amount){

     return _db.collection('orders').doc(orderId).collection('additional').add({
        'description': description, 
        'amount': amount , 
      });
  }
  // Add this to your database_service.dart
Future<void> updateOrderFees(String orderId, List<Map<String, dynamic>> fees) async {
  await _db.collection('orders').doc(orderId).update({
    'additional_fees': fees,
  });
}


  Future<String> addOrder({
    required OrderModel order,
    required List<String> selectedServiceNames,
    required List<CustomerModel> peopleToAdd, // <--- NEW PARAMETER
  }) async {
    try {
      final WriteBatch batch = _db.batch();

      // 1. Create order document reference (don't set data yet)
      final DocumentReference orderRef = _db.collection('orders').doc();
      
      // Set the main order data
      batch.set(orderRef, order.toMap());

      // 2. Add People to 'people' subcollection
      if (peopleToAdd.isNotEmpty) {
        for (var person in peopleToAdd) {
          final personRef = orderRef.collection('people').doc(); // Auto-ID
          
          final Map<String, dynamic> personData = person.toMap();
          personData['original_customer_id'] = person.id; // Link to global customer
          
          batch.set(personRef, personData);
        }
      }

      // 3. Add Services (Only if list is not empty)
      if (selectedServiceNames.isNotEmpty) {
        final QuerySnapshot serviceSnapshot = await _db
            .collection('services')
            .where('name', whereIn: selectedServiceNames)
            .get();

        for (final doc in serviceSnapshot.docs) {
          final serviceRef = orderRef.collection('services').doc(doc.id);
          batch.set(serviceRef, {
            ...doc.data() as Map<String, dynamic>,
            'duration': order.durationDays,
          });
        }
      }

      // 4. Commit all writes (Order, People, Services) atomically
      await batch.commit();

      return orderRef.id;
    } catch (e, stackTrace) {
      print('Error adding order: $e');
      print(stackTrace);
      rethrow;
    }
  }




  Future<void> updateOrderIncome(String orderId, double income) {
    return _db.collection('orders').doc(orderId).update({'manual_income': income});
  }

  Future<void> updateOrderItinerary(String orderId, Map<String, dynamic> itineraryJson) {
    return _db.collection('orders').doc(orderId).update({
      'generated_itinerary': itineraryJson, 
    });
  }
  Future<Map<String, dynamic>?> getOrder(String orderId) async {
  final doc = await _db.collection('orders').doc(orderId).get();
  return doc.data();
}

  Future<void> updateOrderStatuses(String orderId, {String? payStatus, String? tripStatus}) async {
    Map<String, dynamic> data = {};
    if (payStatus != null) data['payment_status'] = payStatus;
    if (tripStatus != null) data['trip_status'] = tripStatus;
    if (data.isNotEmpty) {
      await _db.collection('orders').doc(orderId).update(data);
    }
  }

  // --- NEW: Update Dates ---
  Future<void> updateOrderDates(String orderId, DateTime start, DateTime end, int duration) {
    return _db.collection('orders').doc(orderId).update({
      'startDate': start,
      'endDate': end,
      'durationDays': duration,
    });
  }
   Future<void> addDestinationToOrder(String orderId, List<String> destination){
     return _db.collection('orders').doc(orderId).update({
      'additional_cities': destination, 
    });
    
  }

  // ---------------------------------------------------------
  // ITINERARY METHODS
  // ---------------------------------------------------------

  Stream<List<ItineraryItem>> getItineraries() {
    return _db.collection('itinerary').snapshots().map((snap) =>
        snap.docs.map((doc) {
          final data = doc.data();
          return ItineraryItem(
            id: doc.id,
            description: data['description'] ?? '',
            location: data['location'] ?? '',
          );
        }).toList());
  }

  Future<void> addItineraryItem(ItineraryItem item) {
    return _db.collection('itinerary').add(item.toMap());
  }
 

  // ---------------------------------------------------------
  // PEOPLE & PASSPORT METHODS
  // ---------------------------------------------------------

 
  // Standard File Upload (Mobile only)
  Future<String> uploadPassportImage(String orderId, String personId, File imageFile) async {
    try {
      final ref = _storage.ref().child('orders/$orderId/passports/$personId.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      await _db.collection('orders').doc(orderId).collection('people').doc(personId).update({
        'passport_image_url': url,
      });
      return url;
    } catch (e) {
      throw Exception("Upload failed: $e");
    }
  }

  // Web-Safe Upload Method (Uses XFile)
  Future<String> uploadPassportFromXFile(String orderId, String personId, XFile imageFile) async {
    try {
      final ref = _storage.ref().child('orders/$orderId/passports/$personId.jpg');

      if (kIsWeb) {
        // WEB: Read bytes
        final bytes = await imageFile.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        // MOBILE: Read path
        await ref.putFile(File(imageFile.path));
      }

      final url = await ref.getDownloadURL();
      await _db.collection('orders').doc(orderId).collection('people').doc(personId).update({
        'passport_image_url': url,
      });
      return url;
    } catch (e) {
      throw Exception("Web/Mobile Upload failed: $e");
    }
  }

  // ---------------------------------------------------------
  // UTILITY METHODS
  // ---------------------------------------------------------


  Future<void> updateOrderServices(String orderId, List<String> newServices) {
    // We update the 'services' array in Firestore
    return _db.collection('orders').doc(orderId).update({
      'services': newServices,
    });
  }

  // --- NEW: Delete Order ---
  Future<void> deleteOrder(String orderId) async {
    // Note: This deletes the document. 
    // Subcollections (like 'people') in Firestore must be deleted manually if you want a full cleanup,
    // but deleting the parent doc prevents it from showing in the app queries.
    return _db.collection('orders').doc(orderId).delete();
  }


  // ---------------------------------------------------------
  // DESTINATION & SPOTS METHODS
  // ---------------------------------------------------------

  // 1. Get All Cities
  Stream<List<DestinationModel>> getDestinations() {
    return _db.collection('destinations').snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => DestinationModel.fromMap(doc.data(), doc.id)).toList());
  }

  // 2. Add a City
  Future<void> addDestination(DestinationModel dest) {
    return _db.collection('destinations').add(dest.toMap());
  }
  
  // 3. Delete a City
  Future<void> deleteDestination(String destId) {
    return _db.collection('destinations').doc(destId).delete();
  }

  // 4. Get Spots for a specific City
  Stream<List<SpotModel>> getSpots(String destinationId) {
    return _db.collection('destinations')
        .doc(destinationId)
        .collection('spots')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SpotModel.fromMap(doc.data(), doc.id)).toList());
  }
  Future<void> updateDestination(DestinationModel destination) async {
    try {
      await _db
          .collection('destinations')
          .doc(destination.id)
          .update(destination.toMap());
    } catch (e) {
      print("Error updating destination: $e");
      rethrow;
    }
  }


  // 5. Add a Spot to a specific City
  Future<void> addSpot(String destinationId, SpotModel spot) {
    return _db.collection('destinations')
        .doc(destinationId)
        .collection('spots')
        .add(spot.toMap());
  }

  Future<void> updateSpot(String cityId, SpotModel spot) async {
  try {
    await _db
        .collection('destinations')
        .doc(cityId)
        .collection('spots')
        .doc(spot.id)
        .update(spot.toMap());
  } catch (e) {
    print("Error updating spot: $e");
    rethrow; // Pass error up to the UI to handle
  }
}

  // 6. Delete a Spot
  Future<void> deleteSpot(String destinationId, String spotId) {
    return _db.collection('destinations')
        .doc(destinationId)
        .collection('spots')
        .doc(spotId)
        .delete();
  }

  // Update this utility to use the new collection
  Future<List<String>> getDestinationsList() async {
    try {
      final snap = await _db.collection('destinations').get();

      return snap.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      print("Error fetching destinations: $e");
      return [];
    }
  }
  Future<List<String>> getSpotsForDestination(String destinationName) async {
    try {
      // 1. Query destination by name field
      final destinationSnap = await _db
          .collection('destinations')
          .where('name', isEqualTo: destinationName)
          .limit(1)
          .get();

      if (destinationSnap.docs.isEmpty) {
        return [];
      }

      final destinationDocId = destinationSnap.docs.first.id;

      // 2. Get spots subcollection
      final spotsSnap = await _db
          .collection('destinations')
          .doc(destinationDocId)
          .collection('spots')
          .get();

      // 3. Extract spot names
      return spotsSnap.docs
          .map((doc) => doc.data()['name'] as String?)
          .whereType<String>()
          .toList();
    } catch (e, stackTrace) {
      print('Error fetching spots for $destinationName: $e');
      print(stackTrace);
      return [];
    }
  }

}




 


