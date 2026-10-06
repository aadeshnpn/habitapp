import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../domain/mindfulness_bell_config.dart';
import '../domain/mindfulness_bell_providers.dart';

class MindfulnessBellScreen extends ConsumerStatefulWidget {
  const MindfulnessBellScreen({super.key});

  @override
  ConsumerState<MindfulnessBellScreen> createState() =>
      _MindfulnessBellScreenState();
}

class _MindfulnessBellScreenState extends ConsumerState<MindfulnessBellScreen> {
  MindfulnessBellConfig? _draft;
  bool _saving = false;
  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(mindfulnessBellConfigProvider);

    // Seed local draft once from storage; keep user edits after that.
    ref.listen<AsyncValue<MindfulnessBellConfig>>(
      mindfulnessBellConfigProvider,
      (prev, next) {
        next.whenData((config) {
          if (!_seeded) {
            setState(() {
              _draft = config;
              _seeded = true;
            });
          }
        });
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mindfulness Bell'),
      ),
      body: configAsync.when(
        loading: () => _draft == null
            ? const Center(child: CircularProgressIndicator())
            : _buildForm(_draft!),
        error: (e, _) => Center(child: Text('Could not load settings: $e')),
        data: (loaded) {
          _draft ??= loaded;
          _seeded = true;
          return _buildForm(_draft!);
        },
      ),
    );
  }

  Widget _buildForm(MindfulnessBellConfig draft) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable mindfulness bell'),
          subtitle: const Text(
            'Plays a short sound and vibration during your window. '
            'No tap or logging required.',
          ),
          value: draft.enabled,
          onChanged: _saving ? null : (v) => _onEnableChanged(draft, v),
        ),
        const SizedBox(height: 8),
        Text(
          'Active window',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TimeTile(
                label: 'Start',
                time: TimeOfDay(
                  hour: draft.startHour,
                  minute: draft.startMinute,
                ),
                onPick: (t) => _update(
                  draft.copyWith(
                    startHour: t.hour,
                    startMinute: t.minute,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimeTile(
                label: 'End',
                time: TimeOfDay(
                  hour: draft.endHour,
                  minute: draft.endMinute,
                ),
                onPick: (t) => _update(
                  draft.copyWith(
                    endHour: t.hour,
                    endMinute: t.minute,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Frequency',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Rings about every ${draft.intervalMinutes} minutes, with '
          '±${MindfulnessBellConfig.jitterMinutes} minute random variation '
          'so it does not always land on the exact interval.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final minutes in MindfulnessBellConfig.intervalChoices)
              ChoiceChip(
                label: Text(_intervalLabel(minutes)),
                selected: draft.intervalMinutes == minutes,
                onSelected: (_) =>
                    _update(draft.copyWith(intervalMinutes: minutes)),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Bell sound',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        for (final sound in MindfulnessBellConfig.soundChoices)
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: Text(MindfulnessBellConfig.soundDisplayName(sound)),
            value: sound,
            groupValue: draft.soundId,
            onChanged: (v) {
              if (v != null) _update(draft.copyWith(soundId: v));
            },
            secondary: IconButton(
              tooltip: 'Preview',
              icon: const Icon(Icons.play_arrow),
              onPressed: () =>
                  NotificationService.instance.previewMindfulnessBell(sound),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  void _update(MindfulnessBellConfig next) {
    setState(() => _draft = next);
  }

  /// Toggle persists immediately so Off always disables without relying on Save.
  Future<void> _onEnableChanged(MindfulnessBellConfig draft, bool enabled) async {
    final next = draft.copyWith(enabled: enabled);
    _update(next);
    if (!enabled) {
      setState(() => _saving = true);
      try {
        await saveMindfulnessBellConfig(ref, next);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mindfulness bell disabled')),
        );
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Future<void> _save() async {
    final current = _draft;
    if (current == null) return;

    final start = current.startHour * 60 + current.startMinute;
    final end = current.endHour * 60 + current.endMinute;
    if (end <= start) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    // Save applies the schedule and turns the bell on.
    final toSave = current.copyWith(enabled: true);

    setState(() {
      _draft = toSave;
      _saving = true;
    });
    try {
      await saveMindfulnessBellConfig(ref, toSave);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mindfulness bell scheduled')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _intervalLabel(int minutes) {
    if (minutes < 60) return 'Every $minutes min';
    if (minutes == 60) return 'Every hour';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    if (rem == 0) return 'Every $hours hr';
    return 'Every ${hours}h ${rem}m';
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onPick;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onPick(picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
