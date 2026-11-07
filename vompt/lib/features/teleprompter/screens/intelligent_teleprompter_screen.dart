import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/colors.dart';
import '../../../data/models/document.dart';
import '../../remote/remote_coordinator.dart';
import '../providers/intelligent_teleprompter_provider.dart';
import '../widgets/intelligent_teleprompter_controls.dart';
import '../widgets/prompter_text.dart';
import '../widgets/take_summary.dart';

class IntelligentTeleprompterScreen extends StatefulWidget {
  final Document document;

  /// Ask for the mic and load the speech model as soon as the screen opens.
  final bool warmUp;

  /// Called once the script is loaded into the provider.
  final void Function(IntelligentTeleprompterProvider)? onLoaded;

  const IntelligentTeleprompterScreen({
    super.key,
    required this.document,
    this.warmUp = true,
    this.onLoaded,
  });

  @override
  State<IntelligentTeleprompterScreen> createState() =>
      _IntelligentTeleprompterScreenState();
}

class _IntelligentTeleprompterScreenState
    extends State<IntelligentTeleprompterScreen> {
  IntelligentTeleprompterProvider? _provider;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  PrompterStatus? _lastStatus;
  Route<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _route = ModalRoute.of(context);
      if (_route != null) RemoteCoordinator.instance.prompterShown(_route!);
      final provider = context.read<IntelligentTeleprompterProvider>();
      _provider = provider;
      provider.loadScript(widget.document);
      provider.addListener(_onProviderChanged);
      if (widget.warmUp) provider.prepare();
      widget.onLoaded?.call(provider);

      final size = MediaQuery.of(context).size;
      provider.updateScreenDimensions(size.longestSide, size.shortestSide);
      if (provider.remoteControlService.hasActiveClient) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _onProviderChanged() {
    final status = _provider?.status;
    if (status == _lastStatus) return;
    _lastStatus = status;
    // Get the controls out of the way once reading starts.
    if (status == PrompterStatus.listening) {
      _scheduleHide();
    } else if (status == PrompterStatus.paused ||
        status == PrompterStatus.idle) {
      _hideTimer?.cancel();
      if (mounted && !_controlsVisible) setState(() => _controlsVisible = true);
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_provider?.isSpeechActive != true) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _provider?.isSpeechActive == true) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    if (_route != null) RemoteCoordinator.instance.prompterHidden(_route!);
    final provider = _provider;
    if (provider != null) {
      provider.removeListener(_onProviderChanged);
      // Leaving mid-take still saves it.
      if (provider.hasTake) provider.finishTake();
    }
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<IntelligentTeleprompterProvider>();

    if (p.status == PrompterStatus.finished) {
      return TakeSummary(
        stats: p.stats,
        duration: p.elapsed,
        wordsPerMinute: p.lastSession?.wordsPerMinute ?? p.wordsPerMinute,
        scriptWords: p.scriptWords,
        countsVocalFillers: p.countsVocalFillers,
        onAgain: p.reset,
        onDone: () => Navigator.of(context).pop(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.prompter,
      body: Stack(
        children: [
          Positioned.fill(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(p.isMirrored ? -1 : 1, 1, 1),
              child: SafeArea(
                child: PrompterText(
                  words: p.scriptWords,
                  newlinesBefore: p.newlinesBefore,
                  currentWord: p.currentWordIndex,
                  fontSize: p.fontSize,
                  centered: p.centerText,
                  onTap: _toggleControls,
                  onJump: (i) {
                    p.jumpToWord(i);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            'Continuing from "${p.scriptWords[i]}"',
                          ),
                          duration: const Duration(milliseconds: 1400),
                        ),
                      );
                  },
                ),
              ),
            ),
          ),
          // Reading line: the cue mark the current line rides on.
          Positioned.fill(
            child: IgnorePointer(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, c) => Stack(
                    children: [
                      Positioned(
                        left: 18,
                        top: c.maxHeight * 0.32 + p.fontSize * 0.69 - 9,
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: AppColors.cue,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Words above the reading line fade out under the status readout.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: MediaQuery.of(context).size.height * 0.2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.prompter,
                      AppColors.prompter.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Progress through the script.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value: p.progress,
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  _controlsVisible ? 68 : 12,
                  20,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const TallyLight(),
                    if (p.showStats && (p.hasTake || p.isPreparing)) ...[
                      const SizedBox(height: 8),
                      const StatsReadout(),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _controlsVisible ? 1 : 0,
              child: IntelligentTeleprompterControls(
                onClose: () => Navigator.of(context).pop(),
                onInteract: _scheduleHide,
              ),
            ),
          ),
          if (p.error != null) _ErrorCard(provider: p),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final IntelligentTeleprompterProvider provider;
  const _ErrorCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
        decoration: BoxDecoration(
          color: AppColors.raised,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.error!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: provider.dismissError,
                  child: const Text('Dismiss'),
                ),
                if (provider.errorNeedsSettings) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      provider.dismissError();
                      openAppSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
