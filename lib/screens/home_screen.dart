import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/ringer_service.dart';
import '../utils/next_schedule.dart';
import 'permissions_screen.dart';
import 'schedule_list_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Forces a rebuild every second so the countdown stays live.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(schedulesProvider);
    final ringerAsync = ref.watch(currentRingerModeProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Namaz Silent Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(schedulesProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _AutomationCard(settings: settings),
            const SizedBox(height: 16),
            ringerAsync.when(
              data: (mode) => _CurrentModeCard(mode: mode),
              loading: () => const _CurrentModeCard(mode: null),
              error: (_, __) => const _CurrentModeCard(mode: null),
            ),
            const SizedBox(height: 16),
            schedulesAsync.when(
              data: (schedules) {
                final next = computeNextSchedule(schedules);
                return _NextScheduleCard(info: next);
              },
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading schedules: $e'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.security_outlined),
                title: const Text('Permissions'),
                subtitle: const Text('Notification access, exact alarms'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PermissionsScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.list_alt),
        label: const Text('Manage Schedules'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScheduleListScreen()),
        ),
      ),
    );
  }
}

class _AutomationCard extends ConsumerWidget {
  final dynamic settings;
  const _AutomationCard({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: SwitchListTile(
        title: const Text('Automation'),
        subtitle: Text(settings.automationEnabled
            ? 'Schedules will silence your phone automatically'
            : 'Automation paused — no schedules will fire'),
        value: settings.automationEnabled,
        onChanged: (value) {
          ref.read(settingsProvider.notifier).update((s) {
            s.automationEnabled = value;
            return s;
          });
        },
      ),
    );
  }
}

class _CurrentModeCard extends StatelessWidget {
  final RingerMode? mode;
  const _CurrentModeCard({required this.mode});

  @override
  Widget build(BuildContext context) {
    final label = switch (mode) {
      RingerMode.silent => 'Silent',
      RingerMode.vibrate => 'Vibrate',
      RingerMode.normal => 'Normal',
      null => 'Unknown',
    };
    final icon = switch (mode) {
      RingerMode.silent => Icons.notifications_off,
      RingerMode.vibrate => Icons.vibration,
      RingerMode.normal => Icons.notifications_active,
      null => Icons.help_outline,
    };
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: const Text('Current Phone Mode'),
        subtitle: Text(label, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _NextScheduleCard extends StatelessWidget {
  final NextScheduleInfo? info;
  const _NextScheduleCard({required this.info});

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    if (info == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No upcoming schedules. Add one to get started.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info!.isCurrentlyActive ? 'Currently Active' : 'Next Schedule',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(info!.schedule.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              info!.isCurrentlyActive
                  ? 'Restores in ${_fmtDuration(info!.remaining)}'
                  : 'Starts in ${_fmtDuration(info!.remaining)}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
