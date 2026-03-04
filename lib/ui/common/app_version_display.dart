import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionDisplay extends StatelessWidget {
  const AppVersionDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final packageInfo = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Version ${packageInfo.version} (${packageInfo.buildNumber})',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }
}
