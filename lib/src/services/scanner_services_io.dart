import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as image_tools;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/scan_models.dart';

abstract class ScanCaptureService {
  Future<ScanCaptureResult> scanDocument();

  Future<ScanCaptureResult> importFiles({DocumentKind? sourceKind});

  Future<ScanCaptureResult> importCameraCaptures(
    List<CapturedScanImage> captures,
  );
}

abstract class BatchExportService {
  Future<ExportResult> exportBatch(
    ScanBatch batch,
    ExportFormat format, {
    Directory? outputDirectory,
  });
}

abstract class CompressionService {
  Future<CompressionResult> compressSelectedFiles({
    required CompressionPreset preset,
  });

  Future<CompressionResult> compressFolder({required CompressionPreset preset});

  Future<CompressionResult> compressPaths(
    List<String> paths, {
    required CompressionPreset preset,
    Directory? outputDirectory,
  });
}

class ScanCaptureResult {
  const ScanCaptureResult({required this.pages});

  final List<ScanPage> pages;
}

class CapturedScanImage {
  const CapturedScanImage({
    required this.fileName,
    this.path,
    this.bytes,
    this.mimeType = 'image/jpeg',
  });

  final String fileName;
  final String? path;
  final Uint8List? bytes;
  final String mimeType;
}

class ExportResult {
  const ExportResult({
    required this.outputPath,
    required this.format,
    required this.sizeBytes,
  });

  final String outputPath;
  final ExportFormat format;
  final int sizeBytes;
}

class CompressionResult {
  const CompressionResult({
    required this.outputPath,
    required this.originalBytes,
    required this.compressedBytes,
    required this.items,
    this.kind = CompressionKind.file,
    this.method = 'archive',
    this.qualityPreserved = true,
    this.videoItems = 0,
  });

  final String outputPath;
  final int originalBytes;
  final int compressedBytes;
  final int items;
  final CompressionKind kind;
  final String method;
  final bool qualityPreserved;
  final int videoItems;

  double get savingsRatio {
    if (originalBytes <= 0) {
      return 0;
    }

    return (originalBytes - compressedBytes).clamp(0, originalBytes) /
        originalBytes;
  }
}

class ImageProcessResult {
  const ImageProcessResult({
    required this.outputPath,
    required this.width,
    required this.height,
    required this.sizeBytes,
  });

  final String outputPath;
  final int width;
  final int height;
  final int sizeBytes;
}

class FileIntakeService {
  const FileIntakeService();

