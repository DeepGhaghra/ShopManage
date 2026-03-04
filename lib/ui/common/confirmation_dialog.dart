import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final Color? confirmColor;
  final IconData? icon;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.confirmColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: icon != null ? Icon(icon, size: 32, color: confirmColor ?? AppColors.primary) : null,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: Text(
        message,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor ?? AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }

  /// Specialized dialog for Sign Out
  static Future<bool?> showSignOut(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const ConfirmationDialog(
        title: 'Sign Out',
        message: 'Are you sure you want to sign out? You will need to login again to access your data.',
        confirmLabel: 'Sign Out',
        cancelLabel: 'Stay Logged In',
        confirmColor: Colors.red,
        icon: Icons.logout_rounded,
      ),
    );
  }

  /// Specialized dialog for Deletion
  static Future<bool?> showDelete(BuildContext context, {required String itemName}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Delete $itemName',
        message: 'This action cannot be undone. All associated data will be permanently removed.',
        confirmLabel: 'Delete',
        confirmColor: Colors.red.shade700,
        icon: Icons.delete_forever_rounded,
      ),
    );
  }
}
