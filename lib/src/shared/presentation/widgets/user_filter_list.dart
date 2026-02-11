import 'package:flutter/material.dart';
import '../../../features/people/domain/member_model.dart';
import 'user_avatar.dart';

class UserFilterList extends StatelessWidget {
  final List<Member> members;
  final int? selectedMemberId;
  final ValueChanged<int?> onSelected;

  const UserFilterList({
    super.key,
    required this.members,
    required this.selectedMemberId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: members.map((member) {
          final isSelected = selectedMemberId == member.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(member.name),
              selected: isSelected,
              onSelected: (selected) {
                onSelected(selected ? member.id : null);
              },
              avatar: UserAvatar(
                radius: 10,
                avatarUrl: member.avatarUrl,
                name: member.name,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
