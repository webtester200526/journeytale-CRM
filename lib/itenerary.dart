
import 'package:crmx/service_model.dart';
import 'package:flutter/material.dart';
import 'database_service.dart';

class ItineraryPage extends StatelessWidget {
  final DatabaseService _db = DatabaseService();

  ItineraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Theme Constants
    final Color bgColor = Colors.grey[50]!;
    const Color primaryColor = Color(0xFF1E293B); // Slate 800

    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<List<ItineraryItem>>(
        stream: _db.getItineraries(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final items = snapshot.data!;

          return CustomScrollView(
            slivers: [
              // 1. Modern AppBar
              SliverAppBar(
                backgroundColor: bgColor,
                surfaceTintColor: bgColor,
                pinned: true,
                floating: true,
                expandedHeight: 110,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: const Text(
                    'Destinations',
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // 2. Empty State
              if (items.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          "No destinations found.\nAdd one to start planning.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
              // 3. Grid Content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1, // Taller cards for better text fit
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _DestinationCard(item: items[index]);
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.black,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Location", style: TextStyle(color: Colors.white)),
        onPressed: () => _showAddSheet(context),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Add Destination", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              _buildTextField(controller: locCtrl, label: "City / Region", icon: Icons.location_on_outlined),
              const SizedBox(height: 16),
              
              const SizedBox(height: 16),
              
              _buildTextField(controller: descCtrl, label: "Description", maxLines: 3),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final item = ItineraryItem(
                        id: '',
                        location: locCtrl.text,
                        description: descCtrl.text,
                      );
                      _db.addItineraryItem(item);
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text("Save Location"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
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

class _DestinationCard extends StatelessWidget {
  final ItineraryItem item;

  const _DestinationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {}, // Placeholder for detail view or edit
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location Tag
                Row(
                  children: [
                    Icon(Icons.location_pin,color: Colors.redAccent,),
                    SizedBox(width: 10,),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.location.toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
              
                
                const SizedBox(height: 8),
                
                // Description
                Expanded(
                  child: Text(
                    item.description,
                    maxLines: 4,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      height: 1.4,
                    ),
                  ),
                ),
                
                // Decorative bottom dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.more_horiz, size: 16, color: Colors.grey.shade300),
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