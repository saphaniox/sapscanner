// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'dart:html' as html;

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as image_tools;
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
    Object? outputDirectory,
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
    Object? outputDirectory,
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

  Future<ScanPage> createPageFromPickedFile(
    PlatformFile pickedFile, {
    String folder = 'Inbox',
    bool runOcr = false,
    ScanSource source = ScanSource.file,
  }) async {
    final bytes = pickedFile.bytes ?? Uint8List(0);
    final id = _createId();
    final path = 'web://$id/${pickedFile.name}';
    final kind = classifyPath(
      pickedFile.name,
      mimeType: pickedFile.extension ?? '',
    );
    final text = await extractTextFromBytes(bytes, pickedFile.name, kind);
    final size = _imageSizeFromBytes(bytes);

    _webBytes[path] = bytes;
    _webNames[path] = pickedFile.name;

    return ScanPage(
      id: id,
      title: nameFromFile(pickedFile.name),
      createdAt: DateTime.now(),
      source: source,
      kind: kind,
      localPath: path,
      fileName: pickedFile.name,
      mimeType: pickedFile.extension ?? '',
      folder: folder,
      textPreview: text,
      ocrText: runOcr && kind == DocumentKind.image
          ? 'Browser preview import. Native OCR runs on Android.'
          : '',
      tags: [documentKindLabel(kind).toLowerCase(), 'web'],
      sizeBytes: bytes.length,
      width: size.width,
      height: size.height,
    );
  }

  Future<ScanPage> createPageFromCameraCapture(
    CapturedScanImage capture, {
    String folder = 'Inbox',
  }) async {
    final bytes = capture.bytes ?? Uint8List(0);
    final id = _createId();
    final path = 'web://camera/$id/${capture.fileName}';
    final kind = classifyPath(capture.fileName, mimeType: capture.mimeType);
    final size = _imageSizeFromBytes(bytes);

    _webBytes[path] = bytes;
    _webNames[path] = capture.fileName;

    return ScanPage(
      id: id,
      title: nameFromFile(capture.fileName),
      createdAt: DateTime.now(),
      source: ScanSource.camera,
      kind: kind,
      localPath: path,
      fileName: capture.fileName,
      mimeType: capture.mimeType,
      folder: folder,
      textPreview: '',
      ocrText: 'Browser camera capture. Native OCR runs on Android.',
      tags: const ['camera', 'fullscreen', 'web'],
      sizeBytes: bytes.length,
      width: size.width,
      height: size.height,
    );
  }

  Future<String> extractTextFromBytes(
    Uint8List bytes,
    String fileName,
    DocumentKind kind,
  ) async {
    return switch (kind) {
      DocumentKind.pdf => _extractPdfText(bytes),
      DocumentKind.text => _readPlainText(bytes),
      DocumentKind.word => _extractWordText(bytes, fileName),
      DocumentKind.spreadsheet => _extractSpreadsheetText(bytes, fileName),
      DocumentKind.presentation => _extractPresentationText(bytes, fileName),
      _ => '',
    };
  }

  String nameFromFile(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    return base.trim().isEmpty ? 'Untitled file' : base.trim();
  }

  String _readPlainText(Uint8List bytes) {
    return _cleanText(utf8.decode(bytes, allowMalformed: true));
  }

  String _extractPdfText(Uint8List bytes) {
    try {
      final raw = latin1.decode(bytes);
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

  String _extractWordText(Uint8List bytes, String fileName) {
    final extension = _extension(fileName);
    if (extension == 'txt' || extension == 'md' || extension == 'rtf') {
      return _readPlainText(bytes);
    }
    if (extension != 'docx') {
      return '';
    }

    final archive = _openZip(bytes);
    final xml = _archiveText(archive, 'word/document.xml');
    return _cleanOfficeXml(xml);
  }

  String _extractSpreadsheetText(Uint8List bytes, String fileName) {
    final extension = _extension(fileName);
    if (extension == 'csv') {
      return _readPlainText(bytes);
    }
    if (extension != 'xlsx') {
      return '';
    }

    final archive = _openZip(bytes);
    final sharedStrings = _extractSharedStrings(archive);
    final buffers = <String>[];

    for (final file in archive.files.where(
      (file) => RegExp(r'xl/worksheets/sheet\d+\.xml$').hasMatch(file.name),
    )) {
      final xml = utf8.decode(file.content, allowMalformed: true);
      final cells =
          RegExp(
                r'<c[^>]*?(?:t="s")?[^>]*>\s*<v>(.*?)</v>\s*</c>',
                dotAll: true,
              )
              .allMatches(xml)
              .map((match) {
                final raw = match.group(1) ?? '';
                final index = int.tryParse(raw);
                return index == null || index >= sharedStrings.length
                    ? raw
                    : sharedStrings[index];
              })
              .where((value) => value.trim().isNotEmpty);
      buffers.add(cells.join(', '));
    }

    return _cleanText(
      buffers.where((value) => value.trim().isNotEmpty).join('\n'),
    );
  }

  String _extractPresentationText(Uint8List bytes, String fileName) {
    if (_extension(fileName) != 'pptx') {
      return '';
    }

    final archive = _openZip(bytes);
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
}

class ImageProcessingService {
  const ImageProcessingService();

  Future<ImageProcessResult> processImageFile(
    String inputPath, {
    Object? outputDirectory,
    CropRect? crop,
    List<PerspectivePoint> perspective = const [],
    int rotation = 0,
    ScanFilter filter = ScanFilter.auto,
    ScanQualitySettings quality = const ScanQualitySettings(),
    double imageQuality = 0.86,
    int? maxSide,
  }) async {
    final bytes = _webBytes[inputPath];
    if (bytes == null) {
      throw ArgumentError('Browser image data is no longer available.');
    }

    final result = _processImageBytes(
      bytes,
      fileName: _webNames[inputPath] ?? 'scan.jpg',
      crop: crop,
      perspective: perspective,
      rotation: rotation,
      filter: filter,
      quality: quality,
      imageQuality: imageQuality,
      maxSide: maxSide,
    );
    final outputPath = _downloadBytes(
      result.fileName,
      result.bytes,
      'image/jpeg',
    );

    return ImageProcessResult(
      outputPath: outputPath,
      width: result.width,
      height: result.height,
      sizeBytes: result.bytes.length,
    );
  }

  Future<CropRect?> detectDocumentBounds(String path) async {
    final bytes = _webBytes[path];
    if (bytes == null) {
      return null;
    }

    final decoded = image_tools.decodeImage(bytes);
    if (decoded == null || decoded.width < 40 || decoded.height < 40) {
      return null;
    }

    final padX = (decoded.width * 0.06).round();
    final padY = (decoded.height * 0.06).round();
    return CropRect(
      x: padX,
      y: padY,
      width: decoded.width - padX * 2,
      height: decoded.height - padY * 2,
    );
  }
}

class NativeScannerService implements ScanCaptureService {
  NativeScannerService({
    FileIntakeService fileIntakeService = const FileIntakeService(),
  }) : _fileIntakeService = fileIntakeService;

  final FileIntakeService _fileIntakeService;

  @override
  Future<ScanCaptureResult> scanDocument() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );
    return _pagesFromPickerResult(
      result,
      source: ScanSource.gallery,
      runOcr: true,
    );
  }

  @override
  Future<ScanCaptureResult> importCameraCaptures(
    List<CapturedScanImage> captures,
  ) async {
    final pages = <ScanPage>[];

    for (final capture in captures) {
      if (capture.bytes == null) {
        continue;
      }

      pages.add(await _fileIntakeService.createPageFromCameraCapture(capture));
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
      withData: true,
    );
    return _pagesFromPickerResult(result, sourceKind: sourceKind);
  }

  Future<ScanCaptureResult> _pagesFromPickerResult(
    FilePickerResult? result, {
    ScanSource source = ScanSource.file,
    bool runOcr = false,
    DocumentKind? sourceKind,
  }) async {
    if (result == null) {
      return const ScanCaptureResult(pages: []);
    }

    final pages = <ScanPage>[];
    for (final pickedFile in result.files) {
      if (pickedFile.bytes == null) {
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
        await _fileIntakeService.createPageFromPickedFile(
          pickedFile,
          source: source,
          runOcr: runOcr || kind == DocumentKind.image,
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
    Object? outputDirectory,
  }) async {
    if (format != ExportFormat.json && batch.pages.isEmpty) {
      throw StateError('There are no scans to export');
    }

    return switch (format) {
      ExportFormat.pdf => _exportPdf(batch),
      ExportFormat.jpg => _exportJpg(batch),
      ExportFormat.text => _exportText(batch),
      ExportFormat.word => _exportOfficeHtml(batch, format, 'doc'),
      ExportFormat.excel => _exportOfficeHtml(batch, format, 'xls'),
      ExportFormat.powerPoint => _exportOfficeHtml(batch, format, 'ppt'),
      ExportFormat.zip => _exportZip(batch, 'pages', ExportFormat.zip),
      ExportFormat.json => _exportJson(batch),
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

  Future<ExportResult> _exportPdf(ScanBatch batch) async {
    final document = pw.Document(title: batch.title);
    final pageFormat = _pdfPageFormat(batch.exportSettings.pageSize);

    for (final page in batch.pages) {
      final path = page.bestPath;
      final bytes = path == null ? null : _webBytes[path];
      final hasImage =
          bytes != null && _isImagePath(_webNames[path] ?? page.fileName);
      final imageBytes = hasImage
          ? _preparePdfImageBytes(bytes, batch.exportSettings)
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
                ..add(pw.Text(text, maxLines: 16));
            }

            return _pdfWatermarkedPage(children);
          },
        ),
      );
    }

    final bytes = await document.save();
    final fileName = '${_safeName(batch.title)}.pdf';
    final outputPath = _downloadBytes(fileName, bytes, 'application/pdf');
    return ExportResult(
      outputPath: outputPath,
      format: ExportFormat.pdf,
      sizeBytes: bytes.length,
    );
  }

  Future<ExportResult> _exportText(ScanBatch batch) async {
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

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    final fileName = '${_safeName(batch.title)}.txt';
    final outputPath = _downloadBytes(fileName, bytes, 'text/plain');
    return ExportResult(
      outputPath: outputPath,
      format: ExportFormat.text,
      sizeBytes: bytes.length,
    );
  }

  Future<ExportResult> _exportJpg(ScanBatch batch) async {
    if (batch.pages.length != 1) {
      return _exportZip(batch, 'images', ExportFormat.jpg);
    }

    final page = batch.pages.single;
    final path = page.bestPath;
    final bytes = path == null ? null : _webBytes[path];
    final name = path == null
        ? page.fileName
        : _webNames[path] ?? page.fileName;
    if (bytes == null || !_isImagePath(name)) {
      return _exportZip(batch, 'images', ExportFormat.jpg);
    }

    final jpgBytes = _prepareJpegImageBytes(bytes, batch.exportSettings);
    final fileName = '${_safeName(page.title)}.jpg';
    final outputPath = _downloadBytes(fileName, jpgBytes, 'image/jpeg');
    return ExportResult(
      outputPath: outputPath,
      format: ExportFormat.jpg,
      sizeBytes: jpgBytes.length,
    );
  }

  Future<ExportResult> _exportOfficeHtml(
    ScanBatch batch,
    ExportFormat format,
    String extension,
  ) async {
    final rows = batch.pages
        .asMap()
        .entries
        .map((entry) {
          final page = entry.value;
          final index = entry.key + 1;
          final text = _escapeHtml(_pageText(page));
          final meta = _escapeHtml(
            '${documentKindLabel(page.kind)} | ${page.folder} | ${page.tags.join(', ')}',
          );

          if (format == ExportFormat.excel) {
            return '<tr><td>$index</td><td>${_escapeHtml(page.title)}</td><td>${_escapeHtml(documentKindLabel(page.kind))}</td><td>${_escapeHtml(page.folder)}</td><td>${_escapeHtml(page.tags.join(', '))}</td><td>$text</td></tr>';
          }

          if (format == ExportFormat.powerPoint) {
            return '<section class="slide"><h2>$index. ${_escapeHtml(page.title)}</h2><p>$meta</p><p>$text</p></section>';
          }

          return '<section class="page"><h2>$index. ${_escapeHtml(page.title)}</h2><p>$meta</p><div>$text</div></section>';
        })
        .join('\n');

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
    table { border-collapse: collapse; width: 100%; }
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

    final bytes = Uint8List.fromList(utf8.encode('\ufeff$html'));
    final fileName = '${_safeName(batch.title)}.$extension';
    final outputPath = _downloadBytes(fileName, bytes, _officeMimeType(format));
    return ExportResult(
      outputPath: outputPath,
      format: format,
      sizeBytes: bytes.length,
    );
  }

  String _officeMimeType(ExportFormat format) {
    return switch (format) {
      ExportFormat.word => 'application/msword',
      ExportFormat.excel => 'application/vnd.ms-excel',
      ExportFormat.powerPoint => 'application/vnd.ms-powerpoint',
      _ => 'text/html',
    };
  }

  Future<ExportResult> _exportZip(
    ScanBatch batch,
    String suffix,
    ExportFormat resultFormat,
  ) async {
    final archive = Archive();

    for (final page in batch.pages) {
      final path = page.bestPath;
      final bytes = path == null ? null : _webBytes[path];

      if (bytes != null) {
        final extension = _extension(_webNames[path] ?? page.fileName);
        archive.addFile(
          ArchiveFile(
            '${_safeName(page.title)}${extension.isEmpty ? '' : '.$extension'}',
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
    final fileName = '${_safeName(batch.title)}-$suffix.zip';
    final outputPath = _downloadBytes(fileName, bytes, 'application/zip');
    return ExportResult(
      outputPath: outputPath,
      format: resultFormat,
      sizeBytes: bytes.length,
    );
  }

  Future<ExportResult> _exportJson(ScanBatch batch) async {
    const encoder = JsonEncoder.withIndent('  ');
    final bytes = Uint8List.fromList(
      utf8.encode(encoder.convert(batch.toJson())),
    );
    final fileName = '${_safeName(batch.title)}-workspace.json';
    final outputPath = _downloadBytes(fileName, bytes, 'application/json');
    return ExportResult(
      outputPath: outputPath,
      format: ExportFormat.json,
      sizeBytes: bytes.length,
    );
  }
}

class NativeCompressionService implements CompressionService {
  NativeCompressionService({
    ImageProcessingService imageProcessingService =
        const ImageProcessingService(),
  });

  @override
  Future<CompressionResult> compressSelectedFiles({
    required CompressionPreset preset,
  }) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: true,
    );
    return _compressPickerFiles(result?.files ?? const [], preset);
  }

  @override
  Future<CompressionResult> compressFolder({
    required CompressionPreset preset,
  }) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: true,
    );
    return _compressPickerFiles(
      result?.files ?? const [],
      preset,
      kindHint: CompressionKind.folder,
    );
  }

  @override
  Future<CompressionResult> compressPaths(
    List<String> paths, {
    required CompressionPreset preset,
    Object? outputDirectory,
  }) async {
    return const CompressionResult(
      outputPath: '',
      originalBytes: 0,
      compressedBytes: 0,
      items: 0,
      method: 'browser-file-picker-required',
    );
  }

  Future<CompressionResult> _compressPickerFiles(
    List<PlatformFile> files,
    CompressionPreset preset, {
    CompressionKind? kindHint,
  }) async {
    final entries = [
      for (final file in files)
        if (file.bytes != null) _WebCompressionEntry(file, file.bytes!),
    ];
    if (entries.isEmpty) {
      return CompressionResult(
        outputPath: '',
        originalBytes: 0,
        compressedBytes: 0,
        items: 0,
        kind: kindHint ?? CompressionKind.file,
      );
    }

    final intakeService = const FileIntakeService();
    final originalBytes = entries.fold<int>(
      0,
      (total, entry) => total + entry.bytes.length,
    );
    final videoItems = entries
        .where(
          (entry) =>
              intakeService.classifyPath(entry.file.name) == DocumentKind.video,
        )
        .length;
    final hasVideo = videoItems > 0;
    final kinds = entries
        .map((entry) => intakeService.classifyPath(entry.file.name))
        .toSet();
    final hasMixedKinds = kinds.length > 1;
    final allImages = entries.every((entry) => _isImagePath(entry.file.name));

    if (allImages && entries.length == 1) {
      final entry = entries.single;
      final processed = _processImageBytes(
        entry.bytes,
        fileName: entry.file.name,
        imageQuality: preset.imageQuality,
        maxSide: preset.maxImageSide,
      );
      final bestBytes = processed.bytes.length < entry.bytes.length
          ? processed.bytes
          : entry.bytes;
      final fileName = processed.bytes.length < entry.bytes.length
          ? processed.fileName
          : entry.file.name;
      final outputPath = _downloadBytes(fileName, bestBytes, 'image/jpeg');

      return CompressionResult(
        outputPath: outputPath,
        originalBytes: originalBytes,
        compressedBytes: bestBytes.length,
        items: 1,
        kind: CompressionKind.photo,
        method: processed.bytes.length < entry.bytes.length
            ? 'photo-resize'
            : 'original-photo-kept',
        qualityPreserved: processed.bytes.length >= entry.bytes.length,
      );
    }

    final archive = Archive();
    for (final entry in entries) {
      archive.addFile(
        ArchiveFile(
          _safeName(entry.file.name),
          entry.bytes.length,
          entry.bytes,
        ),
      );
    }

    final bytes = ZipEncoder().encode(
      archive,
      level: preset.archiveLevel.clamp(0, 9).toInt(),
    );
    final kind =
        kindHint ??
        (hasVideo && entries.length == videoItems
            ? CompressionKind.video
            : hasMixedKinds
            ? CompressionKind.mixed
            : CompressionKind.file);
    final fileName = _compressionOutputName(
      hasVideo: hasVideo,
      hasFolder: kindHint == CompressionKind.folder,
      hasMixedKinds: hasMixedKinds,
    );
    final outputPath = _downloadBytes(fileName, bytes, 'application/zip');

    return CompressionResult(
      outputPath: outputPath,
      originalBytes: originalBytes,
      compressedBytes: bytes.length,
      items: entries.length,
      kind: kind,
      method: hasVideo
          ? 'quality-preserving-video-archive'
          : kindHint == CompressionKind.folder
          ? 'folder-archive'
          : 'file-archive',
      qualityPreserved: true,
      videoItems: videoItems,
    );
  }
}

