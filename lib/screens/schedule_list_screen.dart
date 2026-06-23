import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule.dart';
import '../providers/app_providers.dart';
import 'add_edit_schedule_screen.dart';

class ScheduleListScreen extends ConsumerWidget {
  const ScheduleListScreen({super.key});

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(schedulesProvider);
    final controller = ref.read(scheduleControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Schedules')),
      body: schedulesAsync.when(
        data: (schedules) {
          if (schedules.isEmpty) {
            return const Center(child: Text('No schedules yet. Tap + to add one.'));
          }
          return ListView.builder(
            itemCount: schedules.length,
            itemBuilder: (context, index) {
              final s = schedules[index];
              return Dismissible(
                key: ValueKey(s.id),
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 24),
                  child: const Icon(Icons.delete),
                ),
                direction: DismissDirection.startToEnd,
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete schedule?'),
                          content: Text('Delete "${s.name}"? This cannot be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                          ],
                        ),
                      ) ??
                      false;
                },
                onDismissed: (_) => controller.delete(s.id),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(s.name),
                    subtitle: Text(
                      '${s.startLabel} – ${s.endLabel}  •  ${_activeDaysLabel(s.activeDays)}  •  ${s.mode.name}',
                    ),
                    leading: Switch(
                      value: s.enabled,
                      onChanged: (_) => controller.toggleEnabled(s.id),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddEditScheduleScreen(existing: s)),
                          );
                        } else if (value == 'duplicate') {
                          controller.duplicate(s);
                        } else if (value == 'delete') {
                          controller.delete(s.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddEditScheduleScreen(existing: s)),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditScheduleScreen()),
        ),
      ),
    );
  }

  String _activeDaysLabel(List<int> days) {
    if (days.length == 7) return 'Every day';
    if (days.isEmpty) return 'No days set';
    final sorted = List<int>.from(days)..sort();
    return sorted.map((d) => _dayLabels[d - 1]).join(', ');
  }
}
