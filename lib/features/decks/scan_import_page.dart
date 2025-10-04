// lib/features/decks/scan_import_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsBindingObserver, AppLifecycleState;
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanImportPage extends StatefulWidget {
  const ScanImportPage({super.key});

  @override
  State<ScanImportPage> createState() => _ScanImportPageState();
}

class _ScanImportPageState extends State<ScanImportPage>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: [BarcodeFormat.qrCode],
    returnImage: false,
    // cameraResolution: const Size(1280, 720), // 必要なら有効化
  );

  bool _handled = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // _ensureCameraPermission();
  }

  // Future<void> _ensureCameraPermission() async {
  //   try {
  //     await _controller.start(); // バージョンによっては requestPermission()
  //   } catch (_) {}
  // }

  @override
  void deactivate() {
    _controller.stop(); // 遷移中も停止
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller.stop();
    }
  }

  Future<void> _safePop([String? result]) async {
    if (_closing || !mounted) return;
    _closing = true;
    try {
      await _controller.stop();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    } catch (_) {}
    if (mounted) Navigator.of(context).pop(result);
  }

  String? _extractImportId(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');

    final mImpc = RegExp(r'^impc:(?://)?([A-Za-z0-9_-]{4,64})$').firstMatch(text);
    if (mImpc != null) return mImpc.group(1);

    final plain = RegExp(r'^[A-Za-z0-9_-]{4,64}$');
    if (plain.hasMatch(text)) return text;

    final uri = Uri.tryParse(text);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final segs = uri.pathSegments;
      final idx = segs.indexOf('import');
      if (idx >= 0 && idx + 1 < segs.length) {
        final cand = segs[idx + 1];
        if (plain.hasMatch(cand)) return cand;
      }
      final qp = uri.queryParameters['id'] ?? uri.queryParameters['deckId'];
      if (qp != null && plain.hasMatch(qp)) return qp;
    }
    if (uri != null && uri.scheme.isNotEmpty) {
      final qp = uri.queryParameters['id'] ?? uri.queryParameters['deckId'];
      if (qp != null && plain.hasMatch(qp)) return qp;
    }
    final mJson = RegExp(r'"id"\s*:\s*"([A-Za-z0-9_-]{4,64})"').firstMatch(text);
    if (mJson != null) return mJson.group(1);

    return null;
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_handled || _closing) return;
    if (capture.barcodes.isEmpty) return;

    String? importId;
    for (final b in capture.barcodes) {
      final raw = b.rawValue ?? '';
      final id = _extractImportId(raw);
      if (id != null) {
        importId = id;
        break;
      }
    }

    if (importId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('このQRからImport IDを読み取れませんでした')),
      );
      HapticFeedback.mediumImpact();
      return;
    }

    _handled = true;
    HapticFeedback.selectionClick();
    await _safePop(importId);
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;

    return PopScope(          // ★ WillPopScope → PopScope
      canPop: false,          // 既定のpopをブロック（predictive back対応）
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;   // すでにpopされた場合は何もしない
        await _safePop();     // 明示停止してから戻る
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              // allowDuplicates: false, // 対応版なら多重検出抑止
            ),
            Positioned(
              top: safeTop + 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  IconButton(
                    color: Colors.white,
                    onPressed: () => _safePop(),
                    icon: const Icon(Icons.close),
                  ),
                  const Spacer(),
                  IconButton(
                    color: Colors.white,
                    onPressed: () => _controller.toggleTorch(),
                    icon: const Icon(Icons.flash_on),
                  ),
                  if (Platform.isAndroid || Platform.isIOS)
                    IconButton(
                      color: Colors.white,
                      onPressed: () => _controller.switchCamera(),
                      icon: const Icon(Icons.cameraswitch),
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
