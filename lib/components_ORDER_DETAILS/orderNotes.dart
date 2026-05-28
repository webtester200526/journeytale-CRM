import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OrderNotesWidget extends StatefulWidget {
  final String orderId;
  final String initialNotes;

  const OrderNotesWidget({
    super.key,
    required this.orderId,
    required this.initialNotes,
  });

  @override
  State<OrderNotesWidget> createState() => _OrderNotesWidgetState();
}

class _OrderNotesWidgetState extends State<OrderNotesWidget> {
  late TextEditingController _controller;
  Timer? _debounce;
  String _status = "Saved"; // Saved, Saving..., or Error

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    // 1. Update status immediately to feedback to user
    setState(() => _status = "Typing...");

    // 2. Cancel previous timer if the user keeps typing
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // 3. Set a new timer (Debounce)
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      _saveToFirestore(value);
    });
  }

  Future<void> _saveToFirestore(String notes) async {
    setState(() => _status = "Saving...");

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'notes': notes});

      if (mounted) {
        setState(() => _status = "Saved");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = "Error saving");
      }
      debugPrint("Error auto-saving notes: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.sticky_note_2_outlined, size: 20, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    "Internal Notes",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              // Status Indicator
             
              Text(
                _status,
                style: TextStyle(
                  fontSize: 12,
                  color: _status == "Error saving" 
                      ? Colors.red 
                      : (_status == "Saved" ? Colors.green : Colors.grey),
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: null, // Allow it to grow
            minLines: 3,
            onChanged: _onTextChanged,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              hintText: "Write details about this order here...",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}