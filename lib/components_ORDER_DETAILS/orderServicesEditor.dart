import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/pdfEditor/service_editor.dart';
import 'package:crmx/service_model.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderServicesEditor extends StatelessWidget {
  final String orderId;
  final DateTime orderStartDate;
  final DateTime orderEndDate;
  final OrderModel orderModel; 

  const OrderServicesEditor({
    super.key,
    required this.orderId,
    required this.orderStartDate,
    required this.orderEndDate,
    required this.orderModel,
  });

  @override
  Widget build(BuildContext context) {
    final servicesRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .collection('services');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: servicesRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Error loading services');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(Icons.layers_clear, size: 40, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text(
                    'No services added yet',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final doc = docs[index];
            return _ServiceEditorTile(
              orderId: orderId,
              serviceId: doc.id,
              data: doc.data(),
              orderStartDate: orderStartDate,
              orderEndDate: orderEndDate,
              orderModel: orderModel,
            );
          },
        );
      },
    );
  }
}

class _ServiceEditorTile extends StatefulWidget {
  final String orderId;
  final String serviceId;
  final Map<String, dynamic> data;
  final DateTime orderStartDate;
  final DateTime orderEndDate;
  final OrderModel orderModel;

  const _ServiceEditorTile({
    required this.orderId,
    required this.serviceId,
    required this.data,
    required this.orderStartDate,
    required this.orderEndDate,
    required this.orderModel,
  });

  @override
  State<_ServiceEditorTile> createState() => _ServiceEditorTileState();
}

class _ServiceEditorTileState extends State<_ServiceEditorTile> with SingleTickerProviderStateMixin {
  late TextEditingController _daysCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _internalCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _detailsCtrl;
  late TextEditingController _supplierCtrl;

  late DateTime _serviceStartDate;
  late DateTime _serviceEndDate;
  
  // --- NEW: Currency State ---
  String _selectedCurrency = 'RMB'; 
  
  bool _isSaving = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final days = (widget.data['days'] as num?)?.toInt() ?? 1;
    // --- FIX START: Check for both naming conventions ---
    final price = (widget.data['pricePerDay'] ?? widget.data['price_per_day'] as num?)?.toDouble() ?? 0.0;
    final modal = (widget.data['costPerDay'] ?? widget.data['modal_per_day'] as num?)?.toDouble() ?? 0.0;
    // --- FIX END ---
    final discount = (widget.data['discount'] as num?)?.toDouble() ?? 0.0;
    final details = (widget.data['description'] as String?) ?? "";
    final supplier = (widget.data['supplier_name'] as String?) ?? "";
    
    // Load Currency
    _selectedCurrency = widget.data['currency'] ?? 'RMB';

    _daysCtrl = TextEditingController(text: days.toString());
    _priceCtrl = TextEditingController(text: price.toStringAsFixed(2));
    _internalCtrl = TextEditingController(text: modal.toStringAsFixed(2));
    _discountCtrl = TextEditingController(text: discount.toStringAsFixed(2));
    _detailsCtrl = TextEditingController(text: details);
    _supplierCtrl = TextEditingController(text: supplier);

    if (widget.data['start_date'] != null) {
      _serviceStartDate = (widget.data['start_date'] as Timestamp).toDate();
    } else {
      _serviceStartDate = widget.orderStartDate;
    }

