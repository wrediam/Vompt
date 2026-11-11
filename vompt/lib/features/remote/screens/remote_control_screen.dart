import 'dart:async';
import '../../../shared/widgets/readable_width.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/colors.dart';
import '../../../services/remote_control_service.dart';
import '../providers/server_provider.dart';

/// Starts the web remote and shows how to open Vompt Studio in a browser.
/// Navigation the browser asks for is handled app-wide by RemoteCoordinator,
/// so this screen only reports status.
class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key});

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  StreamSubscription<bool>? _connection;
  bool _connected = RemoteControlService().hasActiveClient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServerProvider>().startServer();
    });
    _connection = RemoteControlService().onClientConnectionChange.listen((
      connected,
    ) {
      if (mounted) setState(() => _connected = connected);
    });
  }

  @override
  void dispose() {
    _connection?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerProvider>();
    final text = Theme.of(context).textTheme;
    final url = server.serverUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Web remote')),
      body: SafeArea(
        child: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Text(
                'Open Vompt Studio on your computer',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Edit scripts, use Assist, and run the prompter from a laptop or tablet. '
                'It needs to be on the same Wi-Fi as this iPhone.',
                style: text.bodyLarge?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 28),
              if (server.error != null) ...[
                Text(
                  server.error!,
                  style: text.titleMedium?.copyWith(color: AppColors.tally),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: server.startServer,
                    child: const Text('Try again'),
                  ),
                ),
              ] else if (url == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: QrImageView(
                      data: url,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Scan with the computer\'s camera, or type the link',
                    style: text.bodySmall,
                  ),
                ),
                const SizedBox(height: 20),
                Material(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(url, style: text.titleSmall),
                          ),
                          const Icon(
                            Icons.copy_rounded,
                            size: 20,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _connected ? AppColors.tally : AppColors.muted,
                        shape: BoxShape.circle,
                        boxShadow: _connected
                            ? [
                                BoxShadow(
                                  color: AppColors.tally.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _connected
                            ? 'Vompt Studio is connected. Choose a script there and select Send to prompter. You can keep using the app meanwhile.'
                            : 'Waiting for a browser to connect',
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () async {
                      await server.stopServer();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Turn off web remote'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
