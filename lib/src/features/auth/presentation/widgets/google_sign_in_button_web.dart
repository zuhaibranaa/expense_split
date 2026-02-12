import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Wrapper to control size/centering
    return Center(
      child: SizedBox(
        height: 48, // approximate height to match mobile button
        child: web.renderButton(
          configuration: web.GSIButtonConfiguration(
            type: web.GSIButtonType.standard,
            theme: web.GSIButtonTheme.outline,
            size: web.GSIButtonSize.large,
            text: web.GSIButtonText.continueWith,
          ),
        ),
      ),
    );
  }
}
