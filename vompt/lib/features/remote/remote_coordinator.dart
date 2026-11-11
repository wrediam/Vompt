import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/remote_control_service.dart';
import '../documents/providers/documents_provider.dart';
import '../teleprompter/providers/intelligent_teleprompter_provider.dart';
import '../teleprompter/screens/intelligent_teleprompter_screen.dart';

/// Carries out navigation the web remote asks for, from anywhere in the app.
///
/// One owner, one navigator key: opening a script pushes the prompter (or
/// swaps the script in place if a prompter is already showing), and closing
/// pops exactly back to the prompter's route, so a sheet left open on the
/// phone can never make it close the wrong screen. A browser disconnecting
/// never navigates; it only changes the status shown to the user.
class RemoteCoordinator {
  RemoteCoordinator._();
  static final RemoteCoordinator instance = RemoteCoordinator._();

  final navigatorKey = GlobalKey<NavigatorState>();
  final _remote = RemoteControlService();
  final List<StreamSubscription<dynamic>> _subs = [];
  Route<dynamic>? _prompterRoute;

  /// Serializes requests so rapid clicks in the browser apply in order.
  Future<void> _queue = Future.value();

  bool get prompterOpen => _prompterRoute?.isActive ?? false;

  void start() {
    if (_subs.isNotEmpty) return;
    _subs
      ..add(
        _remote.onDocumentSelected.listen((id) => _enqueue(() => _open(id))),
      )
      ..add(_remote.onControlExit.listen((_) => _enqueue(_close)));
  }

  /// Called by the prompter screen so the coordinator knows about prompters
  /// opened from the phone too.
  void prompterShown(Route<dynamic> route) {
    _prompterRoute = route;
    _remote.prompterOpen = true;
  }

  void prompterHidden(Route<dynamic> route) {
    if (_prompterRoute == route) {
      _prompterRoute = null;
      _remote.prompterOpen = false;
    }
  }

  void _enqueue(Future<void> Function() action) {
    _queue = _queue.then((_) => action()).catchError((Object e) {
      debugPrint('Remote navigation failed: $e');
    });
  }

  Future<void> _open(String documentId) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final docs = context.read<DocumentsProvider>();
    final prompter = context.read<IntelligentTeleprompterProvider>();
    // Read from storage: the script may have just been written in the browser.
    final doc = await docs.reloadDocument(documentId);
    if (doc == null) return;

    if (prompterOpen) {
      if (prompter.document?.id == doc.id &&
          prompter.scriptContent == doc.content) {
        return;
      }
      if (prompter.hasTake) await prompter.finishTake();
      prompter.loadScript(doc);
      _popTo(_prompterRoute!);
      return;
    }
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => IntelligentTeleprompterScreen(document: doc),
      ),
    );
  }

  Future<void> _close() async {
    final route = _prompterRoute;
    if (route == null || !route.isActive) return;
    _popTo(route);
    navigatorKey.currentState?.pop();
  }

  /// Pops anything stacked above [route] (sheets, dialogs).
  void _popTo(Route<dynamic> route) {
    navigatorKey.currentState?.popUntil((r) => r == route || !route.isActive);
  }
}
