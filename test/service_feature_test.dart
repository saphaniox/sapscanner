import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_tools;
import 'package:sapscanner/src/models/scan_models.dart';
import 'package:sapscanner/src/services/i18n_service.dart';
import 'package:sapscanner/src/services/scanner_services.dart';
import 'package:sapscanner/src/services/storage_service.dart';

void main() {
  test('classifies supported document and media formats', () {
    const service = FileIntakeService();

    expect(service.classifyPath('photo.jpg'), DocumentKind.image);
    expect(service.classifyPath('report.pdf'), DocumentKind.pdf);
    expect(service.classifyPath('letter.docx'), DocumentKind.word);
    expect(service.classifyPath('sheet.xlsx'), DocumentKind.spreadsheet);
    expect(service.classifyPath('deck.pptx'), DocumentKind.presentation);
    expect(service.classifyPath('notes.txt'), DocumentKind.text);
    expect(service.classifyPath('clip.mp4'), DocumentKind.video);
    expect(service.classifyPath('camera-roll.m2ts'), DocumentKind.video);
    expect(service.classifyPath('mobile-video.3gp'), DocumentKind.video);
    expect(service.classifyPath('bundle.zip'), DocumentKind.archive);
  });

  test('extracts text from plain text and docx files', () async {
    final temp = await Directory.systemTemp.createTemp('sapscanner-intake-');
    const service = FileIntakeService();

    final textFile = File('${temp.path}${Platform.pathSeparator}notes.txt');
    await textFile.writeAsString('Hello SapScanner');
    expect(
      await service.extractText(textFile.path, DocumentKind.text),
      contains('SapScanner'),
    );

    final docxFile = File('${temp.path}${Platform.pathSeparator}letter.docx');
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'word/document.xml',
          '<w:document><w:body><w:p><w:r><w:t>Pearl office text</w:t></w:r></w:p></w:body></w:document>',
        ),
      );
    await docxFile.writeAsBytes(ZipEncoder().encode(archive));

    expect(
      await service.extractText(docxFile.path, DocumentKind.word),
      contains('Pearl office text'),
    );

    final pdfFile = File('${temp.path}${Platform.pathSeparator}simple.pdf');
    await pdfFile.writeAsBytes(
      latin1.encode('%PDF-1.4\nBT\n(SapScanner PDF text) Tj\nET\n%%EOF'),
    );
    expect(
      await service.extractText(pdfFile.path, DocumentKind.pdf),
      contains('SapScanner PDF text'),
    );
  });

  test(
    'processes images with crop, rotation, filter, and compression',
    () async {
      final temp = await Directory.systemTemp.createTemp('sapscanner-image-');
      final input = File('${temp.path}${Platform.pathSeparator}input.jpg');
      final image = image_tools.Image(width: 80, height: 60)
        ..clear(image_tools.ColorRgb8(250, 250, 250));

      for (var y = 10; y < 50; y++) {
        for (var x = 10; x < 70; x++) {
          image.setPixelRgba(x, y, 20, 120, 80, 255);
        }
      }

      await input.writeAsBytes(image_tools.encodeJpg(image, quality: 95));

      const processor = ImageProcessingService();
      final result = await processor.processImageFile(
        input.path,
        outputDirectory: temp,
        crop: const CropRect(x: 10, y: 10, width: 50, height: 30),
        rotation: 90,
        filter: ScanFilter.grayscale,
        imageQuality: 0.6,
      );

      expect(File(result.outputPath).existsSync(), isTrue);
      expect(result.width, 30);
      expect(result.height, 50);
      expect(result.sizeBytes, greaterThan(0));
    },
  );

  test('exports every supported format to local files', () async {
    final temp = await Directory.systemTemp.createTemp('sapscanner-export-');
    const service = DocumentExportService();
    final batch = _sampleBatch();

    for (final format in ExportFormat.values) {
      final result = await service.exportBatch(
        batch,
        format,
        outputDirectory: temp,
      );
      expect(result.format, format);
      expect(File(result.outputPath).existsSync(), isTrue);
      expect(result.sizeBytes, greaterThan(0));
    }
  });

  test('exports merged PDFs and lower-size compressed page PDFs', () async {
    final temp = await Directory.systemTemp.createTemp('sapscanner-pdf-');
    final imageFile = File('${temp.path}${Platform.pathSeparator}scan.jpg');
    final scanImage = image_tools.Image(width: 520, height: 520);
    for (var y = 0; y < scanImage.height; y++) {
      for (var x = 0; x < scanImage.width; x++) {
        scanImage.setPixelRgba(
          x,
          y,
          (x * 17 + y * 3) % 256,
          (x * 5 + y * 19) % 256,
          (x * 11 + y * 7) % 256,
          255,
        );
      }
    }
    await imageFile.writeAsBytes(
      image_tools.encodeJpg(scanImage, quality: 100),
    );

    const service = DocumentExportService();
    final merged = await service.exportBatch(
      _imageBatch(
        imageFile.path,
        title: 'Merged PDF',
        imageQuality: 0.96,
        pages: 2,
      ),
      ExportFormat.pdf,
      outputDirectory: temp,
    );
    final highQuality = await service.exportBatch(
      _imageBatch(
        imageFile.path,
        title: 'High quality page',
        imageQuality: 0.96,
      ),
      ExportFormat.pdf,
      outputDirectory: temp,
    );
    final compressed = await service.exportBatch(
      _imageBatch(
        imageFile.path,
        title: 'Compressed page',
        imageQuality: CompressionPreset.maximum.imageQuality,
      ),
      ExportFormat.pdf,
      outputDirectory: temp,
    );

    expect(File(merged.outputPath).existsSync(), isTrue);
    expect(File(highQuality.outputPath).existsSync(), isTrue);
    expect(File(compressed.outputPath).existsSync(), isTrue);
    expect(compressed.sizeBytes, lessThan(highQuality.sizeBytes));
  });

  test('compresses files, folders, and single images', () async {
    final temp = await Directory.systemTemp.createTemp('sapscanner-compress-');
    final file = File('${temp.path}${Platform.pathSeparator}plain.txt');
    await file.writeAsString(List.filled(120, 'SapScanner').join('\n'));

    final imageFile = File('${temp.path}${Platform.pathSeparator}photo.jpg');
    final image = image_tools.Image(width: 90, height: 90)
      ..clear(image_tools.ColorRgb8(200, 230, 210));
    await imageFile.writeAsBytes(image_tools.encodeJpg(image, quality: 95));
    final videoFile = File('${temp.path}${Platform.pathSeparator}clip.mp4');
    await videoFile.writeAsBytes(
      List<int>.generate(4096, (index) => index % 251),
    );

    final service = NativeCompressionService();
    final fileResult = await service.compressPaths(
      [file.path],
      preset: CompressionPreset.maximum,
      outputDirectory: temp,
    );
    final imageResult = await service.compressPaths(
      [imageFile.path],
      preset: CompressionPreset.maximum,
      outputDirectory: temp,
    );
    final videoResult = await service.compressPaths(
      [videoFile.path],
      preset: CompressionPreset.maximum,
      outputDirectory: temp,
    );
    final mixedResult = await service.compressPaths(
      [file.path, videoFile.path],
      preset: CompressionPreset.maximum,
      outputDirectory: temp,
    );
    final folderResult = await service.compressPaths(
      [temp.path],
      preset: CompressionPreset.balanced,
      outputDirectory: temp,
    );

    expect(File(fileResult.outputPath).existsSync(), isTrue);
    expect(File(imageResult.outputPath).existsSync(), isTrue);
    expect(File(videoResult.outputPath).existsSync(), isTrue);
    expect(File(mixedResult.outputPath).existsSync(), isTrue);
    expect(File(folderResult.outputPath).existsSync(), isTrue);
    expect(videoResult.kind, CompressionKind.video);
    expect(videoResult.videoItems, 1);
    expect(videoResult.qualityPreserved, isTrue);
    expect(videoResult.method, contains('video'));
    expect(mixedResult.kind, CompressionKind.mixed);
    expect(mixedResult.videoItems, 1);
    expect(folderResult.kind, CompressionKind.folder);
  });

  test('stores and restores workspace json', () async {
    final temp = await Directory.systemTemp.createTemp('sapscanner-storage-');
    final storage = JsonStorageService(directory: temp);
    final batch = _sampleBatch();

    await storage.saveBatch(batch);
    final loaded = await storage.loadBatch();

    expect(loaded?.pages.single.title, 'Receipt');
    expect(jsonEncode(loaded?.toJson()), contains('Receipt'));

    await storage.clearBatch();
    expect(await storage.loadBatch(), isNull);
  });

  test('translates professional navigation labels including Luganda', () {
    const i18n = I18nService();

    for (final language in AppLanguage.values) {
      for (final key in I18nService.coreKeys) {
        expect(
          i18n.hasTranslation(language, key),
          isTrue,
          reason: '${language.name} is missing $key',
        );
      }
    }

    expect(AppLanguage.values.length, 12);
    expect(i18n.t(AppLanguage.en, 'library'), 'Library');
    expect(i18n.t(AppLanguage.lg, 'library'), 'Layibulale');
    expect(i18n.t(AppLanguage.xog, 'language'), 'Olulimi');
    expect(i18n.t(AppLanguage.sw, 'compress'), 'Punguza');
    expect(i18n.t(AppLanguage.ar, 'settings'), 'الإعدادات');
  });
}