  static const imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp',
    'gif',
    'heic',
  };
  static const videoExtensions = {
    'mp4',
    'mov',
    'm4v',
    'webm',
    'mkv',
    'avi',
    '3gp',
    '3g2',
    'flv',
    'wmv',
    'mpg',
    'mpeg',
    'ts',
    'mts',
    'm2ts',
  };
  static const archiveExtensions = {'zip', 'gz', 'rar', '7z'};

  DocumentKind classifyPath(String path, {String mimeType = ''}) {
    final extension = _extension(path);
    final type = mimeType.toLowerCase();

    if (type.startsWith('image/') || imageExtensions.contains(extension)) {
      return DocumentKind.image;
    }
    if (type.startsWith('video/') || videoExtensions.contains(extension)) {
      return DocumentKind.video;
    }
    if (type == 'application/pdf' || extension == 'pdf') {
      return DocumentKind.pdf;
    }
    if ({'doc', 'docx', 'rtf'}.contains(extension) ||
        type == 'application/msword' ||
        type ==
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
      return DocumentKind.word;
    }
    if ({'csv', 'xls', 'xlsx'}.contains(extension) ||
        type == 'text/csv' ||
        type == 'application/vnd.ms-excel' ||
        type ==
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') {
      return DocumentKind.spreadsheet;
    }
    if ({'ppt', 'pptx'}.contains(extension) ||
        type == 'application/vnd.ms-powerpoint' ||
        type ==
            'application/vnd.openxmlformats-officedocument.presentationml.presentation') {
      return DocumentKind.presentation;
    }
    if ({'txt', 'md'}.contains(extension) || type.startsWith('text/')) {
      return DocumentKind.text;
    }
    if (archiveExtensions.contains(extension)) {
      return DocumentKind.archive;
    }

    return DocumentKind.unknown;
  }

  bool canRenderAsScan(DocumentKind kind) {
    return kind == DocumentKind.image ||
        kind == DocumentKind.text ||
        kind == DocumentKind.word;
  }

  Future<ScanPage> createPageFromPath(
    String path, {
    String? displayName,
    String mimeType = '',
    String folder = 'Inbox',
    bool runOcr = false,
    ScanSource source = ScanSource.file,
  }) async {
    final file = File(path);
    final exists = await file.exists();
    final name = displayName ?? _fileName(path);
    final kind = classifyPath(name, mimeType: mimeType);
    final text = exists ? await extractText(path, kind) : '';
    final imageSize = exists && kind == DocumentKind.image
        ? await _imageSize(path)
        : (width: 0, height: 0);
    final ocrText = runOcr && exists && kind == DocumentKind.image
        ? await recognizeText(path)
        : '';

    return ScanPage(
      id: _createId(),
      title: nameFromFile(name),
      createdAt: DateTime.now(),
      source: source,
      kind: kind,
      localPath: path,
      fileName: name,
      mimeType: mimeType,
      folder: folder,
      textPreview: text,
      ocrText: ocrText,
      tags: [documentKindLabel(kind).toLowerCase(), 'import'],
      sizeBytes: exists ? await file.length() : 0,
      width: imageSize.width,
      height: imageSize.height,
    );
  }

  Future<String> extractText(String path, DocumentKind kind) async {
    return switch (kind) {
      DocumentKind.pdf => _extractPdfText(path),
      DocumentKind.text => _readPlainText(path),
      DocumentKind.word => _extractWordText(path),
      DocumentKind.spreadsheet => _extractSpreadsheetText(path),
      DocumentKind.presentation => _extractPresentationText(path),
      _ => '',
    };
  }

  String nameFromFile(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    return base.trim().isEmpty ? 'Untitled file' : base.trim();
  }

  Future<String> _readPlainText(String path) async {
    try {
      return _cleanText(await File(path).readAsString());
    } catch (_) {
      return '';
    }
  }

  Future<String> _extractPdfText(String path) async {
    try {
      final raw = latin1.decode(await File(path).readAsBytes());
      final strings = RegExp(r'\((?:\\.|[^\\)])*\)')
          .allMatches(raw)
          .map((match) => _decodePdfString(match.group(0) ?? ''))
          .where((value) => value.trim().length > 1)
          .toList();
      return _cleanText(strings.join('\n'));
    } catch (_) {
      return '';
    }
  }

  Future<String> _extractWordText(String path) async {
    final extension = _extension(path);
    if (extension == 'txt' || extension == 'md' || extension == 'rtf') {
      return _readPlainText(path);
    }
    if (extension != 'docx') {
      return '';
    }

    final archive = _openZip(path);
    final xml = _archiveText(archive, 'word/document.xml');
    return _cleanOfficeXml(xml);
  }

  Future<String> _extractSpreadsheetText(String path) async {
    final extension = _extension(path);
    if (extension == 'csv') {
      return _readPlainText(path);
    }
    if (extension != 'xlsx') {
      return '';
    }

    final archive = _openZip(path);
    final sharedStrings = _extractSharedStrings(archive);
    final buffers = <String>[];

    for (final file in archive.files.where(
      (file) => RegExp(r'xl/worksheets/sheet\d+\.xml$').hasMatch(file.name),
    )) {
      final xml = utf8.decode(file.content, allowMalformed: true);
      buffers.addAll(_extractWorksheetRows(xml, sharedStrings));
    }

    return _cleanText(
      buffers.where((value) => value.trim().isNotEmpty).join('\n'),
    );
  }

  Future<String> _extractPresentationText(String path) async {
    if (_extension(path) != 'pptx') {
      return '';
    }

    final archive = _openZip(path);
    final slides =
        archive.files
            .where(
              (file) =>
                  RegExp(r'ppt/slides/slide\d+\.xml$').hasMatch(file.name),
            )
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));

    return _cleanText(
      slides
          .asMap()
          .entries
          .map((entry) {
            final xml = utf8.decode(entry.value.content, allowMalformed: true);
            return 'Slide ${entry.key + 1}\n${_cleanOfficeXml(xml)}';
          })
          .join('\n\n'),
    );
  }

  Archive _openZip(String path) {
    try {
      return ZipDecoder().decodeBytes(File(path).readAsBytesSync());
    } catch (_) {
      return Archive();
    }
  }

  String _archiveText(Archive archive, String name) {
    final match = archive.files.where((file) => file.name == name).firstOrNull;
    return match == null
        ? ''
        : utf8.decode(match.content, allowMalformed: true);
  }

  List<String> _extractSharedStrings(Archive archive) {
    final xml = _archiveText(archive, 'xl/sharedStrings.xml');
    return RegExp(
      r'<t[^>]*>(.*?)</t>',
      dotAll: true,
    ).allMatches(xml).map((match) => _decodeXml(match.group(1) ?? '')).toList();
  }

  List<String> _extractWorksheetRows(String xml, List<String> sharedStrings) {
    final rows = <String>[];

    for (final rowMatch in RegExp(
      r'<row\b[^>]*>(.*?)</row>',
      dotAll: true,
    ).allMatches(xml)) {
      final rowXml = rowMatch.group(1) ?? '';
      final values = <String>[];

      for (final cellMatch in RegExp(
        r'<c\b([^>]*)>(.*?)</c>',
        dotAll: true,
      ).allMatches(rowXml)) {
        final attributes = cellMatch.group(1) ?? '';
        final cellXml = cellMatch.group(2) ?? '';
        final cellRef = RegExp(
          r'\br="([A-Z]+)\d+"',
        ).firstMatch(attributes)?.group(1);
        final columnIndex = _columnIndexFromCellRef(cellRef);
        while (columnIndex != null && values.length < columnIndex) {
          values.add('');
        }
        values.add(_spreadsheetCellValue(attributes, cellXml, sharedStrings));
      }

      final line = values.join('\t').replaceFirst(RegExp(r'\t+$'), '');
      if (line.trim().isNotEmpty) {
        rows.add(line);
      }
    }

    return rows;
  }

  String _spreadsheetCellValue(
    String attributes,
    String cellXml,
    List<String> sharedStrings,
  ) {
    if (attributes.contains('t="inlineStr"')) {
      return _cleanText(_textFromXmlTextNodes(cellXml));
    }

    final raw = _firstTagContent(cellXml, 'v');
    if (raw.isEmpty) {
      return _cleanText(_textFromXmlTextNodes(cellXml));
    }

    if (attributes.contains('t="s"')) {
      final index = int.tryParse(raw);
      if (index != null && index < sharedStrings.length) {
        return sharedStrings[index];
      }
    }

    return _decodeXml(raw);
  }

  String _textFromXmlTextNodes(String xml) {
    return RegExp(
      r'<t[^>]*>(.*?)</t>',
      dotAll: true,
    ).allMatches(xml).map((match) => _decodeXml(match.group(1) ?? '')).join();
  }

  String _firstTagContent(String xml, String tag) {
    return RegExp(
          '<$tag[^>]*>(.*?)</$tag>',
          dotAll: true,
        ).firstMatch(xml)?.group(1)?.trim() ??
        '';
  }

  int? _columnIndexFromCellRef(String? letters) {
    if (letters == null || letters.isEmpty) {
      return null;
    }

    var index = 0;
    for (final codeUnit in letters.codeUnits) {
      index = index * 26 + codeUnit - 64;
    }
    return index - 1;
  }
}

