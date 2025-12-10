import 'expense_model.dart';
import '../../people/domain/member_model.dart';

class BalanceCalculator {
  /// Calculates who owes whom.
  /// Returns a list of 'Payment' suggestions (e.g. "A pays B $10").
  static List<BalanceTransfer> calculateBalances(List<Expense> expenses, List<Member> members) {
    // 1. Calculate net balance for each member
    // + means they paid more than their share (they are owed money)
    // - means they paid less than their share (they owe money)
    final balances = <int, double>{};

    for (var member in members) {
      balances[member.id] = 0.0;
    }

    for (var expense in expenses) {
      // Payer gets + amount
      balances[expense.payerId] = (balances[expense.payerId] ?? 0) + expense.amount;

      // Splitters get - split_amount
      for (var split in expense.splits) {
        balances[split.memberId] = (balances[split.memberId] ?? 0) - split.amount;
      }
    }

    // 2. Separate into debtors (-) and creditors (+)
    final debtors = <DebtNode>[];
    final creditors = <DebtNode>[];

    balances.forEach((id, amount) {
      // Round to 2 decimal places to avoid floating point errors
      final roundedAmount = (amount * 100).round() / 100.0;
      if (roundedAmount < -0.01) {
        debtors.add(DebtNode(id, -roundedAmount)); // Store as positive debt
      } else if (roundedAmount > 0.01) {
        creditors.add(DebtNode(id, roundedAmount));
      }
    });

    // 3. Match debts (Basic Greedy Algorithm)
    // Sort by magnitude to minimize number of transactions (heuristic)
    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));

    final transfers = <BalanceTransfer>[];

    var debtIdx = 0;
    var credIdx = 0;

    while (debtIdx < debtors.length && credIdx < creditors.length) {
      final debtor = debtors[debtIdx];
      final creditor = creditors[credIdx];

      final amount = debtor.amount < creditor.amount ? debtor.amount : creditor.amount;
      
      transfers.add(BalanceTransfer(
        fromMemberId: debtor.memberId,
        toMemberId: creditor.memberId,
        amount: amount,
      ));

      debtor.amount -= amount;
      creditor.amount -= amount;

      if (debtor.amount < 0.01) debtIdx++;
      if (creditor.amount < 0.01) credIdx++;
    }

    return transfers;
  }
}

class DebtNode {
  final int memberId;
  double amount;

  DebtNode(this.memberId, this.amount);
}

class BalanceTransfer {
  final int fromMemberId;
  final int toMemberId;
  final double amount;

  BalanceTransfer({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
  });
}
