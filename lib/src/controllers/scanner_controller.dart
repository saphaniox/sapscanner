import 'package:flutter/foundation.dart';

import '../models/scan_models.dart';
import '../services/i18n_service.dart';
import '../services/scanner_services.dart';
import '../services/storage_service.dart';

class ScannerController extends ChangeNotifier {
  ScannerController({
    required this.scannerService,
    required this.exportService,
    required this.compressionService,
    this.storageService,
    this.i18nService = const I18nService(),
  }) : batch = ScanBatch.empty();

  final ScanCaptureService scannerService;
  final BatchExportService exportService;
  final CompressionService compressionService;
  final StorageService? storageService;
  final I18nService i18nService;

  ScanBatch batch;
  bool isBusy = false;
  bool isHydrated = false;
  String notice = '';
  String searchQuery = '';
  String activeFolder = 'All';
  ExportResult? lastExport;
  CompressionResult? lastCompression;

  AppLanguage get language => batch.preferences.language;

  ScanPage? get activePage => batch.activePage;

  int get activeIndex {
    final activeId = batch.activePageId;
    if (activeId == null) {
      return 0;
    }

    final index = batch.pages.indexWhere((page) => page.id == activeId);
    return index < 0 ? 0 : index;
  }

  List<String> get folders {
    final names = <String>{'All', 'Inbox'};
    for (final page in batch.pages) {
      names.add(page.folder);
    }
    return names.toList()
      ..sort((left, right) => left == 'All' ? -1 : left.compareTo(right));
  }

  List<ScanPage> get filteredPages {
    final query = searchQuery.trim().toLowerCase();
    return batch.pages.where((page) {
      final folderMatch = activeFolder == 'All' || page.folder == activeFolder;
      final queryMatch = query.isEmpty || page.searchableText.contains(query);
      return folderMatch && queryMatch;
    }).toList();
  }

  int get estimatedExportSize {
    if (exportService is DocumentExportService) {
      return (exportService as DocumentExportService).estimateExportSize(batch);
    }

    return batch.totalSizeBytes;
  }

  String t(String key) => i18nService.t(language, key);

  Future<void> restore() async {
    final storage = storageService;
    if (storage == null || isHydrated) {
      isHydrated = true;
      return;
    }

    await _run(() async {
      final stored = await storage.loadBatch();
      if (stored != null) {
        final restored = _withoutRetiredGeneratedPages(stored);
        batch = restored;
        if (restored.pages.length != stored.pages.length) {
          await storage.saveBatch(restored);
        }
      }
      isHydrated = true;
      notice = stored == null || batch.pages.isEmpty
          ? ''
          : 'Workspace restored';
    }, saveAfter: false);
  }

  Future<void> startNativeScan() async {
    await _run(() async {
      final result = await scannerService.scanDocument();
      _appendPages(result.pages);
      notice = '${result.pages.length} page scan added';
    });
  }

  Future<void> addCameraCaptures(List<CapturedScanImage> captures) async {
    await _run(() async {
      final result = await scannerService.importCameraCaptures(captures);
      _appendPages(result.pages);
      notice =
          '${result.pages.length} full-screen camera page${result.pages.length == 1 ? '' : 's'} added';
    });
  }

  Future<void> importFiles() async {
    await _run(() async {
      final result = await scannerService.importFiles();
      _appendPages(result.pages);
      notice =
          '${result.pages.length} file${result.pages.length == 1 ? '' : 's'} imported';
    });
  }

  Future<void> export(ExportFormat format) async {
    await _run(() async {
      lastExport = await exportService.exportBatch(batch, format);
      notice = 'Exported ${exportFormatLabel(format)}';
    });
  }

  Future<void> exportActive(ExportFormat format, {String? label}) async {
    await _run(() async {
      final page = activePage;
      if (page == null) {
        notice = 'Open or import a document first';
        return;
      }

      final singleDocumentBatch = ScanBatch.empty().copyWith(
        title: page.title,
        pages: [page],
        activePageId: page.id,
        exportSettings: batch.exportSettings,
        preferences: batch.preferences,
      );
      lastExport = await exportService.exportBatch(singleDocumentBatch, format);
      notice = label ?? 'Converted to ${exportFormatLabel(format)}';
    });
  }

  Future<void> mergeWorkspaceToPdf() async {
    await _run(() async {
      if (batch.pages.isEmpty) {
        notice = 'Import at least one page first';
        return;
      }

      lastExport = await exportService.exportBatch(batch, ExportFormat.pdf);
      notice =
          'Merged ${batch.pages.length} page${batch.pages.length == 1 ? '' : 's'} into PDF';
    });
  }

  Future<void> compressActivePageToPdf() async {
    await _run(() async {
      final page = activePage;
      if (page == null) {
        notice = 'Open or import a document first';
        return;
      }

      final compressedBatch = ScanBatch.empty().copyWith(
        title: '${page.title} compressed',
        pages: [page],
        activePageId: page.id,
        exportSettings: batch.exportSettings.copyWith(
          imageQuality: CompressionPreset.maximum.imageQuality,
          includeTextLayer: true,
          includeAttachmentPages: true,
        ),
        preferences: batch.preferences,
      );
      lastExport = await exportService.exportBatch(
        compressedBatch,
        ExportFormat.pdf,
      );
      notice = 'Compressed active page to PDF';
    });
  }

  Future<void> compress(CompressionPreset preset) async {
    await _run(() async {
      lastCompression = await compressionService.compressSelectedFiles(
        preset: preset,
      );
      notice = _compressionNotice(lastCompression!);
    });
  }