class ImageProcessingService {
  const ImageProcessingService();

  Future<ImageProcessResult> processImageFile(
    String inputPath, {
    Directory? outputDirectory,
    CropRect? crop,
    List<PerspectivePoint> perspective = const [],
    int rotation = 0,
    ScanFilter filter = ScanFilter.auto,
    ScanQualitySettings quality = const ScanQualitySettings(),
    double imageQuality = 0.96,
    int? maxSide,
  }) async {
    final input = File(inputPath);
    final decoded = image_tools.decodeImage(await input.readAsBytes());
    if (decoded == null) {
      throw ArgumentError('Unsupported image: $inputPath');
    }

    var edited = _applyCropOrPerspective(decoded, crop, perspective);

    if (rotation % 360 != 0) {
      edited = image_tools.copyRotate(edited, angle: rotation);
    }

    if (maxSide != null && math.max(edited.width, edited.height) > maxSide) {
      final scale = maxSide / math.max(edited.width, edited.height);
      edited = image_tools.copyResize(
        edited,
        width: math.max(1, (edited.width * scale).round()),
        height: math.max(1, (edited.height * scale).round()),
      );
    }

    edited = _applyFilter(edited, filter, quality);
    final bytes = image_tools.encodeJpg(
      edited,
      quality: (imageQuality.clamp(0.1, 1.0) * 100).round(),
    );
    final output = await _writeOutputFile(
      'scan-${_createId()}.jpg',
      bytes,
      directory: outputDirectory,
    );

    return ImageProcessResult(
      outputPath: output.path,
      width: edited.width,
      height: edited.height,
      sizeBytes: await output.length(),
    );
  }

  Future<CropRect?> detectDocumentBounds(String path) async {
    final decoded = image_tools.decodeImage(await File(path).readAsBytes());
    if (decoded == null) {
      return null;
    }

    final padX = (decoded.width * 0.06).round();
    final padY = (decoded.height * 0.06).round();
    if (decoded.width < 40 || decoded.height < 40) {
      return null;
    }

    return CropRect(
      x: padX,
      y: padY,
      width: decoded.width - padX * 2,
      height: decoded.height - padY * 2,
    );
  }

  image_tools.Image _applyCropOrPerspective(
    image_tools.Image source,
    CropRect? crop,
    List<PerspectivePoint> perspective,
  ) {
    if (perspective.length == 4) {
      final minX = perspective.map((point) => point.x).reduce(math.min).round();
      final minY = perspective.map((point) => point.y).reduce(math.min).round();
      final maxX = perspective.map((point) => point.x).reduce(math.max).round();
      final maxY = perspective.map((point) => point.y).reduce(math.max).round();
      return image_tools.copyCrop(
        source,
        x: minX,
        y: minY,
        width: math.max(1, maxX - minX),
        height: math.max(1, maxY - minY),
      );
    }

    if (crop == null) {
      return image_tools.Image.from(source);
    }

    return image_tools.copyCrop(
      source,
      x: crop.x,
      y: crop.y,
      width: crop.width,
      height: crop.height,
    );
  }

  image_tools.Image _applyFilter(
    image_tools.Image source,
    ScanFilter filter,
    ScanQualitySettings quality,
  ) {
    var edited = image_tools.adjustColor(
      source,
      brightness: (1 + quality.brightness / 100).clamp(0.2, 2.0),
      contrast: quality.contrast.clamp(0.2, 2.0),
      saturation:
          filter == ScanFilter.grayscale || filter == ScanFilter.blackAndWhite
          ? 0
          : 1.08,
    );

    if (filter == ScanFilter.grayscale) {
      edited = image_tools.grayscale(edited);
    }

    if (filter == ScanFilter.blackAndWhite) {
      edited = image_tools.grayscale(edited);
      edited = image_tools.adjustColor(
        edited,
        contrast: 1.75,
        brightness: 1.08,
      );
    }

    return edited;
  }
}

