import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/expenses_repository.dart';
import '../../people/domain/member_model.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/currency_utils.dart';
import '../../auth/data/auth_repository.dart';

class SettleUpScreen extends ConsumerStatefulWidget {
  final int groupId;
  final Member payer;
  final Member receiver;
  final double amount;
  final String groupCurrency;

  const SettleUpScreen({
    super.key,
    required this.groupId,
    required this.payer,
    required this.receiver,
    required this.amount,
    required this.groupCurrency,
  });

  @override
  ConsumerState<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends ConsumerState<SettleUpScreen> {
  late TextEditingController _amountController;
  final TextEditingController _dateController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.amount.toStringAsFixed(2),
    );
    _dateController.text = DateFormat.yMMMd().format(_selectedDate);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat.yMMMd().format(picked);
      });
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref
          .read(expensesRepositoryProvider)
          .createExpense(
            groupId: widget.groupId,
            description:
                'Payment from ${widget.payer.name} to ${widget.receiver.name}',
            amount: amount,
            payerId: widget.payer.id,
            category: 'Payment',
            date: _selectedDate,
            splits: {widget.receiver.id: amount},
            isSettlement: true,
          );

      // Refresh User to update balance
      await ref.read(authControllerProvider.notifier).reloadUser();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Settlement recorded!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settle Expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Transfer Icon
            const Icon(Icons.compare_arrows, size: 64, color: Colors.blue),
            const SizedBox(height: 16),

            // Text explanation
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: Theme.of(context).textTheme.headlineSmall,
                children: [
                  TextSpan(
                    text: widget.payer.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' paid '),
                  TextSpan(
                    text: widget.receiver.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Amount Field
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText:
                    'Amount (${CurrencyUtils.getSymbol(widget.groupCurrency)})',
                prefixIcon: const Icon(Icons.credit_card),
                border: const OutlineInputBorder(),
                helperText: 'Enter the amount paid',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // Date Field
            InkWell(
              onTap: _isLoading ? null : () => _selectDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _dateController.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: const Text('Record Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