  Future<void> compressFolder(CompressionPreset preset) async {
    await _run(() async {
      lastCompression = await compressionService.compressFolder(preset: preset);
      notice = _compressionNotice(lastCompression!);
    });
  }

  void selectPage(int index) {
    if (index < 0 || index >= batch.pages.length) {
      return;
    }

    batch = batch.copyWith(activePageId: batch.pages[index].id);
    notifyListeners();
  }

  void selectPageById(String id) {
    if (!batch.pages.any((page) => page.id == id)) {
      return;
    }

    batch = batch.copyWith(activePageId: id);
    notifyListeners();
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void setActiveFolder(String value) {
    activeFolder = value;
    notifyListeners();
  }

  void updateLanguage(AppLanguage language) {
    batch = batch.copyWith(
      preferences: batch.preferences.copyWith(language: language),
    );
    notice = '${languageLabel(language)} selected';
    _saveQuietly();
    notifyListeners();
  }

  void updatePageNotes(String pageId, String notes) {
    _replacePage(pageId, (page) => page.copyWith(notes: notes));
  }

  void toggleFavorite(String pageId) {
    _replacePage(pageId, (page) => page.copyWith(favorite: !page.favorite));
  }

  void rotateActivePage(int degrees) {
    final page = activePage;
    if (page == null) {
      return;
    }

    _replacePage(
      page.id,
      (current) =>
          current.copyWith(rotation: (current.rotation + degrees) % 360),
    );
  }

  void applyFilterToActivePage(ScanFilter filter) {
    final page = activePage;
    if (page == null) {
      return;
    }

    _replacePage(page.id, (current) => current.copyWith(filter: filter));
  }

  void moveActivePage(int delta) {
    final from = activeIndex;
    final to = from + delta;
    if (from < 0 ||
        to < 0 ||
        from >= batch.pages.length ||
        to >= batch.pages.length) {
      return;
    }

    final pages = [...batch.pages];
    final page = pages.removeAt(from);
    pages.insert(to, page);
    batch = batch.copyWith(pages: pages, activePageId: page.id);
    _saveQuietly();
    notifyListeners();
  }

  void duplicateActivePage() {
    final page = activePage;
    if (page == null) {
      return;
    }

    final copy = page.copyWith(title: '${page.title} copy');
    final duplicated = ScanPage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: copy.title,
      createdAt: DateTime.now(),
      source: copy.source,
      kind: copy.kind,
      localPath: copy.localPath,
      processedPath: copy.processedPath,
      fileName: copy.fileName,
      mimeType: copy.mimeType,
      folder: copy.folder,
      ocrText: copy.ocrText,
      textPreview: copy.textPreview,
      notes: copy.notes,
      tags: copy.tags,
      quality: copy.quality,
      qualitySettings: copy.qualitySettings,
      sizeBytes: copy.sizeBytes,
      width: copy.width,
      height: copy.height,
      filter: copy.filter,
      rotation: copy.rotation,
      crop: copy.crop,
      perspective: copy.perspective,
      favorite: copy.favorite,
    );

    _appendPages([duplicated]);
    notice = 'Page duplicated';
    _saveQuietly();
    notifyListeners();
  }

  void deleteActivePage() {
    final page = activePage;
    if (page == null) {
      return;
    }

    final pages = batch.pages.where((item) => item.id != page.id).toList();
    batch = batch.copyWith(pages: pages);
    notice = 'Page removed';
    _saveQuietly();
    notifyListeners();
  }

  Future<void> clearWorkspace() async {
    batch = ScanBatch.empty();
    searchQuery = '';
    activeFolder = 'All';
    notice = 'Workspace cleared';
    await storageService?.clearBatch();
    notifyListeners();
  }

  void _appendPages(List<ScanPage> pages) {
    if (pages.isEmpty) {
      return;
    }

    final nextPages = [...batch.pages, ...pages];
    batch = batch.copyWith(pages: nextPages, activePageId: pages.last.id);
  }

  ScanBatch _withoutRetiredGeneratedPages(ScanBatch stored) {
    final pages = stored.pages
        .where((page) => page.source != ScanSource.generated)
        .toList(growable: false);
    return pages.length == stored.pages.length
        ? stored
        : stored.copyWith(pages: pages);
  }

  void _replacePage(String pageId, ScanPage Function(ScanPage page) update) {
    final pages = [
      for (final page in batch.pages) page.id == pageId ? update(page) : page,
    ];
    batch = batch.copyWith(pages: pages, activePageId: pageId);
    _saveQuietly();
    notifyListeners();
  }

  Future<void> _run(
    Future<void> Function() task, {
    bool saveAfter = true,
  }) async {
    isBusy = true;
    notice = '';
    notifyListeners();

    try {
      await task();
      if (saveAfter) {
        await _saveQuietly();
      }
    } catch (error) {
      notice = error.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _saveQuietly() async {
    try {
      await storageService?.saveBatch(batch);
    } catch (_) {
      notice = 'Local save failed';
    }
  }

  String _compressionNotice(CompressionResult result) {
    if (result.items == 0) {
      return 'No files selected';
    }

    final savings = (result.savingsRatio * 100).round();
    final videos = result.videoItems == 0
        ? ''
        : ' - ${result.videoItems} video${result.videoItems == 1 ? '' : 's'} preserved';
    final quality = result.qualityPreserved ? ' - quality preserved' : '';

    return 'Compression complete: $savings% saved$videos$quality';
  }
}
