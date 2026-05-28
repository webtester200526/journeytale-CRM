
import 'package:crmx/database_service.dart';
import 'package:crmx/itinerary_service.dart';
import 'package:crmx/pdfEditor/itinerary_editor.dart';
import 'package:crmx/service_model.dart';
import 'package:flutter/material.dart';


class ItineraryEditor extends StatefulWidget {
  final String orderId;

  const ItineraryEditor({super.key, required this.orderId});

  @override
  State<ItineraryEditor> createState() => _ItineraryEditorState();
}

class _ItineraryEditorState extends State<ItineraryEditor> {
  final DatabaseService _db = DatabaseService();
  final ItineraryServices _itineraryServices = ItineraryServices();

  bool _isLoading = true;
  bool _isGeneratingAi = false;
  
  // Auto-save state
  bool _isSaving = false;
  String _saveStatus = "Saved";

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
      emptyDays.add({
        'day_number': i,
        'theme': 'Free Day',
        'activities': []
      });
    }
    _itineraryData = {
      'trip_title': 'Manual Itinerary',
      'days': emptyDays
    };
  }

  // --- AUTO SAVE LOGIC ---

  Future<void> _autoSave() async {
    if (_itineraryData == null) return;
    
    setState(() {
      _isSaving = true;
      _saveStatus = "Saving...";
    });

    try {
      await _db.updateOrderItinerary(widget.orderId, _itineraryData!);
      // Artificial delay to let user see "Saving..." briefly if it's too fast
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStatus = "Saved";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStatus = "Error Saving";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Auto-save failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

   void _showAiGenerationDialog() {
    if (_orderContext == null) return;

    final instructionsCtrl = TextEditingController();
    int daysCount = _orderContext!.durationDays;
    
    // Initialize cities
    String defaultCity = _allowedDestinations.contains(_orderContext!.destination) 
        ? _orderContext!.destination 
        : (_allowedDestinations.isNotEmpty ? _allowedDestinations.first : "Unknown");

    List<String> selectedCities = List.filled(daysCount, defaultCity);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Calculate a safe width for the dialog
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
                      "This will overwrite the current itinerary activities.",
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    
                    // Comment Field
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

                    // Dynamic list of Days
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(), 
                      itemCount: daysCount,
                      separatorBuilder: (c, i) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return Row(
                          children: [
                            SizedBox(
                              width: 50, 
                              child: Text("Day ${index + 1}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8)
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedCities[index],
                                    isExpanded: true,
                                    isDense: true, 
                                    items: _allowedDestinations.map((city) {
                                      return DropdownMenuItem(
                                        value: city, 
                                        child: Text(
                                          city, 
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        )
                                      );
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
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel",style: TextStyle(color: Colors.red)),
              ),
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
      final notes = userInstructions.trim().isEmpty 
          ? "Focus on tourist attractions." 
          : userInstructions;

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
      });
      // Trigger Auto Save
      await _autoSave();

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Error: $e")));
    } finally {
      if (mounted) setState(() => _isGeneratingAi = false);
    }
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
              });
              _autoSave(); // Save
              Navigator.pop(ctx);
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  void _showActivityDialog(int dayIndex, {int? activityIndex, Map<String, dynamic>? existingData}) {
    String? selectedLocation = existingData?['location'];
    String? selectedSpot = existingData?['spot'];
    List<String> spotsForLocation = [];
    
    final timeCtrl = TextEditingController(text: existingData?['time'] ?? "09:00");
    final descCtrl = TextEditingController(text: existingData?['description'] ?? "");
    
    bool isEditing = activityIndex != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateBuilder) {
          
          Future<void> _loadSpots(String location) async {
            final spots = await _db.getSpotsForDestination(location);
            if (context.mounted) {
              setStateBuilder(() {
                spotsForLocation = spots;
                if (!spots.contains(selectedSpot)) selectedSpot = null;
              });
            }
          }

          if (selectedLocation != null && spotsForLocation.isEmpty) {
             _loadSpots(selectedLocation!);
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            child: Container(
              width: 500, 
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? "Edit Activity" : "New Activity",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: _buildDialogInput(
                          controller: timeCtrl,
                          label: "Time",
                          hint: "09:00",
                          icon: Icons.access_time,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDialogDropdown(
                          label: "City / Location",
                          value: selectedLocation,
                          items: _allowedDestinations,
                          onChanged: (val) {
                            if (val != null) {
                              setStateBuilder(() {
                                selectedLocation = val;
                                selectedSpot = null;
                              });
                              _loadSpots(val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildDialogDropdown(
                    label: "Attraction / Spot",
                    value: selectedSpot,
                    items: spotsForLocation,
                    hint: selectedLocation == null ? "Select a city first" : "Select a spot",
                    onChanged: (val) => setStateBuilder(() => selectedSpot = val),
                  ),
                  const SizedBox(height: 16),

                  _buildDialogInput(
                    controller: descCtrl,
                    label: "Activity Description",
                    hint: "e.g. Guided tour of the ancient temple...",
                    maxLines: 4,
                    minLines: 3, 
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (selectedLocation != null) {
                            _updateActivityState(
                              dayIndex, 
                              {
                                "time": timeCtrl.text.isEmpty ? "00:00" : timeCtrl.text,
                                "location": selectedLocation,
                                "spot": selectedSpot ?? selectedLocation, 
                                "description": descCtrl.text,
                              },
                              activityIndex: activityIndex
                            );
                            Navigator.pop(ctx);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please select a location"), backgroundColor: Colors.red)
                            );
                          }
                        },
                        child: Text(isEditing ? "Save Changes" : "Add Activity"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDialogInput({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    int maxLines = 1,
    int minLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: minLines,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            prefixIcon: icon != null ? Icon(icon, size: 18, color: Colors.grey) : null,
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
          isExpanded: true,
          style: const TextStyle(fontSize: 14, color: Colors.black),
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  void _updateActivityState(int dayIndex, Map<String, dynamic> activity, {int? activityIndex}) {
    setState(() {
      if (_itineraryData == null) return;
      List<dynamic> days = _itineraryData!['days'];
      Map<String, dynamic> day = days[dayIndex];
      List<dynamic> activities = List.from(day['activities']);

      if (activityIndex != null) {
        // Edit existing
        activities[activityIndex] = activity;
      } else {
        // Add new
        activities.add(activity);
      }
      
      // Sort by time
      activities.sort((a, b) => (a['time'] as String).compareTo(b['time']));
      
      day['activities'] = activities;
    });
    // Trigger Auto Save
    _autoSave();
  }

  void _deleteActivity(int dayIndex, int actIndex) {
    setState(() {
      List<dynamic> days = _itineraryData!['days'];
      List<dynamic> activities = List.from(days[dayIndex]['activities']);
      activities.removeAt(actIndex);
      days[dayIndex]['activities'] = activities;
    });
    // Trigger Auto Save
    _autoSave();
  }

  // --- UI HELPERS ---

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 16,
          offset: const Offset(0, 4)
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.black));
    if (_itineraryData == null) return const Center(child: Text("Could not load itinerary data"));

    final daysList = (_itineraryData!['days'] as List);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_document, size: 18), 
                label: const Text("Download PDF"),
                
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItineraryPdfEditorPage(itineraryData: _itineraryData!, clientName: _orderContext!.name)
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _isGeneratingAi ? null : _showAiGenerationDialog,
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: _isGeneratingAi
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Auto-Fill AI"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
              )
            ]),
            
            // --- AUTO SAVE STATUS INDICATOR ---
            Row(
              children: [
                if (_isSaving) 
                  const SizedBox(
                    width: 12, height: 12, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)
                  )
                else 
                  const Icon(Icons.cloud_done_outlined, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  _saveStatus, 
                  style: TextStyle(
                    color: _saveStatus == "Saved" ? Colors.green : Colors.grey, 
                    fontSize: 12, 
                    fontWeight: FontWeight.bold
                  )
                )
              ],
            )
          ],
        ),
        
        const SizedBox(height: 16),

        // Days List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
                  tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  initiallyExpanded: true,
                  title: Row(
                    children: [
                      Text("Day ${day['day_number']}: ", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Expanded(
                        child: Text(
                          dayTheme, 
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16, color: Colors.blueGrey),
                        onPressed: () => _editDayThemeDialog(dayIndex, dayTheme),
                        tooltip: "Edit Theme",
                      )
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          if ((day['activities'] as List).isEmpty)
                             Padding(
                               padding: const EdgeInsets.all(8.0),
                               child: Text("No activities", style: TextStyle(color: Colors.grey[400])),
                             ),
                          ...(day['activities'] as List).asMap().entries.map((entry) {
                            final actIndex = entry.key;
                            final act = entry.value;
                            
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showActivityDialog(dayIndex, activityIndex: actIndex, existingData: act),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        children: [
                                          Container(
                                            width: 10, height: 10,
                                            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                                          ),
                                          Container(width: 2, height: 40, color: Colors.grey[200]),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("${act['location']}, ${act['spot']}", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                            const SizedBox(height: 4),
                                            Text("${act['time']} • ${act['description']}", style: TextStyle(color: Colors.grey[600], height: 1.4)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                                        onPressed: () => _deleteActivity(dayIndex, actIndex),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0, left: 24, right: 24),
                            child: OutlinedButton.icon(
                              onPressed: () => _showActivityDialog(dayIndex),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text("Add Activity"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                              ),
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}