class _WebCompressionEntry {
  const _WebCompressionEntry(this.file, this.bytes);

  final PlatformFile file;
  final Uint8List bytes;
}

class _ProcessedImage {
  const _ProcessedImage({
    required this.fileName,
    required this.bytes,
    required this.width,
    required this.height,
  });

  final String fileName;
  final Uint8List bytes;
  final int width;
  final int height;
}

final _webBytes = <String, Uint8List>{};
final _webNames = <String, String>{};

_ProcessedImage _processImageBytes(
  Uint8List bytes, {
  required String fileName,
  CropRect? crop,
  List<PerspectivePoint> perspective = const [],
  int rotation = 0,
  ScanFilter filter = ScanFilter.auto,
  ScanQualitySettings quality = const ScanQualitySettings(),
  double imageQuality = 0.86,
  int? maxSide,
}) {
  final decoded = image_tools.decodeImage(bytes);
  if (decoded == null) {
    throw ArgumentError('Unsupported image: $fileName');
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
  final output = Uint8List.fromList(
    image_tools.encodeJpg(
      edited,
      quality: (imageQuality.clamp(0.1, 1.0) * 100).round(),
    ),
  );

  return _ProcessedImage(
    fileName: '${_safeName(fileName)}-compressed.jpg',
    bytes: output,
    width: edited.width,
    height: edited.height,
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
    edited = image_tools.adjustColor(edited, contrast: 1.75, brightness: 1.08);
  }

  return edited;
}

({int width, int height}) _imageSizeFromBytes(Uint8List bytes) {
  try {
    final decoded = image_tools.decodeImage(bytes);
    return (width: decoded?.width ?? 0, height: decoded?.height ?? 0);
  } catch (_) {
    return (width: 0, height: 0);
  }
}

Archive _openZip(Uint8List bytes) {
  try {
    return ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    return Archive();
  }
}

String _archiveText(Archive archive, String name) {
  final match = archive.files.where((file) => file.name == name).firstOrNull;
  return match == null ? '' : utf8.decode(match.content, allowMalformed: true);
}

List<String> _extractSharedStrings(Archive archive) {
  final xml = _archiveText(archive, 'xl/sharedStrings.xml');
  return RegExp(
    r'<t[^>]*>(.*?)</t>',
    dotAll: true,
  ).allMatches(xml).map((match) => _decodeXml(match.group(1) ?? '')).toList();
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

Uint8List _preparePdfImageBytes(Uint8List source, ExportSettings settings) {
  final decoded = image_tools.decodeImage(source);
  if (decoded == null) {
    return source;
  }

  var prepared = decoded;
  final maxSide = settings.imageQuality <= 0.55
      ? 1400
      : settings.imageQuality <= 0.75
      ? 2200
      : 3200;
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
  if (settings.imageQuality >= 0.85 && encoded.length > source.length) {
    return source;
  }

  return encoded;
}

Uint8List _prepareJpegImageBytes(Uint8List source, ExportSettings settings) {
  final decoded = image_tools.decodeImage(source);
  if (decoded == null) {
    return source;
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

String _extension(String path) {
  final clean = path.split('?').first.toLowerCase();
  final index = clean.lastIndexOf('.');
  return index >= 0 ? clean.substring(index + 1) : '';
}

bool _isImagePath(String path) =>
    FileIntakeService.imageExtensions.contains(_extension(path));

String _cleanText(String value) {
  return value
      .replaceAll('\r', '')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String _cleanOfficeXml(String xml) {
  final text = xml
      .replaceAll(RegExp(r'<a:br\s*/>'), '\n')
      .replaceAll(RegExp(r'</w:p>|</a:p>'), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ');
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
      .replaceAll('>', '&gt;');
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

String _downloadBytes(String fileName, List<int> bytes, String mimeType) {
  final data = Uint8List.fromList(bytes);
  final blob = html.Blob([data], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return fileName;
}

String _createId() => DateTime.now().microsecondsSinceEpoch.toString();
