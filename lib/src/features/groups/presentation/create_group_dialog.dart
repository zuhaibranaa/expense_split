import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:currency_picker/currency_picker.dart';
import '../../auth/data/auth_repository.dart';
import '../data/groups_repository.dart';

class CreateGroupDialog extends ConsumerStatefulWidget {
  final String defaultCurrency;

  const CreateGroupDialog({super.key, required this.defaultCurrency});

  @override
  ConsumerState<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends ConsumerState<CreateGroupDialog> {
  final _nameController = TextEditingController();
  late String _selectedCurrency;
  Currency? _currency;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.defaultCurrency;
    _currency = CurrencyService().findByCode(_selectedCurrency);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;

    try {
      await ref
          .read(groupsRepositoryProvider)
          .createGroup(_nameController.text.trim(), _selectedCurrency, user.id);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCurrencyPicker() {
    showCurrencyPicker(
      context: context,
      showFlag: true,
      showCurrencyName: true,
      showCurrencyCode: true,
      onSelect: (Currency curr) {
        setState(() {
          _selectedCurrency = curr.code;
          _currency = curr;
        });
      },
      favorite: ['USD', 'EUR', 'GBP', 'INR', 'PKR'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Group', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Group Name',
              hintText: 'e.g. Trip to Paris',
              prefixIcon: Icon(Icons.group),
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
            enabled: !_isLoading,
            onSubmitted: (_) => _createGroup(),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _isLoading ? null : _showCurrencyPicker,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Currency',
                prefixIcon: Icon(Icons.attach_money),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              child: Text(
                _currency != null
                    ? '${_currency!.flag} ${_currency!.code} - ${_currency!.name}'
                    : _selectedCurrency,
                style: TextStyle(color: _isLoading ? Colors.grey : null),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _createGroup,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
