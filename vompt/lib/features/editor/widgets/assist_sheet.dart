import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../services/script_assistant.dart';

/// What the editor should do with an assistant result.
class AssistResult {
  final ScriptTask task;
  final String text;
  const AssistResult(this.task, this.text);
}

/// Script tools that run on Apple's on-device model. Returns the accepted
/// result, or null if the person backs out.
/// [preview] opens straight on a finished result (used for screenshots).
Future<AssistResult?> showAssistSheet(
  BuildContext context, {
  required String script,
  AssistResult? preview,
}) {
  return showModalBottomSheet<AssistResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AssistSheet(script: script, preview: preview),
  );
}

class _AssistSheet extends StatefulWidget {
  final String script;
  final AssistResult? preview;
  const _AssistSheet({required this.script, this.preview});

  @override
  State<_AssistSheet> createState() => _AssistSheetState();
}

enum _Stage { pick, length, running, review }

class _AssistSheetState extends State<_AssistSheet> {
  final _assistant = ScriptAssistant.instance;
  ({bool available, String? reason})? _status;
  _Stage _stage = _Stage.pick;
  ScriptTask? _task;
  int _seconds = 60;
  String? _result;
  String? _error;

  static const _lengths = [30, 60, 90, 120, 180, 300];

  @override
  void initState() {
    super.initState();
    final preview = widget.preview;
    if (preview != null) {
      _status = (available: true, reason: null);
      _task = preview.task;
      _result = preview.text;
      _stage = _Stage.review;
      return;
    }
    _assistant.availability(refresh: true).then((s) {
      if (mounted) setState(() => _status = s);
    });
  }

  bool get _empty => widget.script.trim().isEmpty;

  void _choose(ScriptTask task) {
    setState(() {
      _task = task;
      _error = null;
    });
    if (task == ScriptTask.fitTime || task == ScriptTask.draft) {
      setState(() => _stage = _Stage.length);
    } else {
      _run();
    }
  }

  Future<void> _run() async {
    setState(() => _stage = _Stage.running);
    try {
      final out = await _assistant.run(
        _task!,
        widget.script,
        seconds: _seconds,
      );
      if (!mounted) return;
      setState(() {
        _result = out;
        _stage = _Stage.review;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _stage = _Stage.pick;
      });
    }
  }

  String _lengthLabel(int s) => s < 60
      ? '$s s'
      : s % 60 == 0
      ? '${s ~/ 60} min'
      : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = _status;

    Widget body;
    if (status == null) {
      body = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (!status.available) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Script tools are off', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              status.reason ?? 'Apple Intelligence is not available.',
              style: text.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'These tools run on Apple Intelligence on this iPhone. Nothing is sent to a server.',
              style: text.bodySmall,
            ),
          ],
        ),
      );
    } else {
      body = switch (_stage) {
        _Stage.pick => _pickList(text),
        _Stage.length => _lengthPicker(text),
        _Stage.running => Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text('${_task!.label}…', style: text.titleMedium),
              ),
            ],
          ),
        ),
        _Stage.review => _review(text),
      };
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(child: body),
    );
  }

  Widget _pickList(TextTheme text) {
    final tasks = _empty ? const <ScriptTask>[] : ScriptTask.values;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('Assist', style: text.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Runs on this iPhone with Apple Intelligence.',
              style: text.bodySmall,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.tally,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_empty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Type a few notes or bullet points into the script first, then use "Draft from notes" to turn them into a script.',
                style: text.bodyLarge,
              ),
            ),
          for (final t in tasks)
            ListTile(
              title: Text(t.label, style: text.titleSmall),
              subtitle: Text(t.description, style: text.bodySmall),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
              onTap: () => _choose(t),
            ),
        ],
      ),
    );
  }

  Widget _lengthPicker(TextTheme text) {
    final words = (_seconds * ScriptAssistant.defaultPace / 60).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _task == ScriptTask.draft
                ? 'How long should it run?'
                : 'Fit to how long?',
            style: text.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'About $words words at ${ScriptAssistant.defaultPace} words a minute.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _lengths)
                ChoiceChip(
                  label: Text(_lengthLabel(s)),
                  selected: _seconds == s,
                  onSelected: (_) => setState(() => _seconds = s),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _stage = _Stage.pick),
                child: const Text('Back'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _run,
                child: Text(
                  _task == ScriptTask.draft ? 'Write draft' : 'Rewrite',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _review(TextTheme text) {
    final task = _task!;
    final result = _result ?? '';
    final words = result.trim().isEmpty
        ? 0
        : result.trim().split(RegExp(r'\s+')).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.label, style: text.titleLarge),
          const SizedBox(height: 4),
          Text(
            task.rewrites
                ? '$words words. Read it over before you use it.'
                : 'Tap one to put it at the top of your script.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 16),
          if (task.rewrites)
            Container(
              constraints: const BoxConstraints(maxHeight: 360),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SingleChildScrollView(
                child: SelectableText(result, style: text.bodyLarge),
              ),
            )
          else
            for (final line
                in result.split('\n').where((l) => l.trim().isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () =>
                        Navigator.pop(context, AssistResult(task, line.trim())),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(line.trim(), style: text.bodyLarge),
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(onPressed: _run, child: const Text('Try again')),
              const Spacer(),
              if (task.rewrites)
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, AssistResult(task, result)),
                  child: const Text('Use this'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
