import 'expense_model.dart';
import '../../people/domain/member_model.dart';

class BalanceCalculator {
  /// Calculates who owes whom.
  /// Returns a list of 'Payment' suggestions (e.g. "A pays B $10").
  /// Calculates balances based on the minimize flag.
  static List<BalanceTransfer> calculateBalances(
    List<Expense> expenses,
    List<Member> members, {
    bool minimize = true,
  }) {
    if (minimize) {
      return calculateNetBalances(expenses, members);
    } else {
      return calculateDirectDebts(expenses, members);
    }
  }

  /// Calculates who owes whom (Simplified/Net Debts).
  static List<BalanceTransfer> calculateNetBalances(
    List<Expense> expenses,
    List<Member> members,
  ) {
    // 1. Calculate net balance for each member
    // + means they paid more than their share (they are owed money)
    // - means they paid less than their share (they owe money)
    final balances = <int, double>{};

    for (var member in members) {
      balances[member.id] = 0.0;
    }

    for (var expense in expenses) {
      // Payer gets + amount
      balances[expense.payerId] =
          (balances[expense.payerId] ?? 0) + expense.amount;

      // Splitters get - split_amount
      for (var split in expense.splits) {
        balances[split.memberId] =
            (balances[split.memberId] ?? 0) - split.amount;
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

      final amount = debtor.amount < creditor.amount
          ? debtor.amount
          : creditor.amount;

      transfers.add(
        BalanceTransfer(
          fromMemberId: debtor.memberId,
          toMemberId: creditor.memberId,
          amount: amount,
        ),
      );

      debtor.amount -= amount;
      creditor.amount -= amount;

      if (debtor.amount < 0.01) debtIdx++;
      if (creditor.amount < 0.01) credIdx++;
    }

    return transfers;
  }

  /// Calculates direct pairwise debts without transitive simplification.
  static List<BalanceTransfer> calculateDirectDebts(
    List<Expense> expenses,
    List<Member> members,
  ) {
    // Map: FromId -> ToId -> Amount
    final debts = <int, Map<int, double>>{};

    // 1. Accumulate all debts
    for (var expense in expenses) {
      final payerId = expense.payerId;
      for (var split in expense.splits) {
        if (split.memberId == payerId) continue; // Skip self-debt

        // User (split.memberId) owes Payer (payerId)
        debts.putIfAbsent(split.memberId, () => {});
        final currentDebt = debts[split.memberId]![payerId] ?? 0.0;
        debts[split.memberId]![payerId] = currentDebt + split.amount;
      }
    }

    final transfers = <BalanceTransfer>[];

    // 2. Simplify mutual debts (A->B and B->A)
    final allMemberIds = members.map((m) => m.id).toSet();
    // Add any IDs found in debts that might not be in members list (safety)
    debts.keys.forEach(allMemberIds.add);
    for (var m in debts.values) {
      m.keys.forEach(allMemberIds.add);
    }

    final sortedIds = allMemberIds.toList()..sort();

    for (int i = 0; i < sortedIds.length; i++) {
      for (int j = i + 1; j < sortedIds.length; j++) {
        final id1 = sortedIds[i];
        final id2 = sortedIds[j];

        final debt1to2 = debts[id1]?[id2] ?? 0.0;
        final debt2to1 = debts[id2]?[id1] ?? 0.0;

        if (debt1to2 > debt2to1) {
          final net = debt1to2 - debt2to1;
          if (net > 0.01) {
            transfers.add(
              BalanceTransfer(fromMemberId: id1, toMemberId: id2, amount: net),
            );
          }
        } else if (debt2to1 > debt1to2) {
          final net = debt2to1 - debt1to2;
          if (net > 0.01) {
            transfers.add(
              BalanceTransfer(fromMemberId: id2, toMemberId: id1, amount: net),
            );
          }
        }
      }
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
