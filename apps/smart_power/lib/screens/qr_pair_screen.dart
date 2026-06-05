import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/app_icons.dart';

/// Full-screen QR scanner. Reads a JSON payload `{"url": "...", "token": "..."}`
/// and returns it to the caller as a [QrPairing] via `Navigator.pop`.
///
/// The HA-side QR generator lives at `deploy/ha/pair-qr.html` in this repo —
/// the operator opens it in a browser, pastes URL + token, and scans the
/// resulting QR from their laptop screen with this scanner.
class QrPairing {
  final String url;
  final String token;
  const QrPairing({required this.url, required this.token});
}

class QrPairScreen extends StatefulWidget {
  const QrPairScreen({super.key});

  @override
  State<QrPairScreen> createState() => _QrPairScreenState();
}

class _QrPairScreenState extends State<QrPairScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _consumed = false;
  String? _errorMessage;

  void _onDetect(BarcodeCapture capture) {
    if (_consumed) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final pairing = _parse(raw);
      if (pairing != null) {
        _consumed = true;
        _controller.stop();
        Navigator.of(context).pop(pairing);
        return;
      }
      setState(() => _errorMessage =
          'QR doesn\'t look like a Smart Power pairing code. Try again.');
    }
  }

  /// Accepts:
  /// 1. JSON `{"url":"http://...","token":"..."}` (preferred)
  /// 2. `smartpower://pair?url=http://...&token=...` (custom-scheme fallback)
  QrPairing? _parse(String raw) {
    final trimmed = raw.trim();
    // JSON
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final url = (decoded['url'] ?? '').toString().trim();
          final token = (decoded['token'] ?? '').toString().trim();
          if (url.isNotEmpty && token.isNotEmpty) {
            return QrPairing(url: url, token: token);
          }
        }
      } catch (_) {/* fall through */}
    }
    // URL scheme
    try {
      final uri = Uri.parse(trimmed);
      if (uri.scheme == 'smartpower' && uri.host == 'pair') {
        final url = uri.queryParameters['url']?.trim();
        final token = uri.queryParameters['token']?.trim();
        if (url != null && url.isNotEmpty && token != null && token.isNotEmpty) {
          return QrPairing(url: url, token: token);
        }
      }
    } catch (_) {/* fall through */}
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan pairing QR'),
        leading: IconButton(
          tooltip: 'Cancel',
          icon: HugeIcon(
            icon: AppIcons.close,
            size: 22,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle torch',
            onPressed: () => _controller.toggleTorch(),
            icon: HugeIcon(
              icon: AppIcons.bolt,
              size: 22,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Viewfinder overlay
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ViewfinderPainter(),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Generate the QR from deploy/ha/pair-qr.html on your '
                      'computer, then point your phone at it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shorter = size.shortestSide;
    final box = shorter * 0.72;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: box,
      height: box,
    );

    // Dim the area outside the box
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      overlay,
      Paint()..color = const Color(0xCC000000),
    );

    // Corner brackets
    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const arm = 22.0;
    void drawCorner(Offset p, Offset h, Offset v) {
      canvas.drawLine(p, p + h, corner);
      canvas.drawLine(p, p + v, corner);
    }

    drawCorner(rect.topLeft, const Offset(arm, 0), const Offset(0, arm));
    drawCorner(rect.topRight, const Offset(-arm, 0), const Offset(0, arm));
    drawCorner(rect.bottomLeft, const Offset(arm, 0), const Offset(0, -arm));
    drawCorner(rect.bottomRight, const Offset(-arm, 0), const Offset(0, -arm));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
