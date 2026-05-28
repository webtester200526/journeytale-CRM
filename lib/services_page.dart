import 'package:crmx/service_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Added for currency formatting
import 'database_service.dart';

class ServicesPage extends StatelessWidget {
  final DatabaseService _db = DatabaseService();

  ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFFF3F5F7); 
    const Color primaryColor = Color(0xFF1A1C20);

    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<List<ServiceModel>>(
        stream: _db.getServices(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final services = snapshot.data!;
          final Map<String, List<ServiceModel>> groupedServices = {};
          final Set<String> distinctCategories = {};

          for (var service in services) {
            if (!groupedServices.containsKey(service.category)) {
              groupedServices[service.category] = [];
            }
            groupedServices[service.category]!.add(service);
            if (service.category.isNotEmpty) distinctCategories.add(service.category);
          }

          final sortedCategories = groupedServices.keys.toList()..sort();

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: bgColor,
                surfaceTintColor: bgColor,
                pinned: true,
                floating: true,
                expandedHeight: 100,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                  title: const Text(
                    'Services Catalog',
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 24),
                  ),
                ),
              ),

              if (services.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("No services found.\nAdd one to get started.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),

              for (var category in sortedCategories) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Row(
                      children: [
                        Container(width: 4, height: 18, decoration: BoxDecoration(color: Colors.amberAccent, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Text(category.toUpperCase(), style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(child: Divider(color: const Color.fromARGB(255, 234, 234, 234))),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.3,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final service = groupedServices[category]![index];
                        return _ServiceGridCard(
                          service: service,
                          onEdit: () => _showServiceForm(context, distinctCategories.toList(), service: service),
                          onDelete: () => _confirmDelete(context, service),
                        );
                      },
                      childCount: groupedServices[category]!.length,
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)), 
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Service", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showServiceForm(context, []), 
      ),
    );
  }

  void _showServiceForm(BuildContext context, List<String> existingCategories, {ServiceModel? service}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _ServiceFormContent(
          existingService: service,
          availableCategories: existingCategories, 
          onSubmit: (submittedService) {
            if (service == null) {
              _db.addService(submittedService);
            } else {
              _db.updateService(submittedService);
            }
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ServiceModel service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Service?"),
        content: Text("Are you sure you want to remove '${service.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel",style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () { _db.deleteService(service.id); Navigator.pop(ctx); }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

// --- UPDATED: Grid Item Component with Currency ---
class _ServiceGridCard extends StatelessWidget {
  final ServiceModel service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceGridCard({required this.service, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    // Determine Symbol
    final currencyFormat = NumberFormat.simpleCurrency(name: service.currency, decimalDigits: 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        service.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1C20)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                         showModalBottomSheet(context: context, builder: (c) => Wrap(children: [
                           ListTile(leading: const Icon(Icons.edit), title: const Text('Edit'), onTap: (){ Navigator.pop(c); onEdit(); }),
                           ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Delete', style: TextStyle(color: Colors.red)), onTap: (){ Navigator.pop(c); onDelete(); }),
                         ]));
                      },
                      child: Icon(Icons.more_vert, size: 20, color: Colors.grey[400]),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  service.description.isEmpty ? "No description provided" : service.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.4),
                ),
                const Spacer(),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PriceTag(label: "CLIENT", amount: currencyFormat.format(service.pricePerDay), isPrimary: true),
                    Container(width: 1, height: 20, color: Colors.grey.shade200),
                    _PriceTag(label: "COST", amount: currencyFormat.format(service.costPerDay), isPrimary: false),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final String label;
  final String amount; // Now formatted string with symbol
  final bool isPrimary;
  const _PriceTag({required this.label, required this.amount, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isPrimary ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
        Text(amount, style: TextStyle(fontSize: 16, fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w600, color: isPrimary ? Colors.black : Colors.grey.shade600)),
      ],
    );
  }
}

// --- UPDATED Form Component with Currency Selector ---

class _ServiceFormContent extends StatefulWidget {
  final ServiceModel? existingService;
  final List<String> availableCategories; 
  final Function(ServiceModel) onSubmit;

  const _ServiceFormContent({this.existingService, required this.availableCategories, required this.onSubmit});

  @override
  State<_ServiceFormContent> createState() => _ServiceFormContentState();
}

class _ServiceFormContentState extends State<_ServiceFormContent> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _descCtrl;
  String _selectedCurrency = 'RMB'; // Default

  late List<String> _displayCategories;

  @override
  void initState() {
    super.initState();
    final s = widget.existingService;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _categoryCtrl = TextEditingController(text: s?.category ?? ''); 
    _priceCtrl = TextEditingController(text: s?.pricePerDay.toString() ?? '');
    _costCtrl = TextEditingController(text: s?.costPerDay.toString() ?? '');
    _descCtrl = TextEditingController(text: s?.description ?? '');
    _selectedCurrency = s?.currency ?? 'RMB';

    final Set<String> uniqueCats = Set.from(widget.availableCategories);
    if (uniqueCats.isEmpty) {
      uniqueCats.addAll(['Photography', 'Cellular', 'Food', 'Other']);
    }
    _displayCategories = uniqueCats.toList()..sort();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final service = ServiceModel(
        id: widget.existingService?.id ?? '', 
        name: _nameCtrl.text,
        category: _categoryCtrl.text.trim(),
        pricePerDay: double.tryParse(_priceCtrl.text) ?? 0,
        costPerDay: double.tryParse(_costCtrl.text) ?? 0,
        description: _descCtrl.text,
        currency: _selectedCurrency, // Save currency
      );
      widget.onSubmit(service);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingService != null;

    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEditing ? "Edit Service" : "New Service", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: Colors.grey.shade400))
                ],
              ),
              const SizedBox(height: 20),
          
              _buildTextField(
                controller: _categoryCtrl,
                label: "Category",
                icon: Icons.category,
                validator: (v) => v!.isEmpty ? "Category is required" : null,
                hint: "Select below or type new...",
              ),
              const SizedBox(height: 8),
              
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _displayCategories.map((cat) {
                  return ActionChip(
                    label: Text(cat),
                    backgroundColor: Colors.grey.shade100,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: () => setState(() => _categoryCtrl.text = cat),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              _buildTextField(controller: _nameCtrl, label: "Service Name", icon: Icons.title, validator: (v) => v!.isEmpty ? "Name is required" : null),
              const SizedBox(height: 16),
              
              // --- UPDATED ROW WITH CURRENCY ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(controller: _priceCtrl, label: "Client Price", icon: Icons.attach_money, isNumber: true, validator: (v) => v!.isEmpty ? "Required" : null),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _buildTextField(controller: _costCtrl, label: "Internal Cost", icon: Icons.money_off, isNumber: true),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 56, // Matches default TextField height
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCurrency,
                          isExpanded: true,
                          items: [
                            'IDR', 'RMB', 'EUR', 'USD', 'SGD', 'MYR',
                            'JPY', 'CHF', 'KRW', 'TWD', 'HKD', 'MOP', 'AUD',
                          ].map((c) => 
                            DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))
                          ).toList(),
                          onChanged: (val) => setState(() => _selectedCurrency = val!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              _buildTextField(controller: _descCtrl, label: "Description", icon: Icons.description_outlined, maxLines: 3),
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _submit,
                  child: Text(isEditing ? "Save Changes" : "Add Service"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, IconData? icon, bool isNumber = false, int maxLines = 1, String? hint, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 18, color: Colors.grey) : null,
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 1)),
      ),
    );
  }
}