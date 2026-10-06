import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/health/health_service.dart';


class HealthSettingsSection extends ConsumerStatefulWidget {
  const HealthSettingsSection({super.key});

  @override
  ConsumerState<HealthSettingsSection> createState() => _HealthSettingsSectionState();
}

class _HealthSettingsSectionState extends ConsumerState<HealthSettingsSection> {

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          leading: Icon(Icons.health_and_safety_outlined),
          title: Text('Android Health Connect'),
          subtitle: Text('Sync workouts and steps automatically'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: OutlinedButton.icon(
            onPressed: () async {
              final healthService = ref.read(healthServiceProvider);
              final granted = await healthService.requestPermissions();
              if (mounted) {
                if (granted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Health Connect linked successfully!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not link Health Connect. Ensure app is installed.')),
                  );
                  // Optionally open settings
                  await healthService.openHealthConnectSettings();
                }
              }
            },
            icon: const Icon(Icons.link),
            label: const Text('Manage Permissions'),
          ),
        ),
      ],
    );
  }
}