ScanBatch _imageBatch(
  String imagePath, {
  required String title,
  required double imageQuality,
  int pages = 1,
}) {
  final scanPages = [
    for (var index = 0; index < pages; index++)
      ScanPage(
        id: 'image-page-$index',
        title: 'Image page ${index + 1}',
        createdAt: DateTime(2026),
        source: ScanSource.file,
        kind: DocumentKind.image,
        localPath: imagePath,
        fileName: 'scan.jpg',
        mimeType: 'image/jpeg',
        folder: 'Inbox',
        textPreview: 'Scanned image page ${index + 1}',
        sizeBytes: File(imagePath).lengthSync(),
      ),
  ];

  return ScanBatch.empty().copyWith(
    title: title,
    pages: scanPages,
    activePageId: scanPages.first.id,
    exportSettings: ExportSettings(imageQuality: imageQuality),
  );
}

ScanBatch _sampleBatch() {
  final page = ScanPage(
    id: 'page-1',
    title: 'Receipt',
    createdAt: DateTime(2026),
    source: ScanSource.file,
    kind: DocumentKind.text,
    textPreview: 'Item,Amount\nScanner,100',
    ocrText: 'Receipt OCR',
    folder: 'Inbox',
    tags: const ['receipt', 'test'],
    sizeBytes: 2048,
  );

  return ScanBatch.empty().copyWith(
    title: 'Test export',
    pages: [page],
    activePageId: page.id,
  );
}
