
import 'package:crmx/database_service.dart';
import 'package:crmx/itinerary_service.dart';
import 'package:crmx/service_model.dart';
import 'package:flutter/material.dart';

class ItineraryEditorDialog extends StatefulWidget {
  final String orderId;

  const ItineraryEditorDialog({super.key, required this.orderId});

  @override
  State<ItineraryEditorDialog> createState() => _ItineraryEditorDialogState();
}

class _ItineraryEditorDialogState extends State<ItineraryEditorDialog> {
  final DatabaseService _db = DatabaseService();
  final ItineraryServices _itineraryServices = ItineraryServices();

  bool _isLoading = true;
  bool _isGeneratingAi = false;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  OrderModel? _orderContext;
  Map<String, dynamic>? _itineraryData;
  List<String> _allowedDestinations = [];

  @override
  void initState() {
    super.initState();
    _fetchItineraryData();
  }

  Future<void> _fetchItineraryData() async {
    try {
      final results = await Future.wait([
        _db.getOrder(widget.orderId),
        _db.getDestinationsList(),
      ]);

      final orderMap = results[0] as Map<String, dynamic>?;
      final destinations = results[1] as List<String>;

      if (orderMap != null) {
        final order = OrderModel.fromMap(orderMap, widget.orderId);
        setState(() {
          _orderContext = order;
          _allowedDestinations = destinations;

          if (order.generatedItinerary != null) {
            _itineraryData = Map<String, dynamic>.from(order.generatedItinerary!);
          } else {
            _initEmptyItinerary(order.durationDays);
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading itinerary: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initEmptyItinerary(int days) {
    List<Map<String, dynamic>> emptyDays = [];
    for (int i = 1; i <= days; i++) {
      emptyDays.add({'day_number': i, 'theme': 'Free Day', 'activities': []});
    }
    _itineraryData = {'trip_title': 'Manual Itinerary', 'days': emptyDays};
  }

  // --- ACTIONS ---

  Future<void> _saveChanges() async {
    if (_itineraryData == null) return;
    setState(() => _isSaving = true);
    try {
      await _db.updateOrderItinerary(widget.orderId, _itineraryData!);
      setState(() {
        _hasUnsavedChanges = false;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Itinerary saved successfully"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAiGenerationDialog() {
    if (_orderContext == null) return;

    final instructionsCtrl = TextEditingController();
    int daysCount = _orderContext!.durationDays;

    String defaultCity = _allowedDestinations.contains(_orderContext!.destination)
        ? _orderContext!.destination
        : (_allowedDestinations.isNotEmpty ? _allowedDestinations.first : "Unknown");

    List<String> selectedCities = List.filled(daysCount, defaultCity);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          double dialogWidth = MediaQuery.of(context).size.width * 0.9;
          if (dialogWidth > 400) dialogWidth = 400;

          return AlertDialog(
            title: const Text("Generate AI Itinerary"),
            contentPadding: const EdgeInsets.all(20),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "This will overwrite current activities.",
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: instructionsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Instructions / Notes",
                        hintText: "e.g. 'We love history', 'Less walking'",
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text("City Schedule:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: daysCount,
                      separatorBuilder: (c, i) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return Row(
                          children: [
                            SizedBox(width: 50, child: Text("Day ${index + 1}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedCities[index],
                                    isExpanded: true,
                                    isDense: true,
                                    items: _allowedDestinations.map((city) {
                                      return DropdownMenuItem(value: city, child: Text(city, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setStateDialog(() {
                                          selectedCities[index] = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel",style: TextStyle(color: Colors.red))),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.black),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text("Generate"),
                onPressed: () {
                  Navigator.pop(ctx);
                  _generateAiItinerary(instructionsCtrl.text, selectedCities);
                },
              )
            ],
          );
        },
      ),
    );
  }

  Future<void> _generateAiItinerary(String userInstructions, List<String> dailyCities) async {
    if (_orderContext == null) return;
    setState(() => _isGeneratingAi = true);

    try {
      final notes = userInstructions.trim().isEmpty ? "Focus on tourist attractions." : userInstructions;

      final result = await _itineraryServices.generateItineraryWithAI(
        destination: _orderContext!.destination,
        startDate: _orderContext!.startDate,
        endDate: _orderContext!.endDate,
        serviceNames: _orderContext!.serviceTypes,
        clientNotes: notes,
        allowedDestinations: _allowedDestinations,
        dailyTowns: dailyCities,
      );

      setState(() {
        _itineraryData = result;
        _hasUnsavedChanges = true;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Error: $e")));
    } finally {
      if (mounted) setState(() => _isGeneratingAi = false);
    }
  }

  Future<void> _downloadItineraryPdf() async {
    if (_itineraryData == null || _orderContext == null) return;
    await _itineraryServices.generateAndDownloadItineraryPdf(_itineraryData!, _orderContext!.name);
  }

  // --- EDITING LOGIC ---

  void _editDayThemeDialog(int dayIndex, String currentTheme) {
    final txtCtrl = TextEditingController(text: currentTheme);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Day ${dayIndex + 1} Theme"),
        content: TextField(
          controller: txtCtrl,
          decoration: const InputDecoration(labelText: "Theme Name", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel",style: TextStyle(color: Colors.red))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.black),
            onPressed: () {
              setState(() {
                List<dynamic> days = _itineraryData!['days'];
                days[dayIndex]['theme'] = txtCtrl.text;
                _hasUnsavedChanges = true;
              });
              Navigator.pop(ctx);
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  void _showAddActivityDialog(int dayIndex) {
    String? selectedLocation;
    String? selectedSpot;
    List<String> spotsForLocation = [];
    final timeCtrl = TextEditingController(text: "10:00 AM");
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateBuilder) {
          Future<void> _loadSpots(String location) async {
            final spots = await _db.getSpotsForDestination(location);
            setStateBuilder(() {
              spotsForLocation = spots;
              selectedSpot = null;
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Add Activity"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Location", border: OutlineInputBorder()),
                    items: _allowedDestinations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    initialValue: selectedLocation,
                    onChanged: (val) {
                      if (val != null) {
                        setStateBuilder(() => selectedLocation = val);
                        _loadSpots(val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedLocation != null)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Spot", border: OutlineInputBorder()),
                      items: spotsForLocation.map((spot) => DropdownMenuItem(value: spot, child: Text(spot))).toList(),
                      initialValue: selectedSpot,
                      onChanged: (val) => setStateBuilder(() => selectedSpot = val),
                    ),
                  if (selectedLocation != null) const SizedBox(height: 12),
                  TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: "Time", border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()), maxLines: 2),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel",style: TextStyle(color: Colors.red))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.black),
                onPressed: () {
                  if (selectedLocation != null) {
                    _addActivityToState(dayIndex, {
                      "time": timeCtrl.text,
                      "location": selectedLocation,
                      "spot": selectedSpot,
                      "description": descCtrl.text,
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addActivityToState(int dayIndex, Map<String, dynamic> activity) {
    setState(() {
      if (_itineraryData == null) return;
      List<dynamic> days = _itineraryData!['days'];
      Map<String, dynamic> day = days[dayIndex];
      List<dynamic> activities = List.from(day['activities']);
      activities.add(activity);
      activities.sort((a, b) => (a['time'] as String).compareTo(b['time']));
      day['activities'] = activities;
      _hasUnsavedChanges = true;
    });
  }

  void _deleteActivity(int dayIndex, int actIndex) {
    setState(() {
      List<dynamic> days = _itineraryData!['days'];
      List<dynamic> activities = List.from(days[dayIndex]['activities']);
      activities.removeAt(actIndex);
      days[dayIndex]['activities'] = activities;
      _hasUnsavedChanges = true;
    });
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dialog Constraints for Web
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_itineraryData == null) return const Center(child: Text("Could not load itinerary data"));
    final daysList = (_itineraryData!['days'] as List);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- 1. Header & Toolbar ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Itinerary Editor", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (_hasUnsavedChanges)
                  const Text("Unsaved changes", style: TextStyle(fontSize: 12, color: Colors.amber, fontStyle: FontStyle.italic))
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  onPressed: _downloadItineraryPdf,
                  tooltip: "Download PDF",
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _isGeneratingAi ? null : _showAiGenerationDialog,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: _isGeneratingAi
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("AI Auto-Fill"),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: "Close",
                )
              ],
            )
          ],
        ),
        
        const Divider(height: 32),

        // --- 2. Scrollable Body ---
        Expanded(
          child: ListView.builder(
            itemCount: daysList.length,
            itemBuilder: (context, dayIndex) {
              final day = daysList[dayIndex];
              final dayTheme = day['theme'] ?? "Free Day";

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: _cardDecoration(),
                clipBehavior: Clip.hardEdge,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    shape: Border.all(color: Colors.transparent),
                    collapsedShape: Border.all(color: Colors.transparent),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    initiallyExpanded: true,
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6)),
                          child: Text("Day ${day['day_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(dayTheme, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                          onPressed: () => _editDayThemeDialog(dayIndex, dayTheme),
                          tooltip: "Edit Theme",
                        )
                      ],
                    ),
                    children: [
                      Column(
                        children: [
                          if ((day['activities'] as List).isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text("No activities added yet", style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic)),
                            ),
                          ...(day['activities'] as List).asMap().entries.map((entry) {
                            final act = entry.value;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.grey.shade100))
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 70,
                                    child: Text(act['time'], style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("${act['location']}, ${act['spot']}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text(act['description'], style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, size: 16, color: Colors.red[200]),
                                    onPressed: () => _deleteActivity(dayIndex, entry.key),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            );
                          }),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _showAddActivityDialog(dayIndex),
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text("Add Activity", style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // --- 3. Footer Actions ---
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _hasUnsavedChanges && !_isSaving ? _saveChanges : null,
            style: ElevatedButton.styleFrom(
            
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_hasUnsavedChanges ? "Save Changes" : "No Changes", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        )
      ],
    );
  }
}