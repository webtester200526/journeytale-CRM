// create_order_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/customers.dart'; // Ensure GroupModel and CustomerModel are here
import 'package:crmx/permission_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:crmx/service_model.dart';
import 'database_service.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();

  // --- STATE ---
  
  // Selection State: Only one of these will be not null
  CustomerModel? _selectedCustomer; 
  GroupModel? _selectedGroup;
  
  // Existing State
  final _flightNumController = TextEditingController();
  String? _selectedDestination;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 3));
  
  List<String> _availableDestinations = [];
  final List<String> _additionalDestination =[];
  
  bool _isLoading = false;
  bool _isDataLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _flightNumController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      final destinations = await _db.getDestinationsList();
      if (mounted) {
        setState(() {
          _availableDestinations = destinations;
          _isDataLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  // --- LOGIC: SELECTION ---

  void _openSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => _SelectionDialog(
        onCustomerSelected: (customer) {
          setState(() {
            _selectedCustomer = customer;
            _selectedGroup = null; // Clear group if customer selected
          });
        },
        onGroupSelected: (group) {
          setState(() {
            _selectedGroup = group;
            _selectedCustomer = null; // Clear customer if group selected
          });
        },
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    
    // VALIDATIONS
    if (_selectedCustomer == null && _selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Please select a client or a group"), backgroundColor: Colors.redAccent));
      return;
    }

    if (_selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Please select a destination"), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Prepare Passenger List
      List<CustomerModel> passengers = [];
      String orderName = "";

      if (_selectedCustomer != null) {
        // Case A: Single Individual
        passengers.add(_selectedCustomer!);
        orderName = _selectedCustomer!.name;
      } else if (_selectedGroup != null) {
        // Case B: Group - Fetch members first
        orderName = _selectedGroup!.name; // Order Name = Group Name
        
        // Query customers where 'group_ids' array contains the group ID
        final snapshot = await FirebaseFirestore.instance
            .collection('customers')
            .where('group_ids', arrayContains: _selectedGroup!.id)
            .get();

        passengers = snapshot.docs
            .map((doc) => CustomerModel.fromSnapshot(doc))
            .toList();

        if (passengers.isEmpty) {
          throw Exception("The selected group has no members.");
        }
      }

      // 2. Create Order Object
      final newOrder = OrderModel(
        id: '', 
        name: orderName, 
        additionalDestinations: _additionalDestination,
        destination: _selectedDestination!,
        serviceTypes: [], 
        startDate: _startDate,
        endDate: _endDate,
        manualIncome: 0,
        paymentStatus: PaymentStatus.unpaid,
        tripStatus: TripStatus.upcoming,
      );

      // 3. Add Order to Database (Pass passengers to function)
      // The DatabaseService will handle writing the 'people' subcollection
      await _db.addOrder(
        order: newOrder, 
        selectedServiceNames: [], // Empty list passed as requested
        peopleToAdd: passengers,  // <--- Passing the list here
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Order Created Successfully"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5F7),
        appBar: AppBar(
          title: const Text("New Booking", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: Colors.grey[200], height: 1),
          ),
        ),
        body: _isDataLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Form(
              key: _formKey,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: isDesktop 
                      ? _buildDesktopLayout() 
                      : _buildMobileLayout(),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  // --- LAYOUTS ---

  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Client / Group", Icons.person_outline),
                _wrapInCard(child: _buildClientInput()),
                
                const SizedBox(height: 24),
                _buildSectionHeader("Trip Information", Icons.map_outlined),
                _wrapInCard(child: _buildTripDetailsInput()),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Booking Summary", Icons.summarize_outlined),
                _wrapInCard(child: _buildSummaryAndSubmit()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Client / Group", Icons.person_outline),
          _wrapInCard(child: _buildClientInput()),

          const SizedBox(height: 24),
          _buildSectionHeader("Trip Information", Icons.map_outlined),
          _wrapInCard(child: _buildTripDetailsInput()),

          const SizedBox(height: 24),
          _buildSectionHeader("Summary", Icons.check_circle_outline),
          _wrapInCard(child: _buildSummaryAndSubmit()),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- INPUT COMPONENTS ---

  Widget _buildClientInput() {
    if (_selectedCustomer == null && _selectedGroup == null) {
      return InkWell(
        onTap: _openSelectionDialog,
        child: InputDecorator(
          decoration: _inputDecoration("Client or Group", Icons.group_add).copyWith(
            floatingLabelBehavior: FloatingLabelBehavior.never
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Tap to select Client or Group", style: TextStyle(color: Colors.grey)),
              Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      );
    }

    // Determine what to show based on what is selected
    String displayName = "";
    String subtitle = "";
    Widget avatarChild;
    String? imageUrl;

    if (_selectedCustomer != null) {
      displayName = _selectedCustomer!.name;
      subtitle = "Individual • Passport: ${_selectedCustomer!.passportNumber}";
      imageUrl = _selectedCustomer!.passportImageUrl;
      avatarChild = Text(_selectedCustomer!.name.isNotEmpty ? _selectedCustomer!.name[0].toUpperCase() : "?");
    } else {
      displayName = _selectedGroup!.name;
      subtitle = "Group • ${_selectedGroup!.notes}";
      imageUrl = null; // Groups usually don't have one image in this context
      avatarChild = const Icon(Icons.groups, color: Colors.white, size: 20);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _selectedGroup != null ? Colors.blue : Colors.grey[300],
            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) 
              ? NetworkImage(imageUrl) 
              : null,
            child: (imageUrl == null || imageUrl.isEmpty) 
              ? avatarChild
              : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: _openSelectionDialog,
            child: const Text("Change"),
          )
        ],
      ),
    );
  }

  Widget _buildTripDetailsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedDestination,
          decoration: _inputDecoration("Primary Destination", Icons.location_on),
          items: _availableDestinations.isEmpty 
            ? [const DropdownMenuItem(value: null, child: Text("No destinations loaded"))]
            : _availableDestinations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (val) => setState(() => _selectedDestination = val),
          validator: (v) => v == null ? "Required" : null,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        
        const SizedBox(height: 24),
        
        InkWell(
          onTap: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
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
              }
            );
            if (picked != null) {
              setState(() {
                _startDate = picked.start;
                _endDate = picked.end;
              });
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range, color: Colors.black54),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Trip Duration", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      "${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.edit, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 16),
        
        // COLLAPSIBLE ADDITIONAL DESTINATIONS
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              "Also Visiting (Optional)", 
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            subtitle: _additionalDestination.isNotEmpty 
              ? Text("${_additionalDestination.length} selected", style: const TextStyle(fontSize: 12, color: Colors.black54))
              : null,
            children: [
              _selectedDestination == null 
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text("Please select a primary destination first.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13)),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: _additionalDestinationList(),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _additionalDestinationList(){
   final filteredDestinations = _availableDestinations
    .where((d) => !(_selectedDestination?.contains(d) ?? false))
    .toList();

  return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: filteredDestinations.length,
        separatorBuilder: (c, i) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final destination = filteredDestinations[index];
          final isSelected = _additionalDestination.contains(destination);

          return CheckboxListTile(
            title: Text(destination, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            value: isSelected,
            dense: true,
            activeColor: Colors.black,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _additionalDestination.add(destination);
                } else {
                  _additionalDestination.remove(destination);
                }
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
          );
        },
      );
  }

  Widget _buildSummaryAndSubmit() {
    int days = _endDate.difference(_startDate).inDays + 1;
    String clientName = "-";
    if(_selectedCustomer != null) clientName = _selectedCustomer!.name;
    if(_selectedGroup != null) clientName = "Group: ${_selectedGroup!.name}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryRow("Client/Group", clientName), 
        _buildSummaryRow("Destination", _selectedDestination ?? "-"),
        _buildSummaryRow("Duration", "$days Days"),
        
        if(_additionalDestination.isNotEmpty)
          _buildSummaryRow("Extra Cities", "${_additionalDestination.length}"),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),

        FilledButton(
          onPressed: _isLoading ? null : _submitOrder,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : const Text("Create Order", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value, 
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- STYLING HELPERS ---

  Widget _wrapInCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700], letterSpacing: 0.8)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.black54, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: Colors.grey),
      floatingLabelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    );
  }
}

