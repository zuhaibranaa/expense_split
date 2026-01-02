import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:currency_picker/currency_picker.dart';
import '../data/auth_repository.dart';
import 'package:http/http.dart' as http;

import 'package:image_picker/image_picker.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Not logged in'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => _showAvatarOptions(context, ref, user.avatarUrl),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: user.avatarUrl != null
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    // Add an edit icon overlay if you want, but simple tap is fine for now
                    child: user.avatarUrl == null
                        ? Text(
                            user.name[0],
                            style: const TextStyle(fontSize: 32),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  "Tap avatar to edit",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

              const SizedBox(height: 24),
              _buildSectionHeader("Personal Info"),

              ListTile(
                leading: const Icon(Icons.person),
                title: const Text("Name"),
                subtitle: Text(user.name),
                trailing: const Icon(Icons.edit, size: 16),
                onTap: () => _editField(
                  context,
                  ref,
                  "Name",
                  user.name,
                  (val) => ref
                      .read(authControllerProvider.notifier)
                      .updateProfile(name: val),
                ),
              ),

              ListTile(
                leading: const Icon(Icons.email),
                title: const Text("Email"),
                subtitle: Text(user.email),
                trailing: user.isVerified
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : TextButton(
                        onPressed: () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .requestVerification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Verification email sent!"),
                              ),
                            );
                          }
                        },
                        child: const Text("Verify"),
                      ),
              ),

              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text("Phone"),
                subtitle: Text(user.phone ?? "Not set"),
                trailing: const Icon(Icons.edit, size: 16),
                onTap: () => _editField(
                  context,
                  ref,
                  "Phone",
                  user.phone,
                  (val) => ref
                      .read(authControllerProvider.notifier)
                      .updateProfile(phone: val),
                ),
              ),

              ListTile(
                leading: const Icon(Icons.account_balance),
                title: const Text("IBAN"),
                subtitle: Text(user.iban ?? "Not set"),
                trailing: const Icon(Icons.edit, size: 16),
                onTap: () => _editField(
                  context,
                  ref,
                  "IBAN",
                  user.iban,
                  (val) => ref
                      .read(authControllerProvider.notifier)
                      .updateProfile(iban: val),
                ),
              ),

              const SizedBox(height: 24),
              _buildSectionHeader("Settings"),

              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('Default Currency'),
                subtitle: Text(user.defaultCurrency),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showCurrencyPicker(
                    context: context,
                    showFlag: true,
                    showCurrencyName: true,
                    showCurrencyCode: true,
                    onSelect: (Currency currency) {
                      ref
                          .read(authControllerProvider.notifier)
                          .updateProfile(currency: currency.code);
                    },
                    theme: CurrencyPickerThemeData(
                      backgroundColor: Theme.of(context).cardColor,
                      titleTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      subtitleTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 48),
              FilledButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.8),
                ),
                child: const Text('Log Out'),
              ),
            ],
          );
        },
        error: (e, st) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _showAvatarOptions(
    BuildContext context,
    WidgetRef ref,
    String? currentUrl,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Upload Image'),
              onTap: () async {
                Navigator.pop(context);
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  ref.read(authControllerProvider.notifier).uploadAvatar(image);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Enter URL'),
              onTap: () {
                Navigator.pop(context);
                _showAvatarUrlDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarUrlDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    // We use a StatefulBuilder to handle the loading/error state inside the dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isLoading = false;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Enter Avatar URL"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: "Image URL",
                      hintText: "",
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
                    autofocus: true,
                    enabled: !isLoading,
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final url = controller.text.trim();
                          if (url.isEmpty) {
                            setState(() => errorText = "URL cannot be empty");
                            return;
                          }

                          final uri = Uri.tryParse(url);
                          if (uri == null || !uri.hasAbsolutePath) {
                            setState(() => errorText = "Invalid URL format");
                            return;
                          }

                          setState(() {
                            isLoading = true;
                            errorText = null;
                          });

                          try {
                            final response = await http.head(uri);
                            if (response.statusCode == 200) {
                              final contentType =
                                  response.headers['content-type'];
                              if (contentType != null &&
                                  contentType.startsWith('image/')) {
                                // Valid image
                                ref
                                    .read(authControllerProvider.notifier)
                                    .updateProfile(avatarUrl: url);
                                if (context.mounted) Navigator.pop(context);
                              } else {
                                setState(() {
                                  errorText = "URL does not point to an image";
                                  isLoading = false;
                                });
                              }
                            } else {
                              setState(() {
                                errorText =
                                    "Could not fetch resource (Status: ${response.statusCode})";
                                isLoading = false;
                              });
                            }
                          } catch (e) {
                            setState(() {
                              errorText = "Connection error: $e";
                              isLoading = false;
                            });
                          }
                        },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold, // Fixed: Added FontWeight.bold
          color: Colors.grey,
        ),
      ),
    );
  }

  void _editField(
    BuildContext context,
    WidgetRef ref,
    String label,
    String? currentValue,
    Function(String) onSave,
  ) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit $label"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
