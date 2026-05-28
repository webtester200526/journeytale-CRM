import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:dotted_border/dotted_border.dart';

// SHARED CURRENCIES LIST

final List<String> kClientCurrencies = [
  'IDR', 'RMB', 'EUR', 'USD', 'SGD', 'MYR',
  'JPY', 'CHF', 'KRW', 'TWD', 'HKD', 'MOP', 'AUD',
];


class PaymentFromClientWidget extends StatefulWidget {
  final String orderId;

  const PaymentFromClientWidget({Key? key, required this.orderId}) : super(key: key);

  @override
  State<PaymentFromClientWidget> createState() => _PaymentFromClientWidgetState();
}

class _PaymentFromClientWidgetState extends State<PaymentFromClientWidget> {
  // Store draft uploads
  final List<PaymentDraft> _drafts = [];
  bool _isUploading = false;
  final NumberFormat _currencyFormat = NumberFormat.decimalPattern();

  @override
  void dispose() {
    for (var draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  // --- ACTIONS ---

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    // Allow picking multiple images
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      for (var img in images) {
        final bytes = await img.readAsBytes();
        setState(() {
          _drafts.add(PaymentDraft(file: img, bytes: bytes));
        });
      }
    }
  }

  void _removeDraft(int index) {
    setState(() {
      _drafts[index].dispose();
      _drafts.removeAt(index);
    });
  }

  Future<void> _submitAll() async {
    // Validate
    if (_drafts.any((d) => d.amountCtrl.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter amounts for all items")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Process all uploads in parallel
      await Future.wait(_drafts.map((draft) async {
        
        // 1. Upload Image
        String fileName = "${DateTime.now().millisecondsSinceEpoch}_${draft.file.name}";
        Reference ref = FirebaseStorage.instance.ref().child('receipts/${widget.orderId}/$fileName');
        
        UploadTask task = ref.putData(draft.bytes, SettableMetadata(contentType: draft.file.mimeType));
        TaskSnapshot snapshot = await task;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // 2. Add to Firestore
        await FirebaseFirestore.instance
            .collection('income')
            .add({
          'amount': double.tryParse(draft.amountCtrl.text) ?? 0.0,
          'currency': draft.currency,
          'comment': draft.commentCtrl.text.trim(),
          'receiptUrl': downloadUrl,
          'fileName': fileName,
          'uploadedAt': FieldValue.serverTimestamp(),
          'orderId' : widget.orderId
        });
      }));

      // 3. Clear UI
      if (mounted) {
        setState(() {
          for (var d in _drafts) { d.dispose(); }
          _drafts.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payments saved successfully"), backgroundColor: Colors.green));
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- UI CONSTRUCTION ---

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Payments From Client", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                  child: const Text("Income", style: TextStyle(fontSize: 10, color: Colors.grey)),
                )
              ],
            ),
          ),
          const Divider(height: 1),

          // 1. HISTORY SECTION (Scrollable)
          Container(
            constraints: const BoxConstraints(maxHeight: 300), // Limit height so it scrolls
            child: _buildHistoryStream(),
          ),

          const Divider(height: 1),

          // 2. UPLOAD SECTION
          Container(
            color: Colors.grey[50], // Slight contrast for input area
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_drafts.isEmpty) 
                  _buildUploadPlaceholder()
                else 
                  Column(
                    children: [
                      ..._drafts.asMap().entries.map((entry) => _buildDraftRow(entry.key, entry.value)).toList(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.add_photo_alternate, size: 16),
                            label: const Text("Add More"),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _isUploading ? null : _submitAll,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                            child: _isUploading 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text("Save ${_drafts.length} Payment${_drafts.length > 1 ? 's' : ''}"),
                          ),
                        ],
                      )
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HISTORY STREAM ---

  Widget _buildHistoryStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
         .collection('income')
          .where('orderId', isEqualTo: widget.orderId) 
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
         
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: Text("No payments recorded yet.", style: TextStyle(color: Colors.grey))),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            
            // Currency Display Logic
            String currency = data['currency'] ?? 'IDR';
            if (currency == 'CNY') currency = 'RMB';
            