// =======================================================
// HELPER DIALOG FOR SELECTING CUSTOMER OR GROUP
// =======================================================

class _SelectionDialog extends StatefulWidget {
  final Function(CustomerModel) onCustomerSelected;
  final Function(GroupModel) onGroupSelected;

  const _SelectionDialog({
    required this.onCustomerSelected,
    required this.onGroupSelected,
  });

  @override
  State<_SelectionDialog> createState() => _SelectionDialogState();
}

class _SelectionDialogState extends State<_SelectionDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _query = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
                const Text("Select Entity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            
            // TABS
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TabBar(
              dividerColor: Colors.transparent,
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context).colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              labelColor: Theme.of(context).colorScheme.onPrimary,
              unselectedLabelColor: Colors.black54,
              tabs: const [
                Tab(text: "Individuals"),
                Tab(text: "Groups"),
              ],
            )

            ),
            const SizedBox(height: 16),
            
            TextField(
              decoration: InputDecoration(
                hintText: "Search...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (val) => setState(() => _query = val.toLowerCase()),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildIndividualList(),
                  _buildGroupList(),
                ],
              ),
            ),
            
            const Divider(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                   bool granted = await PermissionService().canAccessCustomers;

                    if (granted) {
                      
                      _openCreateNewCustomerDialog(context);
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
                icon: const Icon(Icons.add),
                label: const Text("Create New Customer"),
               
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('customers').orderBy('updatedAt', descending: true).limit(20).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final allDocs = snapshot.data!.docs.map((d) => CustomerModel.fromSnapshot(d)).toList();
        final filtered = _query.isEmpty 
            ? allDocs 
            : allDocs.where((c) => c.name.toLowerCase().contains(_query) || c.passportNumber.contains(_query)).toList();

        if (filtered.isEmpty) return const Center(child: Text("No individuals found"));

        return ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_,__) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final c = filtered[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: c.passportImageUrl.isNotEmpty ? NetworkImage(c.passportImageUrl) : null,
                child: c.passportImageUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Passport: ${c.passportNumber}"),
              onTap: () {
                widget.onCustomerSelected(c);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGroupList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('groups').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final allDocs = snapshot.data!.docs.map((d) => GroupModel.fromSnapshot(d)).toList();
        final filtered = _query.isEmpty 
            ? allDocs 
            : allDocs.where((g) => g.name.toLowerCase().contains(_query)).toList();

        if (filtered.isEmpty) return const Center(child: Text("No groups found"));

        return ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_,__) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final g = filtered[index];
            return ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.groups, color: Colors.white)),
              title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(g.notes),
              onTap: () {
                widget.onGroupSelected(g);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void _openCreateNewCustomerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => CustomerEditorDialog(
        onSave: (model, file) async {
          // 1. Save to Global Database
          DocumentReference ref = await FirebaseFirestore.instance.collection('customers').add(model.toMap());
          
          String imgUrl = "";
          if (file != null) {
            final storageRef = FirebaseStorage.instance.ref().child('customers/${ref.id}/passport.jpg');
            await storageRef.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
            imgUrl = await storageRef.getDownloadURL();
            await ref.update({'passport_image_url': imgUrl});
          }

          final newCustomer = CustomerModel(
            id: ref.id,
            name: model.name,
            passportNumber: model.passportNumber,
            passportImageUrl: imgUrl,
            dob: model.dob,
            preferences: model.preferences,
            notes: model.notes
          );

          if(mounted) {
            Navigator.pop(context); // Close Editor
            widget.onCustomerSelected(newCustomer); // Select in parent
            Navigator.pop(context); // Close Selection Dialog
          }
        },
      ),
    );
  }
}