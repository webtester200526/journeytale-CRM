import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CurrencyExchangeManager extends StatelessWidget {
  final String orderId;
  const CurrencyExchangeManager({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Currency Exchange", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ElevatedButton.icon(onPressed: () => _showEditorDialog(context, null), icon: const Icon(Icons.currency_exchange, size: 16), label: const Text("New Transaction"), ),
        ]),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('orders').doc(orderId).collection('currency').orderBy('date', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)), child: const Center(child: Text("No transactions.", style: TextStyle(color: Colors.grey))));
            
            return ListView.separated(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: docs.length, separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final d = docs[index].data() as Map<String, dynamic>;
                return _TransactionCard(docId: docs[index].id, data: d, onEdit: () => _showEditorDialog(context, docs[index]), onDelete: () => FirebaseFirestore.instance.collection('orders').doc(orderId).collection('currency').doc(docs[index].id).delete());
              },
            );
          },
        ),
      ],
    );
  }

  void _showEditorDialog(BuildContext context, DocumentSnapshot? doc) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => _CurrencyEditorDialog(orderId: orderId, existingDoc: doc));
  }
}

class _TransactionCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TransactionCard({required this.docId, required this.data, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final profit = (data['profit'] as num?)?.toDouble() ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle), child: const Icon(Icons.swap_horiz, color: Colors.blue)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${data['amount_in']} ${data['currency_in']} → ${data['amount_out']} ${data['currency_out']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("Buy: ${data['buy_rate']} | Sell: ${data['sell_rate']}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text("Profit", style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          Text("${profit.toStringAsFixed(0)} ${data['currency_in']}", style: TextStyle(fontWeight: FontWeight.bold, color: profit >= 0 ? Colors.green : Colors.red)),
        ]),
        const SizedBox(width: 8),
        IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, size: 18, color: Colors.grey)),
        IconButton(onPressed: onDelete, icon: const Icon(Icons.delete, size: 18, color: Colors.red)),
      ]),
    );
  }
}

class _CurrencyEditorDialog extends StatefulWidget {
  final String orderId;
  final DocumentSnapshot? existingDoc;
  const _CurrencyEditorDialog({required this.orderId, this.existingDoc});
  @override
  State<_CurrencyEditorDialog> createState() => _CurrencyEditorDialogState();
}

class _CurrencyEditorDialogState extends State<_CurrencyEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _currencies = [
  'IDR', 'RMB', 'EUR', 'USD', 'SGD', 'MYR',
  'JPY', 'CHF', 'KRW', 'TWD', 'HKD', 'MOP', 'AUD',
];
  String _curIn = 'IDR', _curOut = 'RMB';
  final _amtIn = TextEditingController();
  final _buyRate = TextEditingController();
  final _sellRate = TextEditingController();
  final _amtOut = TextEditingController();
  final _profit = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.existingDoc != null) {
      final d = widget.existingDoc!.data() as Map<String, dynamic>;
      _amtIn.text = d['amount_in'].toString();
      _buyRate.text = d['buy_rate'].toString();
      _sellRate.text = d['sell_rate'].toString();
      _amtOut.text = d['amount_out'].toString();
      _profit.text = d['profit'].toString();
      _curIn = d['currency_in']; _curOut = d['currency_out'];
      _date = (d['date'] as Timestamp).toDate();
    }
    _amtIn.addListener(_calc);
    _buyRate.addListener(_calc);
    _sellRate.addListener(_calc);
  }

  void _calc() {
    double input = double.tryParse(_amtIn.text) ?? 0;
    double buy = double.tryParse(_buyRate.text) ?? 0;
    double sell = double.tryParse(_sellRate.text) ?? 0;
    
    if (sell > 0) {
      double output = input / sell; 
      _amtOut.text = output.toStringAsFixed(2);
      
      if (buy > 0) {
        // Profit = (Sell Rate - Buy Rate) * (Input / Sell Rate)
        // Or simpler: Input - (Output * Buy Rate) -> The margin in Input Currency
        double cost = output * buy;
        double profit = input - cost;
        _profit.text = profit.toStringAsFixed(0);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).collection('currency').doc(widget.existingDoc?.id).set({
      'date': Timestamp.fromDate(_date),
      'amount_in': double.parse(_amtIn.text),
      'currency_in': _curIn,
      'amount_out': double.parse(_amtOut.text),
      'currency_out': _curOut,
      'buy_rate': double.parse(_buyRate.text),
      'sell_rate': double.parse(_sellRate.text),
      'profit': double.parse(_profit.text),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(width: 500, padding: const EdgeInsets.all(24), child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("Exchange Transaction", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _dropdown(_curIn, (v) => setState(() => _curIn=v!))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _input(_amtIn, "Amount In")),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _input(_buyRate, "Buy Rate (Cost)", icon: Icons.arrow_downward)),
          const SizedBox(width: 10),
          Expanded(child: _input(_sellRate, "Sell Rate (Client)", icon: Icons.arrow_upward)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _dropdown(_curOut, (v) => setState(() => _curOut=v!))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _input(_amtOut, "Result (Auto)")),
        ]),
        const SizedBox(height: 10),
        _input(_profit, "Est. Profit", icon: Icons.attach_money),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), child: const Text("Save")))
      ]))),
    );
  }

  Widget _input(TextEditingController c, String l, {IconData? icon}) {
    return TextFormField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l, prefixIcon: icon!=null?Icon(icon, size: 14):null, border: const OutlineInputBorder()));
  }

  Widget _dropdown(String v, ValueChanged<String?> c) {
    return DropdownButtonFormField(value: v, items: _currencies.map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: c, decoration: const InputDecoration(border: OutlineInputBorder()));
  }
}