class NativeScannerService implements ScanCaptureService {
  NativeScannerService({
    FileIntakeService fileIntakeService = const FileIntakeService(),
  }) : _fileIntakeService = fileIntakeService;

  final FileIntakeService _fileIntakeService;

  @override
  Future<ScanCaptureResult> scanDocument() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg, DocumentFormat.pdf},
        isGalleryImport: true,
        mode: ScannerMode.full,
        pageLimit: 50,
      ),
    );

    try {
      final result = await scanner.scanDocument();
      final images = result.images ?? const <String>[];
      final pages = <ScanPage>[];

      for (final imagePath in images) {
        final path = _normalizePath(imagePath);
        final page = await _fileIntakeService.createPageFromPath(
          path,
          displayName: 'Scan ${pages.length + 1}.jpg',
          mimeType: 'image/jpeg',
          runOcr: true,
          source: ScanSource.camera,
        );
        pages.add(page.copyWith(tags: const ['camera', 'document', 'ocr']));
      }

      final pdf = result.pdf;
      if (pages.isEmpty && pdf != null) {
        final path = _normalizePath(pdf.uri);
        pages.add(
          await _fileIntakeService.createPageFromPath(
            path,
            displayName: 'Scanned PDF.pdf',
            mimeType: 'application/pdf',
            source: ScanSource.camera,
          ),
        );
      }

      return ScanCaptureResult(pages: pages);
    } finally {
      await scanner.close();
    }
  }

  @override
  Future<ScanCaptureResult> importCameraCaptures(
    List<CapturedScanImage> captures,
  ) async {
    final pages = <ScanPage>[];

    for (final capture in captures) {
      final path = capture.path;
      if (path == null || path.trim().isEmpty) {
        continue;
      }

      final page = await _fileIntakeService.createPageFromPath(
        _normalizePath(path),
        displayName: capture.fileName,
        mimeType: capture.mimeType,
        runOcr: true,
        source: ScanSource.camera,
      );
      pages.add(page.copyWith(tags: const ['camera', 'fullscreen', 'ocr']));
    }

    return ScanCaptureResult(pages: pages);
  }

  @override
  Future<ScanCaptureResult> importFiles({DocumentKind? sourceKind}) async {
    final pickerType = _pickerType(sourceKind);
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: pickerType,
      allowedExtensions: pickerType == FileType.custom
          ? _pickerExtensions(sourceKind)
          : null,
      withData: false,
    );

    if (result == null) {
      return const ScanCaptureResult(pages: []);
    }

    final pages = <ScanPage>[];

    for (final pickedFile in result.files) {
      final path = pickedFile.path;
      if (path == null) {
        continue;
      }

      final kind = _fileIntakeService.classifyPath(
        pickedFile.name,
        mimeType: pickedFile.extension ?? '',
      );
      if (sourceKind != null && kind != sourceKind) {
        continue;
      }

      pages.add(
        await _fileIntakeService.createPageFromPath(
          path,
          displayName: pickedFile.name,
          mimeType: pickedFile.extension ?? '',
          runOcr: kind == DocumentKind.image,
        ),
      );
    }

    return ScanCaptureResult(pages: pages);
  }

  FileType _pickerType(DocumentKind? sourceKind) {
    return switch (sourceKind) {
      DocumentKind.image => FileType.image,
      DocumentKind.pdf ||
      DocumentKind.word ||
      DocumentKind.spreadsheet ||
      DocumentKind.presentation ||
      DocumentKind.text => FileType.custom,
      _ => FileType.any,
    };
  }

  List<String>? _pickerExtensions(DocumentKind? sourceKind) {
    return switch (sourceKind) {
      DocumentKind.pdf => const ['pdf'],
      DocumentKind.word => const ['doc', 'docx', 'rtf'],
      DocumentKind.spreadsheet => const ['csv', 'xls', 'xlsx'],
      DocumentKind.presentation => const ['ppt', 'pptx'],
      DocumentKind.text => const ['txt', 'md'],
      _ => null,
    };
  }
}

class DocumentExportService implements BatchExportService {
  const DocumentExportService();

  @override
  Future<ExportResult> exportBatch(
    ScanBatch batch,
    ExportFormat format, {
    Directory? outputDirectory,
  }) async {
    if (format != ExportFormat.json && batch.pages.isEmpty) {
      throw StateError('There are no scans to export');
    }

    return switch (format) {
      ExportFormat.pdf => _exportPdf(batch, outputDirectory),
      ExportFormat.jpg => _exportJpg(batch, outputDirectory),
      ExportFormat.text => _exportText(batch, outputDirectory),
      ExportFormat.word => _exportOfficeHtml(
        batch,
        format,
        'doc',
        outputDirectory,
      ),
      ExportFormat.excel => _exportOfficeHtml(
        batch,
        format,
        'xls',
        outputDirectory,
      ),
      ExportFormat.powerPoint => _exportOfficeHtml(
        batch,
        format,
        'ppt',
        outputDirectory,
      ),
      ExportFormat.zip => _exportZip(batch, 'pages', outputDirectory),
      ExportFormat.json => _exportJson(batch, outputDirectory),
    };
  }

