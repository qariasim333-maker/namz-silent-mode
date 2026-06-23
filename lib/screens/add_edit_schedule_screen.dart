import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule.dart';
import '../providers/app_providers.dart';

class AddEditScheduleScreen extends ConsumerStatefulWidget {
  final Schedule? existing;
  const AddEditScheduleScreen({super.key, this.existing});

  @override
  ConsumerState<AddEditScheduleScreen> createState() => _AddEditScheduleScreenState();
}

class _AddEditScheduleScreenState extends ConsumerState<AddEditScheduleScreen> {
  late TextEditingController _nameController;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late Set<int> _activeDays;
  late SilenceMode _mode;
  late RestoreBehavior _restoreBehavior;
  late bool _enabled;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _start = e != null
        ? TimeOfDay(hour: e.startMinutes ~/ 60, minute: e.startMinutes % 60)
        : const TimeOfDay(hour: 13, minute: 15);
    _end = e != null
        ? TimeOfDay(hour: e.endMinutes ~/ 60, minute: e.endMinutes % 60)
        : const TimeOfDay(hour: 13, minute: 45);
    _activeDays = e != null ? e.activeDays.toSet() : {1, 2, 3, 4, 5, 6, 7};
    _mode = e?.mode ?? SilenceMode.vibrate;
    _restoreBehavior = e?.restoreBehavior ?? RestoreBehavior.previousMode;
    _enabled = e?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a schedule name')),
      );
      return;
    }
    if (_activeDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one active day')),
      );
      return;
    }

    final startMinutes = _start.hour * 60 + _start.minute;
    var endMinutes = _end.hour * 60 + _end.minute;
    if (endMinutes <= startMinutes) {
      // Allow overnight schedules by wrapping to next day conceptually;
      // for simplicity we just push end past midnight in the same day.
      endMinutes += 24 * 60;
    }

    final controller = ref.read(scheduleControllerProvider.notifier);

    if (isEditing) {
      final updated = widget.existing!.copyWith(
        name: _nameController.text.trim(),
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        activeDays: _activeDays.toList(),
        mode: _mode,
        restoreBehavior: _restoreBehavior,
        enabled: _enabled,
      );
      controller.update(updated);
    } else {
      controller.add(
        name: _nameController.text.trim(),
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        activeDays: _activeDays.toList(),
        mode: _mode,
        restoreBehavior: _restoreBehavior,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Schedule' : 'New Schedule')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Schedule name',
              hintText: 'e.g. Fajr',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _TimeTile(
                  label: 'Start time',
                  time: _start,
                  onTap: () => _pickTime(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeTile(
                  label: 'End time',
                  time: _end,
                  onTap: () => _pickTime(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Active days', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(7, (i) {
              final day = i + 1;
              return FilterChip(
                label: Text(_dayLabels[i]),
                selected: _activeDays.contains(day),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _activeDays.add(day);
                    } else {
                      _activeDays.remove(day);
                    }
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 20),
          Text('Silence mode', style: Theme.of(context).textTheme.titleSmall),
          SegmentedButton<SilenceMode>(
            segments: const [
              ButtonSegment(value: SilenceMode.vibrate, label: Text('Vibrate'), icon: Icon(Icons.vibration)),
              ButtonSegment(value: SilenceMode.silent, label: Text('Silent'), icon: Icon(Icons.notifications_off)),
              ButtonSegment(value: SilenceMode.dnd, label: Text('DND'), icon: Icon(Icons.do_not_disturb)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 20),
          Text('Restore behavior', style: Theme.of(context).textTheme.titleSmall),
          RadioListTile<RestoreBehavior>(
            title: const Text('Restore previous mode'),
            value: RestoreBehavior.previousMode,
            groupValue: _restoreBehavior,
            onChanged: (v) => setState(() => _restoreBehavior = v!),
          ),
          RadioListTile<RestoreBehavior>(
            title: const Text('Always restore Normal mode'),
            value: RestoreBehavior.alwaysNormal,
            groupValue: _restoreBehavior,
            onChanged: (v) => setState(() => _restoreBehavior = v!),
          ),
          SwitchListTile(
            title: const Text('Enabled'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: Text(isEditing ? 'Save Changes' : 'Create Schedule'),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeTile({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(time.format(context)),
      ),
    );
  }
}
