import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../people/domain/member_model.dart';

import 'package:equisplit/src/shared/presentation/widgets/user_avatar.dart';

class MemberProfileScreen extends StatelessWidget {
  final Member member;
  const MemberProfileScreen({super.key, required this.member});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Member Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: UserAvatar(
                radius: 50,
                avatarUrl: member.avatarUrl,
                name: member.name,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              member.name,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            if (member.isAdmin == 1) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Text(
                  'Admin',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (member.userId != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verified User',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),
            _buildSectionHeader(context, "Contact Info"),

            if (member.email != null && member.email!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email'),
                subtitle: Text(member.email!),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: member.email!));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Email copied')));
                },
              )
            else
              const ListTile(
                leading: Icon(Icons.email, color: Colors.grey),
                title: Text('Email', style: TextStyle(color: Colors.grey)),
                subtitle: Text(
                  'Not available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),

            if (member.phone != null && member.phone!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Phone'),
                subtitle: Text(member.phone!),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: member.phone!));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Phone copied')));
                },
              )
            else
              const ListTile(
                leading: Icon(Icons.phone, color: Colors.grey),
                title: Text('Phone', style: TextStyle(color: Colors.grey)),
                subtitle: Text(
                  'Not available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),

            const SizedBox(height: 16),
            _buildSectionHeader(context, "Payment Details"),

            if (member.iban != null && member.iban!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.account_balance),
                title: const Text('IBAN'),
                subtitle: Text(member.iban!),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: member.iban!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('IBAN copied to clipboard')),
                    );
                  },
                ),
              )
            else
              const ListTile(
                leading: Icon(Icons.account_balance, color: Colors.grey),
                title: Text('IBAN', style: TextStyle(color: Colors.grey)),
                subtitle: Text(
                  'Not available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}
