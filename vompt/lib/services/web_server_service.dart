import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../data/models/document.dart';
import '../data/repositories/document_repository.dart';
import 'remote_control_service.dart';
import 'script_assistant.dart';

/// Serves Vompt Studio, the browser remote, from the phone on the local network.
///
/// Every /api request must carry the session key (the `k` query parameter in
/// the link and QR code, then the X-Vompt-Key header), so other people on the
/// same Wi-Fi can't read or change scripts.
class WebServerService {
  HttpServer? _server;
  final DocumentRepository _documents = DocumentRepository();
  final RemoteControlService _remote = RemoteControlService();
  final int port;
  String? _localIpAddress;
  late String _key;

  WebServerService({this.port = AppConstants.defaultServerPort});

  bool get isRunning => _server != null;

  /// The link to open, including the session key.
  String? get serverUrl =>
      _localIpAddress == null ? null : 'http://$_localIpAddress:$port/?k=$_key';

  String get key => _key;

  Future<String?> startServer() async {
    if (_server != null) return serverUrl;
    _localIpAddress = await _findLocalAddress();
    if (_localIpAddress == null) {
      throw const SocketException(
        'Connect this iPhone to Wi-Fi to use the web remote.',
      );
    }
    _key = _newKey();
    final handler = const Pipeline()
        .addMiddleware(_auth())
        .addHandler(_router().call);
    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    return serverUrl;
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// The address other devices on the network can reach: Wi-Fi first, then
  /// any private IPv4 interface (personal hotspot, ethernet, simulator).
  static Future<String?> _findLocalAddress() async {
    try {
      final wifi = await NetworkInfo().getWifiIP();
      if (wifi != null && wifi.isNotEmpty) return wifi;
    } catch (_) {}
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    String? fallback;
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final ip = address.address;
        final private =
            ip.startsWith('192.168.') ||
            ip.startsWith('10.') ||
            RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);
        if (!private || address.isLoopback) continue;
        if (interface.name.startsWith('en') ||
            interface.name.startsWith('bridge')) {
          return ip;
        }
        fallback ??= ip;
      }
    }
    return fallback;
  }

  static String _newKey() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(
      6,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
  }

  Middleware _auth() =>
      (inner) => (request) {
        if (!request.url.path.startsWith('api/')) return inner(request);
        final supplied =
            request.headers['x-vompt-key'] ?? request.url.queryParameters['k'];
        if (supplied?.toUpperCase() != _key) {
          return _json({
            'error':
                'This link has expired. Open the link shown on the iPhone again.',
          }, status: 401);
        }
        return inner(request);
      };

  Router _router() {
    final r = Router();

    r.get(
      '/',
      (Request _) async => Response.ok(
        await rootBundle.loadString('assets/web/index.html'),
        headers: {
          'content-type': 'text/html; charset=utf-8',
          'cache-control': 'no-store',
        },
      ),
    );
    r.get('/font.ttf', (Request _) async {
      final data = await rootBundle.load(
        'assets/web/AtkinsonHyperlegibleNext.ttf',
      );
      return Response.ok(
        data.buffer.asUint8List(),
        headers: {'content-type': 'font/ttf', 'cache-control': 'max-age=86400'},
      );
    });

    // Scripts
    r.get('/api/documents', (Request _) async {
      final docs = await _documents.readAll();
      return _json(docs.map((d) => d.toJson()).toList());
    });
    r.get('/api/documents/<id>', (Request _, String id) async {
      final doc = await _documents.read(id);
      return doc == null
          ? _json({'error': 'Script not found'}, status: 404)
          : _json(doc.toJson());
    });
    r.post('/api/documents', (Request request) async {
      final body = await _body(request);
      final now = DateTime.now();
      final title = (body['title'] as String?)?.trim();
      final doc = Document(
        id: const Uuid().v4(),
        title: title == null || title.isEmpty ? 'Untitled script' : title,
        content: body['content'] as String? ?? '',
        createdAt: now,
        modifiedAt: now,
      );
      await _documents.create(doc);
      _remote.documentsChanged();
      return _json(doc.toJson());
    });
    r.post('/api/documents/<id>/content', (Request request, String id) async {
      final body = await _body(request);
      final doc = await _documents.read(id);
      if (doc == null) return _json({'error': 'Script not found'}, status: 404);
      final title = (body['title'] as String?)?.trim();
      final updated = doc.copyWith(
        content: body['content'] as String? ?? doc.content,
        title: title == null || title.isEmpty ? doc.title : title,
        modifiedAt: DateTime.now(),
      );
      await _documents.update(updated);
      _remote.documentsChanged();
      return _json(updated.toJson());
    });
    r.delete('/api/documents/<id>', (Request _, String id) async {
      await _documents.delete(id);
      _remote.documentsChanged();
      return _json({'success': true});
    });

    // Teleprompter control
    r.post('/api/control/play', (Request _) => _ok(_remote.startSpeech));
    r.post('/api/control/pause', (Request _) => _ok(_remote.stopSpeech));
    r.post('/api/control/reset', (Request _) => _ok(_remote.reset));
    r.post('/api/control/finish', (Request _) => _ok(_remote.finishTake));
    r.post('/api/control/mirror', (Request _) => _ok(_remote.toggleMirror));
    r.post('/api/control/exit', (Request _) => _ok(_remote.exitControl));
    r.post('/api/control/fontsize', (Request request) async {
      final action = (await _body(request))['action'];
      if (action == 'increase') {
        _remote.increaseFontSize();
      } else if (action == 'decrease') {
        _remote.decreaseFontSize();
      } else {
        return _json({
          'error': 'action must be "increase" or "decrease"',
        }, status: 400);
      }
      return _json({'success': true});
    });
    r.post('/api/control/select-document', (Request request) async {
      final id = (await _body(request))['documentId'] as String?;
      if (id == null) {
        return _json({'error': 'documentId is required'}, status: 400);
      }
      _remote.selectDocument(id);
      return _json({'success': true});
    });
    r.get(
      '/api/control/state',
      (Request _) => _json({
        'connected': _remote.hasActiveClient,
        'prompterOpen': _remote.prompterOpen,
        'currentWordIndex': _remote.currentWordIndex,
        'isActive': _remote.isActive,
        'isMirrored': _remote.isMirrored,
        'fontSize': _remote.fontSize,
        'screenWidth': _remote.screenWidth,
        'screenHeight': _remote.screenHeight,
        ..._remote.live,
      }),
    );

    // Presence: keeps the phone in remote mode while the page is open.
    r.post(
      '/api/client/connect',
      (Request _) => _ok(() => _remote.setClientConnected(true)),
    );
    r.post(
      '/api/client/heartbeat',
      (Request _) => _ok(() => _remote.setClientConnected(true)),
    );

    // On-device AI
    r.get('/api/ai/status', (Request _) async {
      final status = await ScriptAssistant.instance.availability(refresh: true);
      return _json({'available': status.available, 'reason': status.reason});
    });
    r.post('/api/ai/run', (Request request) async {
      final body = await _body(request);
      final task = ScriptTask.values
          .where((t) => t.name == body['task'])
          .firstOrNull;
      if (task == null) return _json({'error': 'Unknown task'}, status: 400);
      try {
        final text = await ScriptAssistant.instance.run(
          task,
          body['text'] as String? ?? '',
          seconds: (body['seconds'] as num?)?.toInt(),
          tone: body['tone'] as String? ?? 'warm and confident',
        );
        return _json({'text': text});
      } on AssistantUnavailable catch (e) {
        return _json({'error': e.message}, status: 503);
      }
    });

    r.get(
      '/api/health',
      (Request _) => _json({'status': 'ok', 'app': AppConstants.appName}),
    );
    return r;
  }

  static Future<Map<String, dynamic>> _body(Request request) async {
    final raw = await request.readAsString();
    if (raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  static Response _ok(void Function() action) {
    action();
    return _json({'success': true});
  }

  static Response _json(Object body, {int status = 200}) => Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json', 'cache-control': 'no-store'},
  );
}
