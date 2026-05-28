import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:crmx/service_model.dart';
import 'database_service.dart';

// --- THEME CONSTANTS ---
const Color kBgColor = Color(0xFFF3F5F7);
const Color kSidebarColor = Colors.white;
const Color kPrimaryBlack = Color(0xFF1A1C20);
const Color kBorderColor = Color(0xFFE2E8F0);
const Color kTextSecondary = Color(0xFF64748B);
const double kMobileBreakpoint = 900.0;

// --- HARDCODED COUNTRIES ---
const List<String> kCountries = [
  'China',
  'Japan',
  'South Korea',
  'Thailand',
  'Vietnam',
  'Singapore',
  'Malaysia',
  'Indonesia',
  'Philippines',
  'Other'
];

class PastelPalette {
  static final List<Color> colors = [
    Colors.amber, const Color.fromARGB(255, 82, 177, 255), Colors.purpleAccent, Colors.teal
  ];
  static Color getColor(int index) => colors[index % colors.length];
}

class DestinationsDashboard extends StatefulWidget {
  const DestinationsDashboard({super.key});

  @override
  State<DestinationsDashboard> createState() => _DestinationsDashboardState();
}

class _DestinationsDashboardState extends State<DestinationsDashboard> {
  DestinationModel? _selectedCity;
  Color _selectedThemeColor = Colors.amber;

  void _selectCity(DestinationModel city, int index) {
    setState(() {
      _selectedCity = city;
      _selectedThemeColor = PastelPalette.getColor(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < kMobileBreakpoint;

          // --- MOBILE LAYOUT ---
          if (isMobile) {
            return _CityList(
              selectedId: null,
              onCitySelected: (city, index) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: Text(city.name, style: const TextStyle(color: Colors.black, fontSize: 16)),
                        backgroundColor: Colors.white,
                        iconTheme: const IconThemeData(color: Colors.black),
                        elevation: 0,
                        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: kBorderColor, height: 1)),
                      ),
                      body: _CityContentArea(city: city, themeColor: PastelPalette.getColor(index)),
                    ),
                  ),
                );
              },
            );
          }

          // --- DESKTOP LAYOUT ---
          return Row(
            children: [
              Container(
                width: 300,
                decoration: const BoxDecoration(
                  color: kSidebarColor,
                  border: Border(right: BorderSide(color: kBorderColor)),
                ),
                child: Column(
                  children: [
                    _buildSidebarHeader(),
                    Expanded(
                      child: _CityList(
                        selectedId: _selectedCity?.id,
                        onCitySelected: _selectCity,
                      ),
                    ),
                    _buildSidebarFooter(context),
                  ],
                ),
              ),
              Expanded(
                child: _selectedCity == null
                    ? _buildEmptyDashboardState()
                    : _CityContentArea(
                        key: ValueKey(_selectedCity!.id),
                        city: _selectedCity!,
                        themeColor: _selectedThemeColor,
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: (MediaQuery.of(context).size.width < kMobileBreakpoint)
          ? FloatingActionButton(
              onPressed: () => _showAddCityDialog(context),
              backgroundColor: kPrimaryBlack,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      width: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Destinations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimaryBlack)),
          const SizedBox(height: 4),
          Text("Content Management", style: TextStyle(fontSize: 12, color: kTextSecondary)),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorderColor))),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _showAddCityDialog(context),
          icon: const Icon(Icons.add, size: 16),
          label: const Text("New City"),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amberAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDashboardState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100), border: Border.all(color: kBorderColor)),
            child: Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text("Select a Destination", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 8),
          Text("Choose a city from the sidebar to manage spots", style: TextStyle(fontSize: 14, color: kTextSecondary)),
        ],
      ),
    );
  }

  void _showAddCityDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedCountry;
    final formKey = GlobalKey<FormState>();
    final DatabaseService db = DatabaseService();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New City"),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // COUNTRY DROPDOWN
                DropdownButtonFormField<String>(
                  value: selectedCountry,
                  decoration: const InputDecoration(labelText: "Country", filled: true, fillColor: kBgColor),
                  items: kCountries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => selectedCountry = val,
                  validator: (v) => v == null ? "Required" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  validator: (v) => v!.trim().isEmpty ? "Required" : null,
                  decoration: const InputDecoration(labelText: "City Name", filled: true, fillColor: kBgColor),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "Description", filled: true, fillColor: kBgColor),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel",style: TextStyle(color: Colors.red))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPrimaryBlack),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                db.addDestination(DestinationModel(
                  id: '', 
                  name: nameCtrl.text.trim(), 
                  country: selectedCountry!, // Pass country
                  description: descCtrl.text.trim()
                ));
                Navigator.pop(ctx);
              }
            },
            child: const Text("Create"),
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// --- CITY LIST SIDEBAR (Grouped, Collapsible, Initially Collapsed) ---
// ---------------------------------------------------------------------------

