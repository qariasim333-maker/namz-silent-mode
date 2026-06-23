import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/ringer_service.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _dndAccess = false;
  bool _exactAlarm = false;
  bool _notificationPermission = false;
  bool _locationPermission = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final dnd = await RingerService.hasNotificationPolicyAccess();
    final alarm = await RingerService.canScheduleExactAlarms();
    final notif = await Permission.notification.isGranted;
    final loc = await Permission.location.isGranted;
    setState(() {
      _dndAccess = dnd;
      _exactAlarm = alarm;
      _notificationPermission = notif;
      _locationPermission = loc;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Namaz Silent Mode needs the following permissions to reliably '
            'silence your phone during prayer times, even when the app is '
            'closed or the device restarts.',
          ),
          const SizedBox(height: 20),
          _PermissionCard(
            icon: Icons.do_not_disturb_on_outlined,
            title: 'Notification Policy Access',
            description: 'Required to switch to Silent mode and control Do Not Disturb.',
            granted: _dndAccess,
            onRequest: () async {
              await RingerService.openNotificationPolicySettings();
              await Future.delayed(const Duration(seconds: 1));
              _refresh();
            },
          ),
          _PermissionCard(
            icon: Icons.alarm_on_outlined,
            title: 'Exact Alarm Permission',
            description: 'Ensures schedules fire precisely at prayer start/end times.',
            granted: _exactAlarm,
            onRequest: () async {
              await RingerService.openExactAlarmSettings();
              await Future.delayed(const Duration(seconds: 1));
              _refresh();
            },
          ),
          _PermissionCard(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            description: 'Lets the app notify you when silent mode is activated or restored.',
            granted: _notificationPermission,
            onRequest: () async {
              await Permission.notification.request();
              _refresh();
            },
          ),
          _PermissionCard(
            icon: Icons.location_on_outlined,
            title: 'Location (optional)',
            description: 'Needed only for automatic Prayer Time Mode calculation.',
            granted: _locationPermission,
            onRequest: () async {
              await Permission.location.request();
              _refresh();
            },
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onRequest;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
        trailing: granted
            ? const Icon(Icons.check_circle, color: Colors.green)
            : FilledButton(onPressed: onRequest, child: const Text('Grant')),
      ),
    );
  }
}