  int estimateExportSize(ScanBatch batch) {
    final imageBytes = batch.pages.fold<int>(
      0,
      (total, page) => total + page.sizeBytes,
    );
    final textBytes = batch.pages.fold<int>(0, (total, page) {
      return total +
          (page.ocrText.length + page.textPreview.length + page.notes.length) *
              2;
    });
    return (imageBytes * batch.exportSettings.imageQuality +
            textBytes +
            batch.pages.length * 500)
        .round();
  }

  Future<ExportResult> _exportPdf(
    ScanBatch batch,
    Directory? outputDirectory,
  ) async {
    final document = pw.Document(title: batch.title);
    final pageFormat = _pdfPageFormat(batch.exportSettings.pageSize);

    for (final page in batch.pages) {
      final file = page.bestPath == null ? null : File(page.bestPath!);
      final hasImage =
          file != null && await file.exists() && _isImagePath(file.path);
      final imageBytes = hasImage
          ? _preparePdfImageBytes(
              await file.readAsBytes(),
              batch.exportSettings,
            )
          : null;
      final text = _pageText(page);

      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            final children = <pw.Widget>[
              pw.Text(
                page.title,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
            ];

            if (imageBytes != null) {
              children.add(
                pw.Expanded(
                  child: pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(imageBytes),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              );
            } else if (batch.exportSettings.includeAttachmentPages) {
              children.add(
                pw.Text(
                  '${documentKindLabel(page.kind)} attachment: ${page.fileName}',
                ),
              );
            }

            if (batch.exportSettings.includeTextLayer && text.isNotEmpty) {
              children
                ..add(pw.SizedBox(height: 10))
                ..add(_pdfTextBlock(text));
            }

            return _pdfWatermarkedPage(children);
          },
        ),
      );
    }

