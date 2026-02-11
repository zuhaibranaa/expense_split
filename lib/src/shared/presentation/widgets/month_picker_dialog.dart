import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthPickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const MonthPickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<MonthPickerDialog> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Year Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _selectedYear > widget.firstDate.year
                      ? () => setState(() => _selectedYear--)
                      : null,
                ),
                Text(
                  '$_selectedYear',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _selectedYear < widget.lastDate.year
                      ? () => setState(() => _selectedYear++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Months Grid
            SizedBox(
              height: 200,
              width: 300,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final monthDate = DateTime(_selectedYear, index + 1);
                  final isSelected =
                      _selectedYear == widget.initialDate.year &&
                      index + 1 == widget.initialDate.month;
                  final isCurrentMonth =
                      DateTime.now().year == _selectedYear &&
                      DateTime.now().month == index + 1;

                  return InkWell(
                    onTap: () {
                      Navigator.pop(context, monthDate);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : isCurrentMonth
                            ? Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: 0.3)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        border: isCurrentMonth && !isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        DateFormat.MMM().format(monthDate),
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
