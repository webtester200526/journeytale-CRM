import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/customers.dart';
import 'package:crmx/permission_service.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// IMPORT YOUR FILE 1 HERE
 

class PassengerManager extends StatefulWidget {
  final String orderId;
  const PassengerManager({super.key, required this.orderId});

  @override
  State<PassengerManager> createState() => _PassengerManagerState();
}

class _PassengerManagerState extends State<PassengerManager> {
  
  // --- ORDER SPECIFIC STREAMS ---
  Stream<List<CustomerModel>> _getOrderPassengers() {
    return FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .collection('people') 
        .snapshots()
        .map((snap) => snap.docs.map((doc) => CustomerModel.fromSnapshot(doc)).toList());
  }

  Future<void> _removePassengerFromOrder(String passengerId) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .collection('people')
        .doc(passengerId)
        .delete();
  }

  void _openAddPassengerDialog() {
    showDialog(
      context: context,
      builder: (context) => _PassengerSelectionDialog(orderId: widget.orderId),
    );
  }
  

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("PASSENGERS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1.2)),
              ElevatedButton.icon(
                onPressed: _openAddPassengerDialog,
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: const Text("Select / Add Customer"),
                
              ),
            ],
          ),
        ),
        StreamBuilder<List<CustomerModel>>(
          stream: _getOrderPassengers(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final people = snapshot.data!;
            if (people.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                child: Text("No passengers in this order yet.", style: TextStyle(color: Colors.grey[500])),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: people.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = people[index];
                return _PassengerCard(
                  person: p,
                  onDelete: () => _removePassengerFromOrder(p.id),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// --- SELECTION DIALOG ---

class _PassengerSelectionDialog extends StatefulWidget {
  final String orderId;
  const _PassengerSelectionDialog({required this.orderId});

  @override
  State<_PassengerSelectionDialog> createState() => _PassengerSelectionDialogState();
}

class _PassengerSelectionDialogState extends State<_PassengerSelectionDialog> {
  String _query = "";

  Future<void> _addToOrder(CustomerModel customer) async {
    final data = customer.toMap();
    data['original_customer_id'] = customer.id; // Link to global customer
    
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .collection('people')
        .add(data);
        
    if(mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Select Customer", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: "Search by name or passport...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (val) => setState(() => _query = val.toLowerCase()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('customers').orderBy('updatedAt', descending: true).limit(20).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final allDocs = snapshot.data!.docs.map((d) => CustomerModel.fromSnapshot(d)).toList();
                  final filtered = _query.isEmpty 
                      ? allDocs 
                      : allDocs.where((c) => c.name.toLowerCase().contains(_query) || c.passportNumber.contains(_query)).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_off_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text("Customer not found"),
                          const SizedBox(height: 8),
                         TextButton(
                            onPressed: () async {
                        
                              // 1. Force a fresh check
                              bool granted = await PermissionService().canAccessCustomers;

                              if (granted) {
                               
                                _openCreateNewDialog(context);
                              } else {
               
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('You do not have permission to create a customer.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                            child: const Text("Create New Customer"),
                          )
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_,__) => const Divider(),
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: c.passportImageUrl.isNotEmpty ? NetworkImage(c.passportImageUrl) : null,
                          child: c.passportImageUrl.isEmpty ? const Icon(Icons.person) : null,
                        ),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Passport: ${c.passportNumber}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                          onPressed: () => _addToOrder(c),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                   bool granted = await PermissionService().canAccessCustomers;

                  if (granted) {
                    
                    _openCreateNewDialog(context);
                  } else {
    
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You do not have permission to create a customer.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                            
                }
                
                ,
                icon: const Icon(Icons.add),
                label: const Text("Create New Customer"),
                style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _openCreateNewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => CustomerEditorDialog(
        onSave: (model, file) async {
          // 1. Save to Global
          DocumentReference ref = await FirebaseFirestore.instance.collection('customers').add(model.toMap());
          
          // 2. Upload Image
          String imgUrl = "";
          if (file != null) {
            final storageRef = FirebaseStorage.instance.ref().child('customers/${ref.id}/passport.jpg');
            await storageRef.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
            imgUrl = await storageRef.getDownloadURL();
            await ref.update({'passport_image_url': imgUrl});
          }

          // 3. Add to Current Order
          final newCustomerData = model.toMap();
          newCustomerData['passport_image_url'] = imgUrl;
          newCustomerData['original_customer_id'] = ref.id;

          await FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.orderId)
              .collection('people')
              .add(newCustomerData);

          if(mounted) {
            Navigator.pop(context); // Close Editor
            Navigator.pop(context); // Close Selection Dialog
          }
        },
      ),
    );
  }
}

// --- PASSENGER CARD (View in List) ---

class _PassengerCard extends StatelessWidget {
  final CustomerModel person;
  final VoidCallback onDelete;

  const _PassengerCard({required this.person, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    bool hasImg = person.passportImageUrl.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          GestureDetector(
             onTap: hasImg ? () {
              showDialog(context: context, builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                child: InteractiveViewer(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(person.passportImageUrl))),
              ));
            } : null,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
              child: hasImg ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(person.passportImageUrl, fit: BoxFit.cover)) : const Icon(Icons.person, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text("Passport: ${person.passportNumber}", style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                Text("DOB: ${person.dob != null ? DateFormat('dd MMM yyyy').format(person.dob!) : 'N/A'} (Age: ${person.age})", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                if(person.preferences.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text("Pref: ${person.preferences}", style: TextStyle(color: Colors.purple[700], fontSize: 12, fontWeight: FontWeight.w500)),
                ]
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.delete_outline, color: Colors.red[300]), onPressed: onDelete),
        ],
      ),
    );
  }
}