class _CityList extends StatefulWidget {
  final String? selectedId;
  final Function(DestinationModel, int) onCitySelected;

  const _CityList({required this.selectedId, required this.onCitySelected});

  @override
  State<_CityList> createState() => _CityListState();
}

class _CityListState extends State<_CityList> {
  final DatabaseService _db = DatabaseService();
  
  // Stores the names of countries that are currently expanded
  final Set<String> _expandedCountries = {};

  void _toggleCountry(String country) {
    setState(() {
      if (_expandedCountries.contains(country)) {
        _expandedCountries.remove(country);
      } else {
        _expandedCountries.add(country);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DestinationModel>>(
      stream: _db.getDestinations(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final allCities = snapshot.data!;
        
        // 1. Group cities by Country
        final Map<String, List<DestinationModel>> groupedCities = {};
        for (var city in allCities) {
          if (!groupedCities.containsKey(city.country)) {
            groupedCities[city.country] = [];
          }
          groupedCities[city.country]!.add(city);
        }

        // 2. Sort countries alphabetically
        final sortedCountries = groupedCities.keys.toList()..sort();

        // 3. Auto-expand the country of the selected city (Optional UX improvement)
        // If you strictly want it always collapsed on first load, remove this block.
        // However, this logic keeps the menu open if you refresh the page while a city is selected.
        if (widget.selectedId != null) {
          try {
            final selectedCity = allCities.firstWhere((c) => c.id == widget.selectedId);
            // Only add if we haven't interacted yet? 
            // For now, we just ensure the selected one is visible.
            _expandedCountries.add(selectedCity.country);
          } catch (_) {}
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: sortedCountries.length,
          itemBuilder: (context, countryIndex) {
            final country = sortedCountries[countryIndex];
            final citiesInCountry = groupedCities[country]!;
            final isExpanded = _expandedCountries.contains(country);
            final cityCount = citiesInCountry.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- COUNTRY HEADER (Collapsible Trigger) ---
                InkWell(
                  onTap: () => _toggleCountry(country),
                  hoverColor: Colors.grey[50],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Chevron Icon
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                              size: 16,
                              color: kTextSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              country.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryBlack,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        // City Count Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "$cityCount",
                            style: const TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                // --- CITY LIST (Visible only if expanded) ---
                if (isExpanded)
                  ...citiesInCountry.map((city) {
                    final globalIndex = allCities.indexOf(city);
                    final isSelected = city.id == widget.selectedId;
                    final initial = city.name.isNotEmpty ? city.name[0].toUpperCase() : "?";
                    final color = PastelPalette.getColor(globalIndex);

                    return Material(
                      color: isSelected ? kBgColor : Colors.transparent,
                      child: ListTile(
                        onTap: () => widget.onCitySelected(city, globalIndex),
                        // Add indentation to show hierarchy
                        contentPadding: const EdgeInsets.only(left: 36, right: 16, top: 0, bottom: 0),
                        dense: true,
                        leading: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : color.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: kBorderColor) : null,
                          ),
                          child: Center(
                            child: Text(
                              initial, 
                              style: TextStyle(
                                color: isSelected ? Colors.black : color, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 10
                              )
                            )
                          ),
                        ),
                        title: Text(
                          city.name, 
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, 
                            fontSize: 13, 
                            color: kPrimaryBlack
                          )
                        ),
                      ),
                    );
                  }),
                  
                // Little spacer between groups
                if(isExpanded) const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// --- CITY CONTENT AREA (Professional Admin Style) ---



class _CityContentArea extends StatefulWidget {
  final DestinationModel city;
  final Color themeColor;
  
  const _CityContentArea({super.key, required this.city, required this.themeColor});

  @override
  State<_CityContentArea> createState() => _CityContentAreaState();
}

class _CityContentAreaState extends State<_CityContentArea> {
  final DatabaseService _db = DatabaseService();
  bool _isUploadingHeader = false;
  //final List<String> kCountries = ['China', 'Japan', 'Indonesia', 'Thailand', 'Vietnam', 'Other'];
  void _showEditCityInfoDialog() {
    final nameCtrl = TextEditingController(text: widget.city.name);
    final descCtrl = TextEditingController(text: widget.city.description);
    String selectedCountry = widget.city.country;
    
    if (!kCountries.contains(selectedCountry)) {
      selectedCountry = 'Other';
    }

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Destination Details"),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCountry,
                  decoration: const InputDecoration(labelText: "Country", filled: true, fillColor: kBgColor),
                  items: kCountries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => selectedCountry = val!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  validator: (v) => v!.trim().isEmpty ? "Required" : null,
                  decoration: const InputDecoration(labelText: "City Name", filled: true, fillColor: kBgColor),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: "Description", 
                    filled: true, 
                    fillColor: kBgColor,
                    alignLabelWithHint: true
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel",style: TextStyle(color: Colors.red))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPrimaryBlack),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final updatedCity = DestinationModel(
                    id: widget.city.id,
                    name: nameCtrl.text.trim(),
                    country: selectedCountry,
                    description: descCtrl.text.trim(),
                    imageUrl: widget.city.imageUrl,
                  );

                  await _db.updateDestination(updatedCity);
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("Save Changes"),
          )
        ],
      ),
    );
  }

  Future<void> _uploadCityHeaderImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() => _isUploadingHeader = true);
    try {
      final bytes = await image.readAsBytes();
      final ref = FirebaseStorage.instance.ref().child('cities/${widget.city.id}_header.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('destinations').doc(widget.city.id).update({'imageUrl': url});
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUploadingHeader = false);
    }
  }

  void _confirmDeleteCity() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete City?"),
        content: const Text("This action will permanently delete the city and all associated spots."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel",style: TextStyle(color: Colors.red))),
          TextButton(
            onPressed: () {
              _db.deleteDestination(widget.city.id);
              Navigator.pop(ctx);
              if (MediaQuery.of(context).size.width < kMobileBreakpoint) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- COMPACT ADMIN HEADER ---
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: widget.themeColor,
                  borderRadius: BorderRadius.circular(8),
                  image: widget.city.imageUrl.isNotEmpty
                    ? DecorationImage(image: NetworkImage(widget.city.imageUrl), fit: BoxFit.cover)
                    : null
                ),
                child: widget.city.imageUrl.isEmpty 
                  ? const Icon(Icons.location_city, color: Colors.white) 
                  : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(widget.city.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryBlack)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kBgColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: kBorderColor)
                          ),
                          child: Text(widget.city.country.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTextSecondary)),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.city.description.isEmpty ? "No description provided." : widget.city.description,
                      style: const TextStyle(fontSize: 13, color: kTextSecondary),
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _showEditCityInfoDialog,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text("Info"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryBlack,
                  side: const BorderSide(color: kBorderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _uploadCityHeaderImage,
                icon: _isUploadingHeader 
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.image_outlined, size: 16),
                label: const Text("Cover"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryBlack,
                  side: const BorderSide(color: kBorderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _confirmDeleteCity,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: "Delete City",
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: kBorderColor),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: const Color(0xFFFAFAFA),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StreamBuilder<List<SpotModel>>(
                stream: _db.getSpots(widget.city.id),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return Text("$count Spots Found", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary));
                }
              ),
              FilledButton.icon(
                onPressed: () => _showSpotDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Add Spot"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              )
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<SpotModel>>(
            stream: _db.getSpots(widget.city.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final spots = snapshot.data ?? [];

              if (spots.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("No spots yet", style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("Add a spot to start building the itinerary", style: TextStyle(color: kTextSecondary, fontSize: 12)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: spots.length,
                itemBuilder: (context, index) => _AdminSpotCard(
                  spot: spots[index],
                  themeColor: widget.themeColor,
                  onEdit: () => _showSpotDialog(context, existingSpot: spots[index]),
                  onDelete: () => _db.deleteSpot(widget.city.id, spots[index].id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSpotDialog(BuildContext context, {SpotModel? existingSpot}) {
    showDialog(
      context: context,
      builder: (context) => _SpotEditorDialog(
        cityId: widget.city.id, 
        themeColor: widget.themeColor,
        existingSpot: existingSpot,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// --- ADMIN SPOT CARD (UPDATED with Currency Display) ---
// ---------------------------------------------------------------------------

class _AdminSpotCard extends StatelessWidget {
  final SpotModel spot;
  final Color themeColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminSpotCard({
    required this.spot,
    required this.themeColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // UPDATED: Get Currency from Spot Model (default to RMB if null)
    // Note: Ensure SpotModel has a 'currency' field
    final String currencyCode = (spot as dynamic).currency ?? 'RMB'; 

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorderColor),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.02), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Image Thumbnail
            Container(
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                image: spot.imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(spot.imageUrl), fit: BoxFit.cover) : null,
              ),
              child: spot.imageUrl.isEmpty 
                ? const Icon(Icons.image_not_supported_outlined, color: Colors.grey) 
                : null,
            ),
            
            // 2. Main Content
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(spot.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlack))),
                        ...spot.categories.take(3).map((c) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey[300]!)),
                            child: Text(c, style: const TextStyle(fontSize: 10, color: kPrimaryBlack, fontWeight: FontWeight.w500)),
                          ),
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      spot.description.isNotEmpty ? spot.description : "No description provided.",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: kTextSecondary, height: 1.4),
                    ),
                    const Spacer(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: kTextSecondary),
                        const SizedBox(width: 4),
                        Text(spot.duration.isNotEmpty ? spot.duration : "N/A", style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                        const SizedBox(width: 16),
                        if(spot.locationUrl.isNotEmpty) ...[
                          Icon(Icons.link, size: 14, color: themeColor),
                          const SizedBox(width: 4),
                          Text("Map Linked", style: TextStyle(fontSize: 12, color: themeColor, fontWeight: FontWeight.w600)),
                        ]
                      ],
                    )
                  ],
                ),
              ),
            ),
            
            // 3. Data & Actions Column
            Container(
              width: 180,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: kBorderColor)),
                color: Color(0xFFFAFAFA),
                borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ActionButton(icon: Icons.edit, color: Colors.blue, onTap: onEdit),
                      const SizedBox(width: 8),
                      _ActionButton(icon: Icons.delete, color: Colors.red, onTap: onDelete),
                    ],
                  ),
                  const Spacer(),
                  Text("ENTRY FEES ($currencyCode)", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTextSecondary)),
                  const SizedBox(height: 6),
                  _CompactPriceRow(label: "Adult", price: spot.prices['Adult'] ?? 0, currency: currencyCode),
                  _CompactPriceRow(label: "Child", price: spot.prices['Child'] ?? 0, currency: currencyCode),
                  _CompactPriceRow(label: "Student", price: spot.prices['Student'] ?? 0, currency: currencyCode),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

