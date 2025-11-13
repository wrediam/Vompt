import 'package:flutter/foundation.dart';
import '../../../services/web_server_service.dart';

class ServerProvider with ChangeNotifier {
  final WebServerService _webServerService = WebServerService();
  
  bool _isRunning = false;
  String? _serverUrl;
  String? _error;

  bool get isRunning => _isRunning;
  String? get serverUrl => _serverUrl;
  String? get error => _error;

  // Start server
  Future<bool> startServer() async {
    _error = null;
    notifyListeners();

    try {
      final url = await _webServerService.startServer();
      if (url != null) {
        _isRunning = true;
        _serverUrl = url;
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to start server';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error starting server: $e';
      notifyListeners();
      return false;
    }
  }

  // Stop server
  Future<void> stopServer() async {
    try {
      await _webServerService.stopServer();
      _isRunning = false;
      _serverUrl = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error stopping server: $e';
      notifyListeners();
    }
  }

  // Toggle server
  Future<void> toggleServer() async {
    if (_isRunning) {
      await stopServer();
    } else {
      await startServer();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}
