import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../core/constants/app_constants.dart';
import '../data/repositories/document_repository.dart';
import '../data/models/document.dart';
import 'remote_control_service.dart';

class WebServerService {
  HttpServer? _server;
  final DocumentRepository _documentRepository = DocumentRepository();
  final RemoteControlService _remoteControlService = RemoteControlService();
  final int port;
  String? _localIpAddress;

  WebServerService({this.port = AppConstants.defaultServerPort});

  bool get isRunning => _server != null;
  String? get serverUrl => _localIpAddress != null ? 'http://$_localIpAddress:$port' : null;

  // Start the web server
  Future<String?> startServer() async {
    if (_server != null) {
      return serverUrl;
    }

    try {
      // Get local IP address
      final networkInfo = NetworkInfo();
      _localIpAddress = await networkInfo.getWifiIP();

      if (_localIpAddress == null) {
        throw Exception('Could not determine local IP address');
      }

      // Create router
      final router = _createRouter();

      // Create handler with middleware
      final handler = const Pipeline()
          .addMiddleware(logRequests())
          .addMiddleware(_corsMiddleware())
          .addHandler(router.call);

      // Start server
      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        port,
      );

      // Server started successfully
      return serverUrl;
    } catch (e) {
      // Failed to start server
      return null;
    }
  }

  // Stop the web server
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      // Server stopped
    }
  }

  // Create router with all endpoints
  Router _createRouter() {
    final router = Router();

    // Serve web UI
    router.get('/', _serveWebUI);

    // API endpoints
    router.get('/api/documents', _getDocuments);
    router.get('/api/documents/<id>', _getDocument);
    router.post('/api/documents', _createDocument);
    router.post('/api/documents/<id>/content', _updateDocumentContent);
    router.post('/api/control/play', _controlPlay);
    router.post('/api/control/pause', _controlPause);
    router.post('/api/control/fontsize', _controlFontSize);
    router.post('/api/control/mirror', _controlMirror);
    router.post('/api/control/reset', _controlReset);
    router.post('/api/control/select-document', _selectDocument);
    router.post('/api/control/exit', _exitControl);
    router.get('/api/control/state', _getControlState);
    router.post('/api/client/connect', _clientConnect);
    router.post('/api/client/heartbeat', _clientHeartbeat);

    // Health check
    router.get('/api/health', (Request request) {
      return Response.ok(
        jsonEncode({'status': 'ok', 'timestamp': DateTime.now().toIso8601String()}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    return router;
  }

  // CORS middleware
  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }

        final response = await handler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  Map<String, String> get _corsHeaders => {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      };

  // Serve web UI
  Response _serveWebUI(Request request) {
    final html = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Vompt Remote</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        :root {
            --bg: #09090B;
            --surface: #18181B;
            --surface-hover: #27272A;
            --border: #3F3F46;
            --text: #FAFAFA;
            --text-muted: #A1A1AA;
            --primary: #FAFAFA;
            --primary-fg: #09090B;
            --accent: #3B82F6;
            --success: #10B981;
            --danger: #EF4444;
            --warning: #F59E0B;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: var(--bg);
            color: var(--text);
            min-height: 100vh;
            line-height: 1.5;
        }
        
        .app-container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        /* Header */
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 32px;
            padding-bottom: 16px;
            border-bottom: 1px solid var(--border);
        }
        
        .logo {
            font-size: 24px;
            font-weight: 600;
            letter-spacing: -0.3px;
        }
        
        .nav-tabs {
            display: flex;
            gap: 8px;
        }
        
        .tab {
            padding: 8px 16px;
            background: transparent;
            color: var(--text-muted);
            border: 1px solid transparent;
            border-radius: 8px;
            cursor: default;
            font-size: 14px;
            font-weight: 500;
            transition: all 0.2s;
            pointer-events: none;
        }
        
        .tab.active {
            background: var(--surface);
            color: var(--text);
            border-color: var(--border);
        }
        
        /* Views */
        .view {
            display: none;
        }
        
        .view.active {
            display: block;
        }
        
        /* Card */
        .card {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 16px;
        }
        
        .card-title {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 16px;
        }
        
        /* Scripts List */
        .script-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 16px;
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 8px;
            margin-bottom: 8px;
            cursor: pointer;
            transition: all 0.2s;
        }
        
        .script-item:hover {
            background: var(--surface-hover);
            border-color: var(--text-muted);
        }
        
        .script-info h3 {
            font-size: 16px;
            font-weight: 600;
            margin-bottom: 4px;
        }
        
        .script-meta {
            font-size: 14px;
            color: var(--text-muted);
        }
        
        .script-actions {
            display: flex;
            gap: 8px;
        }
        
        /* Editor */
        .editor-container {
            display: flex;
            flex-direction: column;
            gap: 16px;
        }
        
        .editor-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .editor-title {
            font-size: 24px;
            font-weight: 600;
            color: var(--text);
            background: transparent;
            border: none;
            outline: none;
            padding: 8px 0;
            width: 100%;
        }
        
        .editor-content {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 24px;
            min-height: 400px;
            font-size: 16px;
            color: var(--text);
            resize: vertical;
            outline: none;
            font-family: inherit;
            line-height: 1.6;
            width: 100%;
            box-sizing: border-box;
        }
        
        .editor-stats {
            display: flex;
            gap: 24px;
            font-size: 14px;
            color: var(--text-muted);
        }
        
        /* Control Panel */
        .control-panel {
            display: grid;
            gap: 24px;
        }
        
        .control-group {
            display: flex;
            flex-direction: column;
            gap: 12px;
        }
        
        .control-label {
            font-size: 14px;
            font-weight: 600;
            color: var(--text);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .control-value {
            background: var(--accent);
            color: white;
            padding: 4px 12px;
            border-radius: 6px;
            font-size: 14px;
            font-weight: 600;
        }
        
        /* Slider */
        input[type="range"] {
            width: 100%;
            height: 8px;
            background: var(--surface-hover);
            border-radius: 4px;
            outline: none;
            -webkit-appearance: none;
        }
        
        input[type="range"]::-webkit-slider-thumb {
            -webkit-appearance: none;
            appearance: none;
            width: 20px;
            height: 20px;
            background: var(--primary);
            border-radius: 50%;
            cursor: pointer;
        }
        
        input[type="range"]::-moz-range-thumb {
            width: 20px;
            height: 20px;
            background: var(--primary);
            border-radius: 50%;
            cursor: pointer;
            border: none;
        }
        
        /* Buttons */
        .btn {
            padding: 12px 24px;
            border: 1px solid var(--border);
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
        }
        
        .btn-primary {
            background: var(--primary);
            color: var(--primary-fg);
            border-color: var(--primary);
        }
        
        .btn-primary:hover {
            opacity: 0.9;
        }
        
        .btn-secondary {
            background: var(--surface);
            color: var(--text);
        }
        
        .btn-secondary:hover {
            background: var(--surface-hover);
        }
        
        .btn-success {
            background: var(--success);
            color: white;
            border-color: var(--success);
        }
        
        .btn-danger {
            background: var(--danger);
            color: white;
            border-color: var(--danger);
        }
        
        .btn-sm {
            padding: 6px 12px;
            font-size: 12px;
        }
        
        .btn-icon {
            width: 36px;
            height: 36px;
            padding: 0;
        }
        
        .button-group {
            display: flex;
            gap: 12px;
        }
        
        /* Status Badge */
        .status-badge {
            padding: 12px 20px;
            border-radius: 8px;
            text-align: center;
            font-size: 14px;
            font-weight: 500;
            background: var(--surface-hover);
            color: var(--text-muted);
        }
        
        .status-badge.active {
            background: rgba(16, 185, 129, 0.1);
            color: var(--success);
        }
        
        /* Empty State */
        .empty-state {
            text-align: center;
            padding: 64px 20px;
            color: var(--text-muted);
        }
        
        .empty-state-title {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 8px;
            color: var(--text);
        }
        
        /* Teleprompter Container */
        .teleprompter-container {
            position: relative;
            background: #000;
            border-radius: 12px;
            overflow: hidden;
            min-height: 500px;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        
        .teleprompter-preview {
            background: #000;
            padding: 60px 40px;
            overflow-y: auto;
            overflow-x: hidden;
            display: block;
            text-align: center;
            font-size: 32px;
            line-height: 1.4;
            color: #fff;
            font-weight: 400;
            margin: 0 auto;
        }
        
        .teleprompter-text {
            display: inline-block;
            max-width: 100%;
        }
        
        .teleprompter-word {
            display: inline;
            color: rgba(255,255,255,1.0);
            transition: all 0.3s;
            font-weight: 400;
        }
        
        .teleprompter-word.current {
            color: #FBBF24;
            background-color: rgba(251, 191, 36, 0.15);
            text-shadow: 0 0 10px #FBBF24;
            font-weight: 400;
            padding: 2px 4px;
            border-radius: 4px;
        }
        
        .teleprompter-word.passed {
            color: rgba(255,255,255,0.5);
        }
        
        /* Teleprompter Controls Overlay */
        .teleprompter-controls {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: linear-gradient(
                to bottom,
                rgba(0,0,0,0.6) 0%,
                transparent 8%,
                transparent 92%,
                rgba(0,0,0,0.6) 100%
            );
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            padding: 16px;
            pointer-events: none;
        }
        
        .teleprompter-controls > * {
            pointer-events: auto;
        }
        
        .controls-top,
        .controls-bottom {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 12px;
        }
        
        .control-btn {
            width: 44px;
            height: 44px;
            background: rgba(255,255,255,0.12);
            border: none;
            border-radius: 10px;
            color: #fff;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: background 0.2s;
        }
        
        .control-btn:hover {
            background: rgba(255,255,255,0.2);
        }
        
        .control-btn:active {
            transform: scale(0.95);
        }
        
        .status-indicator {
            padding: 6px 12px;
            background: rgba(128,128,128,0.2);
            border: 2px solid rgba(128,128,128,0.3);
            border-radius: 12px;
            display: flex;
            align-items: center;
            gap: 6px;
            color: #999;
            font-size: 12px;
            font-weight: 600;
        }
        
        .status-indicator.active {
            background: rgba(16,185,129,0.2);
            border-color: rgba(16,185,129,0.5);
            color: #10B981;
        }
        
        .status-indicator.active::before {
            content: '';
            width: 8px;
            height: 8px;
            background: #10B981;
            border-radius: 50%;
        }
        
        .font-size-display {
            padding: 8px 12px;
            background: rgba(0,0,0,0.4);
            border: 1px solid rgba(255,255,255,0.15);
            border-radius: 10px;
            color: #fff;
            font-size: 18px;
            font-weight: 700;
            min-width: 50px;
            text-align: center;
        }
        
        .speech-btn {
            width: 56px;
            height: 56px;
            background: #10B981;
            border: none;
            border-radius: 50%;
            color: #fff;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 0 16px rgba(16,185,129,0.4);
            transition: all 0.2s;
        }
        
        .speech-btn:hover {
            transform: scale(1.05);
        }
        
        .speech-btn:active {
            transform: scale(0.95);
        }
        
        .speech-btn.active {
            background: #EF4444;
            box-shadow: 0 0 16px rgba(239,68,68,0.4);
        }
        
        /* Loading */
        .loading {
            display: inline-block;
            width: 16px;
            height: 16px;
            border: 2px solid var(--border);
            border-top-color: var(--text);
            border-radius: 50%;
            animation: spin 0.6s linear infinite;
        }
        
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        
        /* Modal */
        .modal-overlay {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.7);
            z-index: 1000;
            align-items: center;
            justify-content: center;
        }
        
        .modal-overlay.active {
            display: flex;
        }
        
        .modal {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 16px;
            padding: 32px;
            max-width: 500px;
            width: 90%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.5);
        }
        
        .modal-title {
            font-size: 24px;
            font-weight: 600;
            color: var(--text);
            margin-bottom: 24px;
        }
        
        .modal-input {
            width: 100%;
            background: var(--background);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 16px;
            font-size: 16px;
            color: var(--text);
            outline: none;
            box-sizing: border-box;
            margin-bottom: 24px;
        }
        
        .modal-input:focus {
            border-color: var(--primary);
        }
        
        .modal-buttons {
            display: flex;
            gap: 12px;
            justify-content: flex-end;
        }
        
        /* Responsive */
        @media (max-width: 768px) {
            .app-container {
                padding: 16px;
            }
            
            .header {
                flex-direction: column;
                align-items: flex-start;
                gap: 16px;
            }
            
            .button-group {
                flex-direction: column;
            }
            
            .btn {
                width: 100%;
            }
        }
    </style>
</head>
<body>
    <div class="app-container">
        <!-- Header -->
        <div class="header">
            <div class="logo">Vompt Remote</div>
            <div class="nav-tabs">
                <button class="tab active">Scripts</button>
                <button class="tab">Editor</button>
                <button class="tab">Control</button>
            </div>
        </div>
        
        <!-- Scripts View -->
        <div id="scripts-view" class="view active">
            <div class="card">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
                    <div class="card-title" style="margin: 0;">Your Scripts</div>
                    <button class="btn btn-primary" onclick="showNewScriptDialog()">New Script</button>
                </div>
                <div id="scripts-list"></div>
            </div>
        </div>
        
        <!-- Editor View -->
        <div id="editor-view" class="view">
            <div class="editor-container">
                <div class="card">
                    <input type="text" id="editor-title" class="editor-title" placeholder="Script Title">
                </div>
                
                <div class="card">
                    <textarea id="editor-content" class="editor-content" placeholder="Start typing your script..."></textarea>
                </div>
                
                <div class="card">
                    <div class="editor-stats">
                        <span>Words: <strong id="word-count">0</strong></span>
                        <span>Characters: <strong id="char-count">0</strong></span>
                        <span>Reading time: <strong id="read-time">0 min</strong></span>
                    </div>
                </div>
                
                <div class="button-group">
                    <button class="btn btn-secondary" onclick="switchView('scripts')">Back to Scripts</button>
                    <button class="btn btn-primary" id="save-btn" onclick="saveDocument()">Save</button>
                    <button class="btn btn-success" onclick="openControl()">Start Teleprompter</button>
                </div>
                
                <div id="save-status" class="status-badge" style="display: none; margin-top: 16px;"></div>
            </div>
        </div>
        
        <!-- Control View -->
        <div id="control-view" class="view">
            <!-- Teleprompter Preview (full screen style) -->
            <div class="teleprompter-container">
                <div class="teleprompter-preview" id="preview-content" style="width: ${_remoteControlService.screenWidth}px; height: ${_remoteControlService.screenHeight}px; max-width: ${_remoteControlService.screenWidth}px; max-height: ${_remoteControlService.screenHeight}px; font-size: ${_remoteControlService.fontSize}px;">
                    Select a script to begin
                </div>
                
                <!-- Teleprompter Controls Overlay -->
                <div class="teleprompter-controls">
                    <!-- Top row -->
                    <div class="controls-top">
                        <button class="control-btn" onclick="switchView('editor')">
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M6 18L18 6M6 6l12 12"/>
                            </svg>
                        </button>
                        
                        <div class="status-indicator" id="speech-status">
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                                <path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3z"/>
                                <path d="M17 11c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z"/>
                            </svg>
                            <span id="status-text">Paused</span>
                        </div>
                        
                        <button class="control-btn" onclick="toggleMirror()" id="mirror-btn">
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7"/>
                                <path d="M12 3v18"/>
                            </svg>
                        </button>
                    </div>
                    
                    <!-- Bottom row -->
                    <div class="controls-bottom">
                        <button class="control-btn" onclick="decreaseFontSize()">
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <text x="2" y="18" font-size="16" font-weight="bold" fill="currentColor">A</text>
                                <path d="M16 16h6M19 13v6"/>
                            </svg>
                        </button>
                        
                        <div class="font-size-display" id="font-display">${_remoteControlService.fontSize.toInt()}</div>
                        
                        <button class="control-btn" onclick="increaseFontSize()">
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <text x="2" y="18" font-size="20" font-weight="bold" fill="currentColor">A</text>
                                <path d="M16 13h6M19 10v6"/>
                            </svg>
                        </button>
                        
                        <button class="control-btn" onclick="resetTeleprompter()">
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2"/>
                            </svg>
                        </button>
                        
                        <button class="speech-btn" id="speech-btn" onclick="toggleSpeech()">
                            <svg width="28" height="28" viewBox="0 0 24 24" fill="currentColor">
                                <path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3z"/>
                                <path d="M17 11c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z"/>
                            </svg>
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- New Script Modal -->
    <div id="new-script-modal" class="modal-overlay" onclick="if(event.target === this) hideNewScriptDialog()">
        <div class="modal">
            <div class="modal-title">New Script</div>
            <input type="text" id="new-script-title" class="modal-input" placeholder="Script title" onkeypress="if(event.key === 'Enter') createNewScript()">
            <div class="modal-buttons">
                <button class="btn btn-secondary" onclick="hideNewScriptDialog()">Cancel</button>
                <button class="btn btn-primary" onclick="createNewScript()">Create</button>
            </div>
        </div>
    </div>
    
    <script>
        // State
        let currentView = 'scripts';
        let documents = [];
        let currentDocument = null;
        
        // Initialize
        loadDocuments();
        
        // Connect to server and start heartbeat
        fetch('/api/client/connect', {method: 'POST'});
        setInterval(() => {
            fetch('/api/client/heartbeat', {method: 'POST'});
        }, 5000); // Send heartbeat every 5 seconds
        
        // Handle page unload/refresh - exit control if in control view
        window.addEventListener('beforeunload', () => {
            if (currentView === 'control') {
                // Use sendBeacon for reliable delivery during page unload
                navigator.sendBeacon('/api/control/exit');
            }
        });
        
        // View switching
        function switchView(view) {
            const wasInControl = currentView === 'control';
            
            currentView = view;
            document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            document.getElementById(view + '-view').classList.add('active');
            
            // Update tab indicator
            const tabs = document.querySelectorAll('.tab');
            if (view === 'scripts') tabs[0].classList.add('active');
            else if (view === 'editor') tabs[1].classList.add('active');
            else if (view === 'control') tabs[2].classList.add('active');
            
            // Start/stop state polling based on view
            if (view === 'control') {
                startStatePolling();
            } else {
                stopStatePolling();
                // Notify server when leaving control view
                if (wasInControl) {
                    fetch('/api/control/exit', {method: 'POST'})
                        .then(() => console.log('Exited control view'))
                        .catch(err => console.error('Failed to exit control:', err));
                }
            }
        }
        
        // Load documents
        async function loadDocuments() {
            try {
                const response = await fetch('/api/documents');
                documents = await response.json();
                renderScripts();
            } catch (error) {
                console.error('Failed to load documents:', error);
            }
        }
        
        // Render scripts list
        function renderScripts() {
            const container = document.getElementById('scripts-list');
            
            if (documents.length === 0) {
                container.innerHTML = \`
                    <div class="empty-state">
                        <div class="empty-state-title">No scripts yet</div>
                        <div>Create your first script in the iOS app</div>
                    </div>
                \`;
                return;
            }
            
            container.innerHTML = documents.map(doc => \`
                <div class="script-item" onclick="openEditor('\${doc.id}')">
                    <div class="script-info">
                        <h3>\${doc.title}</h3>
                        <div class="script-meta">
                            Modified: \${new Date(doc.modifiedAt).toLocaleDateString()}
                        </div>
                    </div>
                    <div class="script-actions">
                        <button class="btn btn-sm btn-secondary" onclick="event.stopPropagation(); openEditorForScript('\${doc.id}')">Edit</button>
                    </div>
                </div>
            \`).join('');
        }
        
        // Open editor
        async function openEditor(docId) {
            const doc = documents.find(d => d.id === docId);
            if (!doc) return;
            
            currentDocument = doc;
            document.getElementById('editor-title').value = doc.title;
            document.getElementById('editor-content').value = doc.content;
            updateEditorStats();
            switchView('editor');
        }
        
        function openEditorForScript(docId) {
            openEditor(docId);
        }
        
        // Update editor stats
        function updateEditorStats() {
            const content = document.getElementById('editor-content').value;
            const words = content.trim().split(/\\s+/).filter(w => w.length > 0).length;
            const chars = content.length;
            const readTime = Math.ceil(words / 150); // 150 words per minute
            
            document.getElementById('word-count').textContent = words;
            document.getElementById('char-count').textContent = chars;
            document.getElementById('read-time').textContent = readTime + ' min';
        }
        
        document.getElementById('editor-content')?.addEventListener('input', updateEditorStats);
        
        // Save document
        async function saveDocument() {
            if (!currentDocument) return;
            
            const title = document.getElementById('editor-title').value;
            const content = document.getElementById('editor-content').value;
            
            // Update current document
            currentDocument.title = title;
            currentDocument.content = content;
            
            try {
                // Save content
                await fetch(\`/api/documents/\${currentDocument.id}/content\`, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({content, title})
                });
                
                showStatus('Saved successfully', 'success');
                await loadDocuments();
            } catch (error) {
                showStatus('Failed to save', 'danger');
                console.error('Save error:', error);
            }
        }
        
        // Control state - initialized from server
        let currentFontSize = ${_remoteControlService.fontSize};
        const iosScreenWidth = ${_remoteControlService.screenWidth};
        const iosScreenHeight = ${_remoteControlService.screenHeight};
        let isSpeechActive = false;
        let isMirrored = false;
        let statePollingInterval = null;
        
        // Control functions
        function openControl() {
            if (!currentDocument) {
                console.error('No document selected');
                alert('Please select a script first');
                return;
            }
            
            console.log('Opening control for document:', currentDocument.title);
            
            switchView('control');
            loadTeleprompterPreview();
            
            // Notify server about document selection and trigger iOS navigation
            fetch('/api/control/select-document', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({documentId: currentDocument.id})
            }).then(response => {
                console.log('Document selected on server:', response.ok);
            });
        }
        
        function openControlForScript(docId) {
            const doc = documents.find(d => d.id === docId);
            if (doc) {
                currentDocument = doc;
                openControl();
            }
        }
        
        function loadTeleprompterPreview() {
            if (!currentDocument) {
                console.error('Cannot load preview: no document');
                return;
            }
            
            console.log('Loading teleprompter preview for:', currentDocument.title);
            console.log('Content length:', currentDocument.content.length);
            console.log('📱 iOS dimensions (from server):', iosScreenWidth, 'x', iosScreenHeight);
            console.log('📱 Font size (from server):', currentFontSize);
            
            const preview = document.getElementById('preview-content');
            
            // Split into words exactly like iOS does
            // First normalize the content by replacing all whitespace sequences with single space
            console.log('📝 Original content sample:', currentDocument.content.substring(0, 100));
            
            // Replace newlines, carriage returns, tabs, and multiple spaces explicitly
            let normalizedContent = currentDocument.content;
            normalizedContent = normalizedContent.replace(/\\r\\n/g, ' ');  // Windows line endings
            normalizedContent = normalizedContent.replace(/\\n/g, ' ');     // Unix line endings
            normalizedContent = normalizedContent.replace(/\\r/g, ' ');     // Old Mac line endings
            normalizedContent = normalizedContent.replace(/\\t/g, ' ');     // Tabs
            normalizedContent = normalizedContent.replace(/ {2,}/g, ' ');   // Multiple spaces to single
            normalizedContent = normalizedContent.trim();
            
            console.log('📝 Normalized content sample:', normalizedContent.substring(0, 100));
            const words = normalizedContent.split(' ');
            console.log('📝 Web UI word count:', words.length);
            console.log('📝 First 10 words:', words.slice(0, 10));
            
            // Clear preview and build with DOM nodes to avoid escaping issues
            preview.innerHTML = '';
            
            words.forEach((word, index) => {
                // Skip empty strings but keep the index consistent
                if (word.length === 0) return;
                
                const span = document.createElement('span');
                span.className = 'teleprompter-word';
                span.setAttribute('data-index', index.toString());
                span.textContent = word;
                preview.appendChild(span);
                
                // Add space after each word (except last)
                if (index < words.length - 1) {
                    preview.appendChild(document.createTextNode(' '));
                }
            });
            preview.style.fontSize = currentFontSize + 'px';
            preview.style.transform = isMirrored ? 'scaleX(-1)' : 'scaleX(1)';
        }
        
        async function toggleSpeech() {
            if (isSpeechActive) {
                await fetch('/api/control/pause', {method: 'POST'});
                isSpeechActive = false;
                updateSpeechUI();
            } else {
                await fetch('/api/control/play', {method: 'POST'});
                isSpeechActive = true;
                updateSpeechUI();
            }
        }
        
        function updateSpeechUI() {
            const btn = document.getElementById('speech-btn');
            const status = document.getElementById('speech-status');
            const statusText = document.getElementById('status-text');
            
            if (isSpeechActive) {
                btn.classList.add('active');
                status.classList.add('active');
                statusText.textContent = 'Listening';
            } else {
                btn.classList.remove('active');
                status.classList.remove('active');
                statusText.textContent = 'Paused';
            }
        }
        
        async function increaseFontSize() {
            currentFontSize = Math.min(72, currentFontSize + 2);
            document.getElementById('font-display').textContent = currentFontSize;
            document.getElementById('preview-content').style.fontSize = currentFontSize + 'px';
            
            // Update iOS teleprompter font size
            await fetch('/api/control/fontsize', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({action: 'increase'})
            });
        }
        
        async function decreaseFontSize() {
            currentFontSize = Math.max(16, currentFontSize - 2);
            document.getElementById('font-display').textContent = currentFontSize;
            document.getElementById('preview-content').style.fontSize = currentFontSize + 'px';
            
            await fetch('/api/control/fontsize', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({action: 'decrease'})
            });
        }
        
        async function toggleMirror() {
            isMirrored = !isMirrored;
            document.getElementById('preview-content').style.transform = isMirrored ? 'scaleX(-1)' : 'scaleX(1)';
            
            await fetch('/api/control/mirror', {method: 'POST'});
        }
        
        async function resetTeleprompter() {
            await fetch('/api/control/reset', {method: 'POST'});
            isSpeechActive = false;
            updateSpeechUI();
        }
        
        let lastScrolledLine = -1;
        
        // Poll for teleprompter state updates
        async function pollTeleprompterState() {
            try {
                const response = await fetch('/api/control/state');
                const state = await response.json();
                
                // Use hardcoded dimensions from server
                updateWordHighlighting(state.currentWordIndex, currentFontSize, iosScreenWidth, iosScreenHeight);
            } catch (error) {
                console.error('Failed to poll state:', error);
            }
        }
        
        function updateWordHighlighting(currentIndex, fontSize, screenWidth, screenHeight) {
            const words = document.querySelectorAll('.teleprompter-word');
            const preview = document.getElementById('preview-content');
            
            // Update highlighting
            words.forEach((word, index) => {
                word.classList.remove('current', 'passed');
                if (index === currentIndex) {
                    word.classList.add('current');
                } else if (index < currentIndex) {
                    word.classList.add('passed');
                }
            });
            
            // Line-based scrolling
            if (currentIndex >= 0 && fontSize > 0 && screenWidth > 0) {
                const avgWordWidth = fontSize * 5 * 0.6;
                const wordsPerLine = Math.floor((screenWidth - 64) / avgWordWidth);
                const currentLine = Math.floor(currentIndex / wordsPerLine);
                
                if (currentLine !== lastScrolledLine) {
                    lastScrolledLine = currentLine;
                    
                    // Calculate line height - decrease multiplier as font size increases
                    // Small fonts (16-32): 1.4x multiplier
                    // Large fonts (60-72): 1.1x multiplier
                    const lineHeightMultiplier = 1.4 - ((fontSize - 16) / 186.67);
                    const lineHeight = fontSize * lineHeightMultiplier;
                    
                    const linePosition = currentLine * lineHeight;
                    const targetScroll = linePosition - (preview.clientHeight * 0.35);
                    
                    preview.scrollTo({
                        top: Math.max(0, targetScroll),
                        behavior: 'smooth'
                    });
                }
            }
        }
        
        function startStatePolling() {
            if (statePollingInterval) return;
            statePollingInterval = setInterval(pollTeleprompterState, 200); // Poll every 200ms
        }
        
        function stopStatePolling() {
            if (statePollingInterval) {
                clearInterval(statePollingInterval);
                statePollingInterval = null;
            }
        }
        
        function showStatus(message, type) {
            const status = document.getElementById('save-status');
            if (status) {
                status.textContent = message;
                status.style.display = 'block';
                status.className = 'status-badge ' + (type === 'success' ? 'active' : '');
                
                // Update save button
                const saveBtn = document.getElementById('save-btn');
                if (saveBtn && type === 'success') {
                    const originalText = saveBtn.textContent;
                    saveBtn.textContent = 'Saved!';
                    setTimeout(() => {
                        saveBtn.textContent = originalText;
                    }, 2000);
                }
                
                setTimeout(() => {
                    status.style.display = 'none';
                }, 3000);
            }
        }
        
        // New script modal functions
        function showNewScriptDialog() {
            const modal = document.getElementById('new-script-modal');
            const input = document.getElementById('new-script-title');
            modal.classList.add('active');
            input.value = '';
            setTimeout(() => input.focus(), 100);
        }
        
        function hideNewScriptDialog() {
            const modal = document.getElementById('new-script-modal');
            modal.classList.remove('active');
        }
        
        async function createNewScript() {
            const title = document.getElementById('new-script-title').value.trim();
            
            if (!title) {
                alert('Please enter a script title');
                return;
            }
            
            try {
                const response = await fetch('/api/documents', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({title})
                });
                
                if (response.ok) {
                    const newDoc = await response.json();
                    hideNewScriptDialog();
                    await loadDocuments();
                    // Open the new document in editor
                    openEditor(newDoc.id);
                } else {
                    alert('Failed to create script');
                }
            } catch (error) {
                console.error('Create error:', error);
                alert('Failed to create script');
            }
        }
    </script>
</body>
</html>
    ''';

    return Response.ok(
      html,
      headers: {'Content-Type': 'text/html'},
    );
  }

  // Get all documents
  Future<Response> _getDocuments(Request request) async {
    try {
      final documents = await _documentRepository.readAll();
      final jsonList = documents.map((doc) => doc.toJson()).toList();
      return Response.ok(
        jsonEncode(jsonList),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  // Get single document
  Future<Response> _getDocument(Request request, String id) async {
    try {
      final document = await _documentRepository.read(id);
      if (document == null) {
        return Response.notFound(
          jsonEncode({'error': 'Document not found'}),
        );
      }
      return Response.ok(
        jsonEncode(document.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  // Create new document
  Future<Response> _createDocument(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final title = data['title'] as String?;

      if (title == null || title.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Title is required'}),
        );
      }

      final now = DateTime.now();
      final document = Document(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        content: '',
        createdAt: now,
        modifiedAt: now,
      );

      await _documentRepository.create(document);

      return Response.ok(
        jsonEncode(document.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  // Update document content
  Future<Response> _updateDocumentContent(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final content = data['content'] as String?;
      final title = data['title'] as String?;

      if (content == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Content is required'}),
        );
      }

      final document = await _documentRepository.read(id);
      if (document == null) {
        return Response.notFound(
          jsonEncode({'error': 'Document not found'}),
        );
      }

      final updatedDoc = document.copyWith(
        content: content,
        title: title ?? document.title, // Update title if provided
        modifiedAt: DateTime.now(),
      );
      await _documentRepository.update(updatedDoc);

      return Response.ok(
        jsonEncode({'success': true}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  // Control endpoints
  Future<Response> _controlPlay(Request request) async {
    try {
      _remoteControlService.startSpeech();
      return Response.ok(
        jsonEncode({'success': true, 'action': 'startSpeech'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _controlPause(Request request) async {
    try {
      _remoteControlService.stopSpeech();
      return Response.ok(
        jsonEncode({'success': true, 'action': 'stopSpeech'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _controlFontSize(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final action = data['action'] as String?;

      if (action == 'increase') {
        _remoteControlService.increaseFontSize();
      } else if (action == 'decrease') {
        _remoteControlService.decreaseFontSize();
      } else {
        return Response.badRequest(
          body: jsonEncode({'error': 'Action must be "increase" or "decrease"'}),
        );
      }

      return Response.ok(
        jsonEncode({'success': true, 'action': action}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _controlMirror(Request request) async {
    try {
      _remoteControlService.toggleMirror();
      return Response.ok(
        jsonEncode({'success': true, 'action': 'mirror'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _controlReset(Request request) async {
    try {
      _remoteControlService.reset();
      return Response.ok(
        jsonEncode({'success': true, 'action': 'reset'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _selectDocument(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final documentId = data['documentId'] as String?;

      if (documentId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Document ID is required'}),
        );
      }

      _remoteControlService.selectDocument(documentId);
      return Response.ok(
        jsonEncode({'success': true, 'documentId': documentId}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _exitControl(Request request) async {
    try {
      _remoteControlService.exitControl();
      return Response.ok(
        jsonEncode({'success': true}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _getControlState(Request request) async {
    try {
      return Response.ok(
        jsonEncode({
          'currentWordIndex': _remoteControlService.currentWordIndex,
          'isActive': _remoteControlService.isActive,
          // Dimensions and fontSize only sent on initial load, not every poll
          'fontSize': _remoteControlService.fontSize,
          'screenWidth': _remoteControlService.screenWidth,
          'screenHeight': _remoteControlService.screenHeight,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _clientConnect(Request request) async {
    try {
      _remoteControlService.setClientConnected(true);
      return Response.ok(
        jsonEncode({'success': true, 'connected': true}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _clientHeartbeat(Request request) async {
    try {
      // Keep the connection alive
      _remoteControlService.setClientConnected(true);
      return Response.ok(
        jsonEncode({'success': true, 'timestamp': DateTime.now().toIso8601String()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }
}