    final output = await _writeOutputFile(
      '${_safeName(batch.title)}.pdf',
      await document.save(),
      directory: outputDirectory,
    );
    return _result(output, ExportFormat.pdf);
  }

  Future<ExportResult> _exportText(
    ScanBatch batch,
    Directory? outputDirectory,
  ) async {
    final buffer = StringBuffer();
    for (final page in batch.pages) {
      buffer
        ..writeln(page.title)
        ..writeln(
          _pageText(page).isEmpty
              ? 'No extracted text available.'
              : _pageText(page),
        )
        ..writeln();
    }

    final output = await _writeOutputFile(
      '${_safeName(batch.title)}.txt',
      utf8.encode(buffer.toString()),
      directory: outputDirectory,
    );
    return _result(output, ExportFormat.text);
  }

  Future<ExportResult> _exportJpg(
    ScanBatch batch,
    Directory? outputDirectory,
  ) async {
    if (batch.pages.length != 1) {
      return _exportZip(
        batch,
        'images',
        outputDirectory,
        resultFormat: ExportFormat.jpg,
      );
    }

    final page = batch.pages.single;
    final path = page.bestPath;
    final file = path == null ? null : File(path);
    if (file == null || !await file.exists() || !_isImagePath(file.path)) {
      return _exportZip(
        batch,
        'images',
        outputDirectory,
        resultFormat: ExportFormat.jpg,
      );
    }

    final output = await _writeOutputFile(
      '${_safeName(page.title)}.jpg',
      _prepareJpegImageBytes(await file.readAsBytes(), batch.exportSettings),
      directory: outputDirectory,
    );
    return _result(output, ExportFormat.jpg);
  }

  Future<ExportResult> _exportOfficeHtml(
    ScanBatch batch,
    ExportFormat format,
    String extension,
    Directory? outputDirectory,
  ) async {
    final sections = <String>[];
    for (final entry in batch.pages.asMap().entries) {
      final page = entry.value;
      final index = entry.key + 1;
      final text = _escapeHtml(_pageText(page));
      final media = await _officeMediaMarkup(page);
      final meta = _escapeHtml(
        '${documentKindLabel(page.kind)} | ${page.folder} | ${page.tags.join(', ')}',
      );

      if (format == ExportFormat.excel) {
        sections.add(
          '<tr><td>$index</td><td>${_escapeHtml(page.title)}</td><td>${_escapeHtml(documentKindLabel(page.kind))}</td><td>${_escapeHtml(page.folder)}</td><td>${_escapeHtml(page.tags.join(', '))}</td><td>$media<div class="document-text">$text</div></td></tr>',
        );
        continue;
      }

      if (format == ExportFormat.powerPoint) {
        sections.add(
          '<section class="slide"><h2>$index. ${_escapeHtml(page.title)}</h2><p>$meta</p>$media<div class="document-text">$text</div></section>',
        );
        continue;
      }

      sections.add(
        '<section class="page"><h2>$index. ${_escapeHtml(page.title)}</h2><p>$meta</p>$media<div class="document-text">$text</div></section>',
      );
    }

    final rows = sections.join('\n');

    final body = format == ExportFormat.excel
        ? '<table><thead><tr><th>#</th><th>Name</th><th>Type</th><th>Folder</th><th>Tags</th><th>Text</th></tr></thead><tbody>$rows</tbody></table>'
        : rows;
    final html =
        '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>${_escapeHtml(batch.title)}</title>
  <style>
    body { font-family: Arial, sans-serif; color: #17231f; position: relative; }
    body::before { content: "SapScanner"; position: fixed; top: 45%; left: 50%; transform: translate(-50%, -50%) rotate(-24deg); font-size: 78px; font-weight: 800; color: rgba(16, 16, 16, 0.055); pointer-events: none; z-index: 0; }
    body > * { position: relative; z-index: 1; }
    .document-text { white-space: pre-wrap; line-height: 1.5; overflow-wrap: break-word; }
    .page-image { display: block; max-width: 100%; max-height: 620px; object-fit: contain; margin: 12px 0 16px; }
    .slide .page-image { max-height: 360px; }
    table { border-collapse: collapse; width: 100%; table-layout: fixed; }
    th, td { border: 1px solid #cad1ce; padding: 8px; vertical-align: top; }
    th { background: #101010; color: #fff; }
    .page { page-break-after: always; margin-bottom: 24px; position: relative; }
    .slide { width: 960px; min-height: 540px; page-break-after: always; padding: 34px; box-sizing: border-box; position: relative; }
  </style>
</head>
<body>
  <h1>${_escapeHtml(batch.title)}</h1>
  $body
</body>
</html>
''';

    final output = await _writeOutputFile(
      '${_safeName(batch.title)}.$extension',
      utf8.encode('\ufeff$html'),
      directory: outputDirectory,
    );
    return _result(output, format);
  }

  Future<ExportResult> _exportZip(
    ScanBatch batch,
    String suffix,
    Directory? outputDirectory, {
    ExportFormat resultFormat = ExportFormat.zip,
  }) async {
    final archive = Archive();

    for (final page in batch.pages) {
      final path = page.bestPath;
      final file = path == null ? null : File(path);

      if (file != null && await file.exists()) {
        final bytes = await file.readAsBytes();
        archive.addFile(
          ArchiveFile(
            '${_safeName(page.title)}.${_extension(file.path)}',
            bytes.length,
            bytes,
          ),
        );
      } else {
        final text = utf8.encode(_pageText(page));
        archive.addFile(
          ArchiveFile('${_safeName(page.title)}.txt', text.length, text),
        );
      }
    }

    final bytes = ZipEncoder().encode(archive, level: 9);
    final output = await _writeOutputFile(
      '${_safeName(batch.title)}-$suffix.zip',
      bytes,
      directory: outputDirectory,
    );
    return _result(output, resultFormat);
  }

  Future<ExportResult> _exportJson(
    ScanBatch batch,
    Directory? outputDirectory,
  ) async {
    const encoder = JsonEncoder.withIndent('  ');
    final output = await _writeOutputFile(
      '${_safeName(batch.title)}-workspace.json',
      utf8.encode(encoder.convert(batch.toJson())),
      directory: outputDirectory,
    );
    return _result(output, ExportFormat.json);
  }

  Future<ExportResult> _result(File file, ExportFormat format) async {
    return ExportResult(
      outputPath: file.path,
      format: format,
      sizeBytes: await file.length(),
    );
  }
}

class NativeCompressionService implements CompressionService {
  NativeCompressionService({
    ImageProcessingService imageProcessingService =
        const ImageProcessingService(),
  }) : _imageProcessingService = imageProcessingService;

  final ImageProcessingService _imageProcessingService;

  @override
  Future<CompressionResult> compressSelectedFiles({
    required CompressionPreset preset,
  }) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: false,
    );

    if (result == null) {
      return const CompressionResult(
        outputPath: '',
        originalBytes: 0,
        compressedBytes: 0,
        items: 0,
      );
    }

    final paths = result.files
        .map((file) => file.path)
        .whereType<String>()
        .toList();
    return compressPaths(paths, preset: preset);
  }

  @override
  Future<CompressionResult> compressFolder({
    required CompressionPreset preset,
  }) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose folder to compress',
    );
    if (path == null) {
      return const CompressionResult(
        outputPath: '',
        originalBytes: 0,
        compressedBytes: 0,
        items: 0,
        kind: CompressionKind.folder,
      );
    }

    return compressPaths([path], preset: preset);
  }

  @override
  Future<CompressionResult> compressPaths(
    List<String> paths, {
    required CompressionPreset preset,
    Directory? outputDirectory,
  }) async {
    final entries = await _expandFiles(paths);
    final files = entries.map((entry) => entry.file).toList();
    if (files.isEmpty) {
      return const CompressionResult(
        outputPath: '',
        originalBytes: 0,
        compressedBytes: 0,
        items: 0,
      );
    }

    final originalBytes = await _sumFiles(files);
    final allImages = files.every((file) => _isImagePath(file.path));
    final intakeService = const FileIntakeService();
    final videoItems = files
        .where(
          (file) => intakeService.classifyPath(file.path) == DocumentKind.video,
        )
        .length;
    final hasVideo = videoItems > 0;
    final hasFolder = paths.any(
      (path) =>
          FileSystemEntity.typeSync(path) == FileSystemEntityType.directory,
    );
    final kinds = files
        .map((file) => intakeService.classifyPath(file.path))
        .toSet();
    final hasMixedKinds = kinds.length > 1;

    if (allImages && files.length == 1) {
      final compressed = await _imageProcessingService.processImageFile(
        files.single.path,
        outputDirectory: outputDirectory,
        imageQuality: preset.imageQuality,
        maxSide: preset.maxImageSide,
      );
      final original = await files.single.length();
      final bestOutput = compressed.sizeBytes < original
          ? File(compressed.outputPath)
          : files.single;
      return CompressionResult(
        outputPath: bestOutput.path,
        originalBytes: original,
        compressedBytes: await bestOutput.length(),
        items: 1,
        kind: CompressionKind.photo,
        method: compressed.sizeBytes < original
            ? 'photo-resize'
            : 'original-photo-kept',
        qualityPreserved: bestOutput.path == files.single.path,
      );
    }

    final archive = Archive();
    for (final entry in entries) {
      final file = entry.file;
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(entry.archiveName, bytes.length, bytes));
    }

    final bytes = ZipEncoder().encode(
      archive,
      level: preset.archiveLevel.clamp(0, 9).toInt(),
    );
    final output = await _writeOutputFile(
      _compressionOutputName(
        hasVideo: hasVideo,
        hasFolder: hasFolder,
        hasMixedKinds: hasMixedKinds,
      ),
      bytes,
      directory: outputDirectory,
    );

    return CompressionResult(
      outputPath: output.path,
      originalBytes: originalBytes,
      compressedBytes: await output.length(),
      items: files.length,
      kind: hasFolder
          ? CompressionKind.folder
          : hasVideo && files.length == videoItems
          ? CompressionKind.video
          : hasMixedKinds
          ? CompressionKind.mixed
          : CompressionKind.file,
      method: hasVideo
          ? 'quality-preserving-video-archive'
          : hasFolder
          ? 'folder-archive'
          : 'file-archive',
      qualityPreserved: true,
      videoItems: videoItems,
    );
  }

  Future<List<_CompressionEntry>> _expandFiles(List<String> paths) async {
    final entries = <_CompressionEntry>[];

    for (final path in paths) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.file) {
        final file = File(path);
        entries.add(_CompressionEntry(file, _fileName(file.path)));
      } else if (type == FileSystemEntityType.directory) {
        final root = Directory(path);
        await for (final entity in root.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            entries.add(
              _CompressionEntry(entity, _relativeArchiveName(root, entity)),
            );
          }
        }
      }
    }

    return entries;
  }
}

class _CompressionEntry {
  const _CompressionEntry(this.file, this.archiveName);

  final File file;
  final String archiveName;
}

Future<String> recognizeText(String path) async {
  final recognizer = TextRecognizer();

  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    return result.text;
  } catch (_) {
    return '';
  } finally {
    await recognizer.close();
  }
}

Future<File> _writeOutputFile(
  String fileName,
  List<int> bytes, {
  Directory? directory,
}) async {
  final outputDirectory = directory ?? await getApplicationDocumentsDirectory();
  if (!await outputDirectory.exists()) {
    await outputDirectory.create(recursive: true);
  }

  final file = File(
    '${outputDirectory.path}${Platform.pathSeparator}$fileName',
  );
  return file.writeAsBytes(bytes, flush: true);
}

Future<({int width, int height})> _imageSize(String path) async {
  try {
    final decoded = image_tools.decodeImage(await File(path).readAsBytes());
    return (width: decoded?.width ?? 0, height: decoded?.height ?? 0);
  } catch (_) {
    return (width: 0, height: 0);
  }
}

Future<int> _sumFiles(List<File> files) async {
  var total = 0;
  for (final file in files) {
    total += await file.length();
  }
  return total;
}

PdfPageFormat _pdfPageFormat(PageSize pageSize) {
  return switch (pageSize) {
    PageSize.a4 => PdfPageFormat.a4,
    PageSize.letter => PdfPageFormat.letter,
    PageSize.legal => PdfPageFormat.legal,
  };
}

String _pageText(ScanPage page) {
  return [
    page.ocrText,
    page.textPreview,
    page.notes,
  ].where((value) => value.trim().isNotEmpty).join('\n\n').trim();
}

pw.Widget _pdfTextBlock(String text) {
  return pw.Text(text, style: const pw.TextStyle(fontSize: 10.5));
}

pw.Widget _pdfWatermarkedPage(List<pw.Widget> children) {
  return pw.Stack(
    children: [
      pw.Positioned(
        left: 0,
        right: 0,
        top: 0,
        bottom: 0,
        child: pw.Center(
          child: pw.Transform.rotate(
            angle: -0.42,
            child: pw.Opacity(
              opacity: 0.08,
              child: pw.Text(
                'SapScanner',
                style: pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 72,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      ),
    ],
  );
}

Uint8List _preparePdfImageBytes(List<int> source, ExportSettings settings) {
  final original = Uint8List.fromList(source);
  final decoded = image_tools.decodeImage(original);
  if (decoded == null) {
    return original;
  }

  var prepared = decoded;
  final maxSide = settings.imageQuality <= 0.55
      ? 1400
      : settings.imageQuality <= 0.75
      ? 2200
      : 4096;
  if (math.max(prepared.width, prepared.height) > maxSide) {
    final scale = maxSide / math.max(prepared.width, prepared.height);
    prepared = image_tools.copyResize(
      prepared,
      width: math.max(1, (prepared.width * scale).round()),
      height: math.max(1, (prepared.height * scale).round()),
    );
  }

  final encoded = Uint8List.fromList(
    image_tools.encodeJpg(prepared, quality: settings.jpegQuality),
  );
  if (settings.imageQuality >= 0.85 && encoded.length > original.length) {
    return original;
  }

  return encoded;
}

Uint8List _prepareJpegImageBytes(List<int> source, ExportSettings settings) {
  final original = Uint8List.fromList(source);
  final decoded = image_tools.decodeImage(original);
  if (decoded == null) {
    return original;
  }

  return Uint8List.fromList(
    image_tools.encodeJpg(decoded, quality: settings.jpegQuality),
  );
}

String _safeName(String value) {
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]+'), '-')
      .replaceAll(RegExp(r'\s+'), '-');
  return cleaned
          .replaceAll(RegExp(r'-+'), '-')
          .substring(0, math.min(80, cleaned.length))
          .trim()
          .isEmpty
      ? 'sapscanner'
      : cleaned
            .replaceAll(RegExp(r'-+'), '-')
            .substring(0, math.min(80, cleaned.length));
}

String _fileName(String path) {
  return path.split(RegExp(r'[\\/]')).last;
}

String _relativeArchiveName(Directory root, File file) {
  final rootPath = root.absolute.path.replaceAll(r'\', '/');
  final filePath = file.absolute.path.replaceAll(r'\', '/');
  final prefix = rootPath.endsWith('/') ? rootPath : '$rootPath/';
  final relative = filePath.startsWith(prefix)
      ? filePath.substring(prefix.length)
      : _fileName(file.path);
  final cleanParts = relative
      .split('/')
      .where((part) => part.trim().isNotEmpty)
      .map(_safeName)
      .toList();
  final rootName = _safeName(_fileName(root.path));

  return [rootName, ...cleanParts].join('/');
}

String _compressionOutputName({
  required bool hasVideo,
  required bool hasFolder,
  required bool hasMixedKinds,
}) {
  final label = hasFolder
      ? 'folder'
      : hasVideo && hasMixedKinds
      ? 'mixed-media'
      : hasVideo
      ? 'video-safe'
      : hasMixedKinds
      ? 'mixed-files'
      : 'files';

  return 'sapscanner-$label-compressed-${_createId()}.zip';
}

String _extension(String path) {
  final clean = path.split('?').first.toLowerCase();
  final index = clean.lastIndexOf('.');
  return index >= 0 ? clean.substring(index + 1) : '';
}

bool _isImagePath(String path) =>
    FileIntakeService.imageExtensions.contains(_extension(path));

Future<String> _officeMediaMarkup(ScanPage page) async {
  final path = page.bestPath;
  final file = path == null ? null : File(path);
  if (file == null || !await file.exists() || !_isImagePath(file.path)) {
    return '';
  }

  final mimeType = _imageMimeType(file.path);
  final data = base64Encode(await file.readAsBytes());
  return '<img class="page-image" src="data:$mimeType;base64,$data" alt="${_escapeHtml(page.title)}">';
}

String _imageMimeType(String path) {
  return switch (_extension(path)) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'bmp' => 'image/bmp',
    _ => 'image/jpeg',
  };
}

String _normalizePath(String uriOrPath) {
  if (uriOrPath.startsWith('file:')) {
    return Uri.parse(uriOrPath).toFilePath();
  }
  return uriOrPath;
}

String _cleanText(String value) {
  return value
      .replaceAll('\r', '')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String _cleanOfficeXml(String xml) {
  final text = xml
      .replaceAll(RegExp(r'<w:tab\s*/>'), '\t')
      .replaceAll(RegExp(r'<w:br\s*/>|<w:cr\s*/>|<a:br\s*/>'), '\n')
      .replaceAll(RegExp(r'</w:p>\s*</w:tc>'), '</w:tc>')
      .replaceAll(RegExp(r'</w:tc>'), '\t')
      .replaceAll(RegExp(r'</w:tr>'), '\n')
      .replaceAll(RegExp(r'</w:p>|</a:p>'), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  return _cleanText(_decodeXml(text));
}

String _decodeXml(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}

String _decodePdfString(String value) {
  final body = value.length >= 2 ? value.substring(1, value.length - 1) : value;
  return body
      .replaceAll(r'\(', '(')
      .replaceAll(r'\)', ')')
      .replaceAll(r'\\', '\\')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '\n')
      .replaceAll(r'\t', ' ')
      .replaceAll(r'\b', '')
      .replaceAll(r'\f', '\n');
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _createId() => DateTime.now().microsecondsSinceEpoch.toString();
