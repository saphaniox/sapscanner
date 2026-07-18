import 'package:flutter/material.dart';

import 'src/controllers/scanner_controller.dart';
import 'src/services/scanner_services.dart';
import 'src/services/storage_service.dart';
import 'src/theme/sap_theme.dart';
import 'src/views/sap_scanner_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    SapScannerApp(
      controller: ScannerController(
        scannerService: NativeScannerService(),
        exportService: DocumentExportService(),
        compressionService: NativeCompressionService(),
        storageService: JsonStorageService(),
      ),
    ),
  );
}

class SapScannerApp extends StatelessWidget {
  const SapScannerApp({super.key, required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SapScanner',
      debugShowCheckedModeBanner: false,
      theme: SapTheme.light(),
      home: SapScannerHome(controller: controller),
    );
  }
}
