import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sapscanner/src/controllers/scanner_controller.dart';
import 'package:sapscanner/src/models/scan_models.dart';
import 'package:sapscanner/src/services/scanner_services.dart';
import 'package:sapscanner/src/services/storage_service.dart';

void main() {
  test(
    'imports, searches, edits, exports, compresses, and clears workspace',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'sapscanner-controller-',
      );
      final exportService = _FakeExportService(temp);
      final controller = ScannerController(
        scannerService: _FakeScanService(),
        exportService: exportService,
        compressionService: _FakeCompressionService(temp),
        storageService: JsonStorageService(directory: temp),
      );

      await controller.restore();
      await controller.importFiles();

      expect(controller.batch.pages.length, 1);
      expect(controller.activePage?.title, 'Imported receipt');

      controller.setSearchQuery('receipt');
      expect(controller.filteredPages.length, 1);

      controller.applyFilterToActivePage(ScanFilter.grayscale);
      controller.rotateActivePage(90);
      controller.toggleFavorite(controller.activePage!.id);

      expect(controller.activePage?.filter, ScanFilter.grayscale);
      expect(controller.activePage?.rotation, 90);
      expect(controller.activePage?.favorite, isTrue);

      controller.duplicateActivePage();
      expect(controller.batch.pages.length, 2);

      await controller.export(ExportFormat.pdf);
      expect(controller.lastExport?.format, ExportFormat.pdf);
      expect(File(controller.lastExport!.outputPath).existsSync(), isTrue);

      await controller.exportActive(ExportFormat.word);
      expect(controller.lastExport?.format, ExportFormat.word);
      expect(File(controller.lastExport!.outputPath).existsSync(), isTrue);
      expect(exportService.exportedBatches.last.pages.length, 1);

      await controller.mergeWorkspaceToPdf();
      expect(controller.lastExport?.format, ExportFormat.pdf);
      expect(File(controller.lastExport!.outputPath).existsSync(), isTrue);
      expect(exportService.exportedBatches.last.pages.length, 2);
      expect(controller.notice, contains('Merged 2 pages'));

      await controller.compressActivePageToPdf();
      expect(controller.lastExport?.format, ExportFormat.pdf);
      expect(File(controller.lastExport!.outputPath).existsSync(), isTrue);
      expect(exportService.exportedBatches.last.pages.length, 1);
      expect(
        exportService.exportedBatches.last.exportSettings.imageQuality,
        CompressionPreset.maximum.imageQuality,
      );
      expect(controller.notice, 'Compressed active page to PDF');

      await controller.compress(CompressionPreset.maximum);
      expect(controller.lastCompression?.items, 1);
      expect(File(controller.lastCompression!.outputPath).existsSync(), isTrue);

      controller.updateLanguage(AppLanguage.lg);
      expect(controller.t('library'), 'Layibulale');

      await controller.clearWorkspace();
      expect(controller.batch.pages, isEmpty);
    },
  );

  test('adds demo scans without platform services', () {
    final controller = ScannerController(
      scannerService: _FakeScanService(),
      exportService: _FakeExportService(Directory.systemTemp),
      compressionService: _FakeCompressionService(Directory.systemTemp),
    );

    controller.addDemoScan();

    expect(controller.batch.pages.length, 1);
    expect(controller.activePage?.title, 'Demo scan 1');
    expect(controller.activePage?.kind, DocumentKind.text);
  });
}

class _FakeScanService implements ScanCaptureService {
  @override
  Future<ScanCaptureResult> importCameraCaptures(
    List<CapturedScanImage> captures,
  ) async {
    return ScanCaptureResult(
      pages: [
        for (final capture in captures)
          ScanPage(
            id: 'camera-${capture.fileName}',
            title: capture.fileName,
            createdAt: DateTime(2026),
            source: ScanSource.camera,
            kind: DocumentKind.image,
            textPreview: 'camera capture',
            folder: 'Inbox',
            sizeBytes: capture.bytes?.length ?? 0,
          ),
      ],
    );
  }

  @override
  Future<ScanCaptureResult> importFiles() async {
    return ScanCaptureResult(
      pages: [
        ScanPage(
          id: 'imported-1',
          title: 'Imported receipt',
          createdAt: DateTime(2026),
          source: ScanSource.file,
          kind: DocumentKind.text,
          textPreview: 'receipt total 42000',
          folder: 'Inbox',
          sizeBytes: 128,
        ),
      ],
    );
  }

  @override
  Future<ScanCaptureResult> scanDocument() async => importFiles();
}

class _FakeExportService implements BatchExportService {
  _FakeExportService(this.directory);

  final Directory directory;
  final exportedBatches = <ScanBatch>[];

  @override
  Future<ExportResult> exportBatch(
    ScanBatch batch,
    ExportFormat format, {
    Directory? outputDirectory,
  }) async {
    exportedBatches.add(batch);
    final file = File(
      '${(outputDirectory ?? directory).path}${Platform.pathSeparator}export-${exportedBatches.length}-${format.name}.txt',
    );
    await file.writeAsString(
      '${batch.title}\n${batch.pages.length}\n${batch.exportSettings.imageQuality}',
    );
    return ExportResult(
      outputPath: file.path,
      format: format,
      sizeBytes: await file.length(),
    );
  }
}

class _FakeCompressionService implements CompressionService {
  const _FakeCompressionService(this.directory);

  final Directory directory;

  @override
  Future<CompressionResult> compressFolder({
    required CompressionPreset preset,
  }) => compressSelectedFiles(preset: preset);

  @override
  Future<CompressionResult> compressPaths(
    List<String> paths, {
    required CompressionPreset preset,
    Directory? outputDirectory,
  }) async {
    final file = File(
      '${(outputDirectory ?? directory).path}${Platform.pathSeparator}compressed.zip',
    );
    await file.writeAsString('compressed');
    return CompressionResult(
      outputPath: file.path,
      originalBytes: 100,
      compressedBytes: 50,
      items: 1,
    );
  }

  @override
  Future<CompressionResult> compressSelectedFiles({
    required CompressionPreset preset,
  }) {
    return compressPaths(const [], preset: preset);
  }
}
