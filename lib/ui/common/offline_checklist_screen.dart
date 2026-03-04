import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class OfflineChecklistScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const OfflineChecklistScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: Color(0xFFD32F2F),
              ),
              const SizedBox(height: 24),
              Text(
                'Connection Lost',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'It seems you are not connected to the internet. Please check the following items:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView(
                  children: [
                    _ChecklistItem(
                      icon: Icons.wifi_rounded,
                      title: 'Verify WiFi',
                      description: 'Ensure WiFi is turned on and you are connected to a network.',
                    ),
                    _ChecklistItem(
                      icon: Icons.signal_cellular_alt_rounded,
                      title: 'Mobile Data',
                      description: 'Check if mobile data is enabled if you are not using WiFi.',
                    ),
                    _ChecklistItem(
                      icon: Icons.airplanemode_inactive_rounded,
                      title: 'Airplane Mode',
                      description: 'Make sure Airplane Mode is turned off.',
                    ),
                    _ChecklistItem(
                      icon: Icons.router_rounded,
                      title: 'Router / Modem',
                      description: 'Check if your internet router is working and has internet access.',
                    ),
                    _ChecklistItem(
                      icon: Icons.dns_rounded,
                      title: 'DNS / Firewall',
                      description: 'Ensure your network allows access to required services.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('RETRY CONNECTION'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ChecklistItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
