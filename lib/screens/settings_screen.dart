import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/schedule.dart';
import '../providers/app_providers.dart';
import '../services/prayer_time_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Prayer Time Mode'),
          SwitchListTile(
            title: const Text('Auto-calculate prayer times'),
            subtitle: const Text('Uses your location instead of manual schedules'),
            value: settings.prayerTimeModeEnabled,
            onChanged: (v) async {
              await notifier.update((s) {
                s.prayerTimeModeEnabled = v;
                return s;
              });
              if (v) {
                try {
                  final pos = await PrayerTimeService.getCurrentLocation();
                  await notifier.update((s) {
                    s.lastLatitude = pos.latitude;
                    s.lastLongitude = pos.longitude;
                    return s;
                  });
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Location permission required for this feature')),
                    );
                  }
                }
              }
            },
          ),
          ListTile(
            title: const Text('Calculation method'),
            subtitle: Text(_methodLabel(settings.calculationMethod)),
            trailing: const Icon(Icons.chevron_right),
            enabled: settings.prayerTimeModeEnabled,
            onTap: () => _showMethodPicker(context, ref, settings),
          ),
          ListTile(
            title: const Text('Prayer duration'),
            subtitle: Text('${settings.prayerDurationMinutes} minutes'),
            trailing: const Icon(Icons.chevron_right),
            enabled: settings.prayerTimeModeEnabled,
            onTap: () => _showDurationPicker(context, ref, settings),
          ),
          const Divider(),
          const _SectionHeader('Default Silence Behavior'),
          ListTile(
            title: const Text('Default mode'),
            subtitle: Text(settings.defaultMode.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showModePicker(context, ref, settings),
          ),
          ListTile(
            title: const Text('Restore behavior'),
            subtitle: Text(settings.restoreBehavior == RestoreBehavior.previousMode
                ? 'Restore previous mode'
                : 'Always restore Normal mode'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRestorePicker(context, ref, settings),
          ),
          const Divider(),
          const _SectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Notify when silent mode activates'),
            value: settings.notifyOnActivate,
            onChanged: (v) => notifier.update((s) {
              s.notifyOnActivate = v;
              return s;
            }),
          ),
          SwitchListTile(
            title: const Text('Notify when silent mode restores'),
            value: settings.notifyOnRestore,
            onChanged: (v) => notifier.update((s) {
              s.notifyOnRestore = v;
              return s;
            }),
          ),
        ],
      ),
    );
  }

  String _methodLabel(CalculationMethodOption m) {
    switch (m) {
      case CalculationMethodOption.muslimWorldLeague:
        return 'Muslim World League';
      case CalculationMethodOption.egyptian:
        return 'Egyptian General Authority';
      case CalculationMethodOption.karachi:
        return 'University of Islamic Sciences, Karachi';
      case CalculationMethodOption.ummAlQura:
        return 'Umm al-Qura, Makkah';
      case CalculationMethodOption.dubai:
        return 'Dubai';
      case CalculationMethodOption.moonsightingCommittee:
        return 'Moonsighting Committee';
      case CalculationMethodOption.northAmerica:
        return 'ISNA (North America)';
      case CalculationMethodOption.kuwait:
        return 'Kuwait';
      case CalculationMethodOption.qatar:
        return 'Qatar';
      case CalculationMethodOption.singapore:
        return 'Singapore';
    }
  }

  void _showMethodPicker(BuildContext context, WidgetRef ref, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        children: CalculationMethodOption.values.map((m) {
          return RadioListTile<CalculationMethodOption>(
            title: Text(_methodLabel(m)),
            value: m,
            groupValue: settings.calculationMethod,
            onChanged: (v) {
              ref.read(settingsProvider.notifier).update((s) {
                s.calculationMethod = v!;
                return s;
              });
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showDurationPicker(BuildContext context, WidgetRef ref, AppSettings settings) {
    final options = [15, 20, 30];
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...options.map((m) => RadioListTile<int>(
                title: Text('$m minutes'),
                value: m,
                groupValue: settings.prayerDurationMinutes,
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).update((s) {
                    s.prayerDurationMinutes = v!;
                    return s;
                  });
                  Navigator.pop(context);
                },
              )),
          ListTile(
            title: const Text('Custom...'),
            onTap: () async {
              Navigator.pop(context);
              final value = await showDialog<int>(
                context: context,
                builder: (ctx) {
                  final controller = TextEditingController();
                  return AlertDialog(
                    title: const Text('Custom duration (minutes)'),
                    content: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
                        child: const Text('OK'),
                      ),
                    ],
                  );
                },
              );
              if (value != null && value > 0) {
                ref.read(settingsProvider.notifier).update((s) {
                  s.prayerDurationMinutes = value;
                  return s;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  void _showModePicker(BuildContext context, WidgetRef ref, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: SilenceMode.values.map((m) {
          return RadioListTile<SilenceMode>(
            title: Text(m.name),
            value: m,
            groupValue: settings.defaultMode,
            onChanged: (v) {
              ref.read(settingsProvider.notifier).update((s) {
                s.defaultMode = v!;
                return s;
              });
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showRestorePicker(BuildContext context, WidgetRef ref, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<RestoreBehavior>(
            title: const Text('Restore previous mode'),
            value: RestoreBehavior.previousMode,
            groupValue: settings.restoreBehavior,
            onChanged: (v) {
              ref.read(settingsProvider.notifier).update((s) {
                s.restoreBehavior = v!;
                return s;
              });
              Navigator.pop(context);
            },
          ),
          RadioListTile<RestoreBehavior>(
            title: const Text('Always restore Normal mode'),
            value: RestoreBehavior.alwaysNormal,
            groupValue: settings.restoreBehavior,
            onChanged: (v) {
              ref.read(settingsProvider.notifier).update((s) {
                s.restoreBehavior = v!;
                return s;
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