            final comment = data['comment'] ?? '';
            final url = data['receiptUrl'] ?? '';
            final timestamp = (data['uploadedAt'] as Timestamp?)?.toDate();

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: GestureDetector(
                onTap: () => _showImageDialog(url),
                child: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                  ),
                ),
              ),
              title: Text(
                "$currency ${_currencyFormat.format(amount)}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (comment.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(comment, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                    ),
                  if (timestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(DateFormat('dd MMM yyyy • HH:mm').format(timestamp), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- EDIT BUTTON ---
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.blueGrey),
                    onPressed: () => _showEditPaymentDialog(
                      doc.id, 
                      amount, 
                      data['currency'] ?? 'IDR', // Pass raw currency code
                      comment
                    ),
                    tooltip: "Edit Payment",
                  ),
                  // --- VIEW RECEIPT BUTTON ---
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18, color: Colors.grey),
                    onPressed: () => _showImageDialog(url),
                    tooltip: "View Receipt",
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- DRAFT INPUT ROWS ---

  Widget _buildDraftRow(int index, PaymentDraft draft) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(draft.bytes, width: 60, height: 60, fit: BoxFit.cover),
          ),
          const SizedBox(width: 16),
          
          // Inputs
          Expanded(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount
                   Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: TextField(
                        controller: draft.amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 18, 
                        ),
                        decoration: _inputDeco("Amount"),
                      ),
                    ),
                  ),

                    const SizedBox(width: 8),
                    // Currency Dropdown
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: draft.currency,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() => draft.currency = newValue);
                            }
                          },
                          items: kClientCurrencies.map<DropdownMenuItem<String>>((String value) {
                            // Display 'RMB' for 'CNY' value
                            String display = value == 'CNY' ? 'RMB' : value;
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(display),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Comment
              SizedBox(
                height: 80,
                child: TextField(
                  controller: draft.commentCtrl,
                  maxLines: null, 
                  expands: true,  
                  textAlignVertical: TextAlignVertical.top, 
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                  decoration: _inputDeco("Comment (Optional)").copyWith(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 10,
                    ),
                  ),
                ),
              ),

              ],
            ),
          ),
          
          // Delete Button
          IconButton(
            onPressed: () => _removeDraft(index),
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          )
        ],
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return GestureDetector(
      onTap: _pickImages,
      child: DottedBorder(
        child: Container(
          width: double.infinity,
          height: 120,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              const Text("Click to upload receipts", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("Supports multiple files", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPERS ---

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.black)),
    );
  }

  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(child: Image.network(url)),
            Positioned(
              top: 0, right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- EDIT DIALOG ---
  void _showEditPaymentDialog(String docId, double currentAmount, String currentCurrency, String currentComment) {
    final TextEditingController amountCtrl = TextEditingController(text: currentAmount.toString());
    final TextEditingController commentCtrl = TextEditingController(text: currentComment);
    String selectedCurrency = currentCurrency;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Edit Payment"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: "Amount",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: selectedCurrency,
                        onChanged: (val) {
                          if (val != null) setState(() => selectedCurrency = val);
                        },
                        items: kClientCurrencies.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c == 'CNY' ? 'RMB' : c),
                        )).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentCtrl,
                    decoration: const InputDecoration(
                      labelText: "Comment",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (amountCtrl.text.isEmpty) return;
                    
                    try {
                      await FirebaseFirestore.instance.collection('income').doc(docId).update({
                        'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                        'currency': selectedCurrency,
                        'comment': commentCtrl.text.trim(),
                      });
                      if (context.mounted) Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated successfully"), backgroundColor: Colors.green));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  },
                  child: const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// --- HELPER CLASS ---

class PaymentDraft {
  final XFile file;
  final Uint8List bytes;
  final TextEditingController amountCtrl = TextEditingController();
  final TextEditingController commentCtrl = TextEditingController();
  String currency = 'IDR';

  PaymentDraft({required this.file, required this.bytes});

  void dispose() {
    amountCtrl.dispose();
    commentCtrl.dispose();
  }
}