class _CompactPriceRow extends StatelessWidget {
  final String label;
  final double price;
  final String currency;
  const _CompactPriceRow({required this.label, required this.price, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (price == 0) return const SizedBox.shrink();
    // Simple format
    final format = NumberFormat.simpleCurrency(name: currency, decimalDigits: 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
          Text(format.format(price), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// --- SPOT EDITOR (UPDATED with Currency Dropdown) ---
// ---------------------------------------------------------------------------

class _SpotEditorDialog extends StatefulWidget {
  final String cityId;
  final Color themeColor;
  final SpotModel? existingSpot;

  const _SpotEditorDialog({required this.cityId, required this.themeColor, this.existingSpot});

  @override
  State<_SpotEditorDialog> createState() => _SpotEditorDialogState();
}

class _SpotEditorDialogState extends State<_SpotEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _locationUrlCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _priceAdult;
  late TextEditingController _priceChild;
  late TextEditingController _priceSenior;
  late TextEditingController _priceStudent;

  final List<String> _selectedCategories = [];
  final List<String> _allCategories = ['Scenery', 'Food', 'Shopping', 'Hotel', 'Adventure', 'Culture', 'Transport', 'Nature', 'Museum'];
  
  XFile? _imageFile;
  Uint8List? _webImageBytes;
  bool _isUploading = false;
  String? _existingImageUrl;
  
  // UPDATED: Currency Selection
  String _selectedCurrency = 'RMB'; 

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existingSpot?.name ?? '');
    _descCtrl = TextEditingController(text: widget.existingSpot?.description ?? '');
    _locationUrlCtrl = TextEditingController(text: widget.existingSpot?.locationUrl ?? '');
    _durationCtrl = TextEditingController(text: widget.existingSpot?.duration ?? '');
    
    _priceAdult = TextEditingController(text: (widget.existingSpot?.prices['Adult'] ?? 0) == 0 ? '' : widget.existingSpot!.prices['Adult'].toString());
    _priceChild = TextEditingController(text: (widget.existingSpot?.prices['Child'] ?? 0) == 0 ? '' : widget.existingSpot!.prices['Child'].toString());
    _priceSenior = TextEditingController(text: (widget.existingSpot?.prices['Senior'] ?? 0) == 0 ? '' : widget.existingSpot!.prices['Senior'].toString());
    _priceStudent = TextEditingController(text: (widget.existingSpot?.prices['Student'] ?? 0) == 0 ? '' : widget.existingSpot!.prices['Student'].toString());

    if (widget.existingSpot != null) {
      _selectedCategories.addAll(widget.existingSpot!.categories);
      _existingImageUrl = widget.existingSpot!.imageUrl;
      // Load currency if exists
      _selectedCurrency = (widget.existingSpot as dynamic).currency ?? 'RMB';
    } else {
      _selectedCategories.add(_allCategories.first);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageFile = image;
        _webImageBytes = bytes;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a category")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      if (widget.existingSpot != null) {
        await _updateExistingSpot();
      } else {
        await _createNewSpot();
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _createNewSpot() async {
    String imageUrl = '';
    if (_webImageBytes != null) {
      final ref = FirebaseStorage.instance.ref().child('spots/${widget.cityId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putData(_webImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
      imageUrl = await ref.getDownloadURL();
    }

    final spot = _buildSpotModel(id: '', imageUrl: imageUrl);
    await DatabaseService().addSpot(widget.cityId, spot);
  }

  Future<void> _updateExistingSpot() async {
    String imageUrl = _existingImageUrl ?? '';
    
    if (_webImageBytes != null) {
      final ref = FirebaseStorage.instance.ref().child('spots/${widget.cityId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putData(_webImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
      imageUrl = await ref.getDownloadURL();
    }

    final spot = _buildSpotModel(id: widget.existingSpot!.id, imageUrl: imageUrl);
    await DatabaseService().updateSpot(widget.cityId, spot);
  }

  SpotModel _buildSpotModel({required String id, required String imageUrl}) {
    return SpotModel(
      id: id,
      name: _nameCtrl.text,
      categories: _selectedCategories,
      description: _descCtrl.text,
      imageUrl: imageUrl,
      locationUrl: _locationUrlCtrl.text,
      duration: _durationCtrl.text,
      // UPDATED: Save Currency
      currency: _selectedCurrency, 
      prices: {
        'Adult': double.tryParse(_priceAdult.text) ?? 0,
        'Child': double.tryParse(_priceChild.text) ?? 0,
        'Senior': double.tryParse(_priceSenior.text) ?? 0,
        'Student': double.tryParse(_priceStudent.text) ?? 0,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSpot != null;
    final currencySymbol = NumberFormat.simpleCurrency(name: _selectedCurrency).currencySymbol;

    final inputDecor = InputDecoration(
      filled: true, fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: kTextSecondary, fontSize: 13),
      isDense: true,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  Text(isEditing ? "Edit Destination Spot" : "Add New Spot", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryBlack)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: DottedBorder(
                              child: Container(
                                width: 110, height: 110,
                                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                                child: _webImageBytes != null
                                  ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_webImageBytes!, fit: BoxFit.cover))
                                  : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                                      ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_existingImageUrl!, fit: BoxFit.cover))
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_a_photo, size: 24, color: Colors.grey[400]),
                                            const SizedBox(height: 8),
                                            Text("Photo", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                          ],
                                        ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameCtrl,
                                  decoration: inputDecor.copyWith(labelText: "Spot Name"),
                                  validator: (v) => v!.isEmpty ? "Required" : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _locationUrlCtrl,
                                  decoration: inputDecor.copyWith(labelText: "Maps URL", prefixIcon: const Icon(Icons.link, size: 16)),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      const Text("Categories", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryBlack)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _allCategories.map((c) {
                          final isSelected = _selectedCategories.contains(c);
                          return FilterChip(
                            label: Text(c, style: TextStyle(fontSize: 11, color: isSelected ? widget.themeColor : kPrimaryBlack)),
                            selected: isSelected,
                            onSelected: (v) {
                              setState(() {
                                if(isSelected) { if(_selectedCategories.length > 1) _selectedCategories.remove(c); }
                                else { _selectedCategories.add(c); }
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: widget.themeColor.withOpacity(0.1),
                            checkmarkColor: widget.themeColor,
                            side: BorderSide(color: isSelected ? widget.themeColor : Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 20),
                      TextFormField(controller: _descCtrl, maxLines: 3, decoration: inputDecor.copyWith(labelText: "Description")),
                      const SizedBox(height: 12),
                      TextFormField(controller: _durationCtrl, decoration: inputDecor.copyWith(labelText: "Duration (e.g., 2 hours)", prefixIcon: const Icon(Icons.access_time, size: 16))),
                      
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: kBorderColor),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[50]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // UPDATED: Header with Currency Dropdown
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Entry Prices ($currencySymbol)", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryBlack)),
                                SizedBox(
                                  width: 90,
                                  height: 35,
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCurrency,
                                    decoration: inputDecor.copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 10), labelText: null),
                                    items: [
                                      'IDR', 'RMB', 'EUR', 'USD', 'SGD', 'MYR',
                                      'JPY', 'CHF', 'KRW', 'TWD', 'HKD', 'MOP', 'AUD',
                                    ].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                    onChanged: (val) => setState(() => _selectedCurrency = val!),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildPriceInput("Adult", _priceAdult, inputDecor, currencySymbol)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildPriceInput("Child", _priceChild, inputDecor, currencySymbol)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildPriceInput("Student", _priceStudent, inputDecor, currencySymbol)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: kTextSecondary))),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isUploading ? null : _handleSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.themeColor,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isUploading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : Text(isEditing ? "Update Details" : "Save Spot"),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPriceInput(String label, TextEditingController ctrl, InputDecoration decor, String symbol) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: decor.copyWith(labelText: label, prefixText: "$symbol ", contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
    );
  }
}