    if (widget.data['end_date'] != null) {
      _serviceEndDate = (widget.data['end_date'] as Timestamp).toDate();
    } else {
      _serviceEndDate = _serviceStartDate.add(Duration(days: days > 0 ? days - 1 : 0));
    }
  }

  String get _currencySymbol {
    return NumberFormat.simpleCurrency(name: _selectedCurrency).currencySymbol;
  }

  Future<void> _deleteService() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Service?'),
        content: const Text('Are you sure you want to remove this service? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).collection('services').doc(widget.serviceId).delete();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting service: $e')));
      }
    }
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: widget.orderStartDate.subtract(const Duration(days: 30)), 
      lastDate: widget.orderEndDate.add(const Duration(days: 30)),
      initialDateRange: DateTimeRange(start: _serviceStartDate, end: _serviceEndDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Colors.black, onPrimary: Colors.white)),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _serviceStartDate = picked.start;
        _serviceEndDate = picked.end;
        final int newDuration = picked.end.difference(picked.start).inDays + 1;
        _daysCtrl.text = newDuration.toString();
      });
    }
  }

  void _navigateToPdfEditor() {
    final currentData = Map<String, dynamic>.from(widget.data);
    currentData['days'] = int.tryParse(_daysCtrl.text) ?? 1;
    currentData['price_per_day'] = double.tryParse(_priceCtrl.text) ?? 0.0;
    currentData['modal_per_day'] = double.tryParse(_internalCtrl.text) ?? 0.0;
    currentData['discount'] = double.tryParse(_discountCtrl.text) ?? 0.0;
    currentData['description'] = _detailsCtrl.text;
    currentData['supplier_name'] = _supplierCtrl.text;
    currentData['currency'] = _selectedCurrency; // Pass currency
    currentData['start_date'] = Timestamp.fromDate(_serviceStartDate);
    currentData['end_date'] = Timestamp.fromDate(_serviceEndDate);

    Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceVoucherEditorPage(
      orderId: widget.orderId, 
      serviceData: currentData, 
      orderModel: widget.orderModel
    )));
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    FocusScope.of(context).unfocus(); 

    try {
      final days = int.tryParse(_daysCtrl.text) ?? 1;
      final price = double.tryParse(_priceCtrl.text) ?? 0.0;
      final modal = double.tryParse(_internalCtrl.text) ?? 0.0;
      final discount = double.tryParse(_discountCtrl.text) ?? 0.0;
      
      final dateDiff = _serviceEndDate.difference(_serviceStartDate).inDays + 1;
      DateTime finalEnd = _serviceEndDate;
      if (dateDiff != days) {
        finalEnd = _serviceStartDate.add(Duration(days: days > 0 ? days - 1 : 0));
      }

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .collection('services')
          .doc(widget.serviceId)
          .update({
        'days': days,
        'price_per_day': price,
        'modal_per_day': modal,
        'discount': discount,
        'currency': _selectedCurrency, // Save Currency
        'description': _detailsCtrl.text,
        'supplier_name': _supplierCtrl.text,
        'start_date': Timestamp.fromDate(_serviceStartDate),
        'end_date': Timestamp.fromDate(finalEnd),
      });

      if (mounted) {
        setState(() {
          _serviceEndDate = finalEnd;
          _isExpanded = false; 
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Service updated'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green[700],
          duration: const Duration(milliseconds: 1000),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.data['name'] as String? ?? 'Service';
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isExpanded ? Colors.black26 : Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(_isExpanded ? 0.06 : 0.03), blurRadius: _isExpanded ? 15 : 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER ---
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.vertical(top: const Radius.circular(16), bottom: Radius.circular(_isExpanded ? 0 : 16)),
            child: InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.vertical(top: const Radius.circular(16), bottom: Radius.circular(_isExpanded ? 0 : 16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Icon(_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                          if (!_isExpanded)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              // Display price with correct currency symbol
                              child: Text(
                                "${dateFormat.format(_serviceStartDate)} - ${dateFormat.format(_serviceEndDate)} • $_currencySymbol${_priceCtrl.text}/day",
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: _navigateToPdfEditor, icon: const Icon(Icons.picture_as_pdf_outlined, size: 20), style: IconButton.styleFrom(backgroundColor: Colors.grey[100])),
                    const SizedBox(width: 8),
                    IconButton(onPressed: _deleteService, icon: const Icon(Icons.delete_outline, size: 20), style: IconButton.styleFrom(foregroundColor: Colors.red[700], backgroundColor: Colors.red[50])),
                  ],
                ),
              ),
            ),
          ),
          
          // --- BODY ---
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isExpanded 
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      // DATES
                      InkWell(
                        onTap: _pickDateRange,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                          child: Row(
                            children: [
                              Icon(Icons.date_range, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Service Dates", style: TextStyle(fontSize: 10, color: Colors.blue[800], fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text("${dateFormat.format(_serviceStartDate)} - ${dateFormat.format(_serviceEndDate)}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                ],
                              ),
                              const Spacer(),
                              const Icon(Icons.edit, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      _ModernInputField(controller: _supplierCtrl, label: 'Supplier Name', icon: Icons.store_outlined),
                      const SizedBox(height: 12),

                      // FINANCIALS ROW
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Duration
                          Expanded(flex: 2, child: _ModernInputField(controller: _daysCtrl, label: 'Days', icon: Icons.timer_outlined, isInteger: true)),
                          const SizedBox(width: 12),
                          // Currency Selector
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                                  child: Text("Currency", style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                ),
                                Container(
                                  height: 52, // Match TextField height approximately
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCurrency,
                                      isExpanded: true,
                                      items: [
                                        'IDR', 'RMB', 'EUR', 'USD', 'SGD', 'MYR',
                                        'JPY', 'CHF', 'KRW', 'TWD', 'HKD', 'MOP', 'AUD',
                                      ].map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(() => _selectedCurrency = val!),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Price
                          Expanded(flex: 3, child: _ModernInputField(controller: _priceCtrl, label: 'Price / Day', prefixText: '$_currencySymbol ')),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // COST & DISCOUNT
                      Row(
                        children: [
                          Expanded(child: _ModernInputField(controller: _internalCtrl, label: 'Cost / Day', prefixText: '$_currencySymbol ', textColor: Colors.amber[800])),
                          const SizedBox(width: 12),
                          Expanded(child: _ModernInputField(controller: _discountCtrl, label: 'Discount', prefixText: '$_currencySymbol ', textColor: Colors.green[700])),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _ModernInputField(controller: _detailsCtrl, label: 'Details / Notes', textColor: Colors.black, maxLines: 2),
                          
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveChanges,
                          //style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)) : const Icon(Icons.check, size: 18),
                          label: Text(_isSaving ? 'Saving Changes...' : 'Save Changes'),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ModernInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? prefixText;
  final IconData? icon;
  final bool isInteger;
  final Color? textColor;
  final int maxLines;

  const _ModernInputField({
    required this.controller,
    required this.label,
    this.prefixText,
    this.icon,
    this.isInteger = false,
    this.textColor,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ),
        TextFormField(
          controller: controller,
          keyboardType: isInteger ? TextInputType.number : (maxLines > 1 ? TextInputType.multiline : TextInputType.numberWithOptions(decimal: true)),
          maxLines: maxLines,
          style: TextStyle(fontWeight: FontWeight.w600, color: textColor ?? Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.grey[100],
            prefixIcon: icon != null ? Icon(icon, size: 16, color: Colors.grey[500]) : null,
            prefixText: prefixText,
            prefixStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black12, width: 1.5)),
          ),
        ),
      ],
    );
  }
}