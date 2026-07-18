enum DocumentKind {
  image,
  pdf,
  word,
  spreadsheet,
  presentation,
  text,
  video,
  archive,
  unknown,
}

enum ScanSource { camera, gallery, file, generated }

enum ScanQuality { draft, standard, premium }

enum ScanFilter { auto, color, grayscale, blackAndWhite }

enum PageSize { a4, letter, legal }

enum ExportFormat { pdf, jpg, text, word, excel, powerPoint, zip, json }

enum AppLanguage { en, lg, xog, sw, fr, es, ar, pt, de, hi, zh, ja }

enum CompressionKind { photo, video, file, folder, mixed }

class CropRect {
  const CropRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;

  Map<String, Object> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory CropRect.fromJson(Map<String, Object?> json) {
    return CropRect(
      x: _int(json['x']),
      y: _int(json['y']),
      width: _int(json['width']),
      height: _int(json['height']),
    );
  }
}

class PerspectivePoint {
  const PerspectivePoint({required this.x, required this.y});

  final double x;
  final double y;

  Map<String, Object> toJson() => {'x': x, 'y': y};

  factory PerspectivePoint.fromJson(Map<String, Object?> json) {
    return PerspectivePoint(x: _double(json['x']), y: _double(json['y']));
  }
}

class ScanQualitySettings {
  const ScanQualitySettings({
    this.brightness = 0,
    this.contrast = 1,
    this.sharpness = 0.15,
  });

  final double brightness;
  final double contrast;
  final double sharpness;

  Map<String, Object> toJson() => {
    'brightness': brightness,
    'contrast': contrast,
    'sharpness': sharpness,
  };

  factory ScanQualitySettings.fromJson(Map<String, Object?> json) {
    return ScanQualitySettings(
      brightness: _double(json['brightness']),
      contrast: _double(json['contrast'], fallback: 1),
      sharpness: _double(json['sharpness'], fallback: 0.15),
    );
  }
}

class ExportSettings {
  const ExportSettings({
    this.pageSize = PageSize.a4,
    this.imageQuality = 0.86,
    this.includeTextLayer = true,
    this.includeAttachmentPages = true,
  });

  final PageSize pageSize;
  final double imageQuality;
  final bool includeTextLayer;
  final bool includeAttachmentPages;

  int get jpegQuality => (imageQuality.clamp(0.1, 1.0) * 100).round();

  Map<String, Object> toJson() => {
    'pageSize': pageSize.name,
    'imageQuality': imageQuality,
    'includeTextLayer': includeTextLayer,
    'includeAttachmentPages': includeAttachmentPages,
  };

  factory ExportSettings.fromJson(Map<String, Object?> json) {
    return ExportSettings(
      pageSize: _enumByName(PageSize.values, json['pageSize'], PageSize.a4),
      imageQuality: _double(
        json['imageQuality'],
        fallback: 0.86,
      ).clamp(0.1, 1.0),
      includeTextLayer: json['includeTextLayer'] != false,
      includeAttachmentPages: json['includeAttachmentPages'] != false,
    );
  }

  ExportSettings copyWith({
    PageSize? pageSize,
    double? imageQuality,
    bool? includeTextLayer,
    bool? includeAttachmentPages,
  }) {
    return ExportSettings(
      pageSize: pageSize ?? this.pageSize,
      imageQuality: imageQuality ?? this.imageQuality,
      includeTextLayer: includeTextLayer ?? this.includeTextLayer,
      includeAttachmentPages:
          includeAttachmentPages ?? this.includeAttachmentPages,
    );
  }
}

class ScanPreferences {
  const ScanPreferences({
    this.language = AppLanguage.en,
    this.privacyMode = true,
    this.autoCropOnImport = true,
    this.defaultFolder = 'Inbox',
  });

  final AppLanguage language;
  final bool privacyMode;
  final bool autoCropOnImport;
  final String defaultFolder;

  Map<String, Object> toJson() => {
    'language': language.name,
    'privacyMode': privacyMode,
    'autoCropOnImport': autoCropOnImport,
    'defaultFolder': defaultFolder,
  };

  factory ScanPreferences.fromJson(Map<String, Object?> json) {
    return ScanPreferences(
      language: _enumByName(
        AppLanguage.values,
        json['language'],
        AppLanguage.en,
      ),
      privacyMode: json['privacyMode'] != false,
      autoCropOnImport: json['autoCropOnImport'] != false,
      defaultFolder:
          (json['defaultFolder'] as String?)?.trim().isNotEmpty == true
          ? json['defaultFolder']! as String
          : 'Inbox',
    );
  }

  ScanPreferences copyWith({
    AppLanguage? language,
    bool? privacyMode,
    bool? autoCropOnImport,
    String? defaultFolder,
  }) {
    return ScanPreferences(
      language: language ?? this.language,
      privacyMode: privacyMode ?? this.privacyMode,
      autoCropOnImport: autoCropOnImport ?? this.autoCropOnImport,
      defaultFolder: defaultFolder ?? this.defaultFolder,
    );
  }
}

class ScanPage {
  const ScanPage({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.source,
    this.kind = DocumentKind.image,
    this.localPath,
    this.processedPath,
    this.fileName = '',
    this.mimeType = '',
    this.folder = 'Inbox',
    this.ocrText = '',
    this.textPreview = '',
    this.notes = '',
    this.tags = const [],
    this.quality = ScanQuality.standard,
    this.qualitySettings = const ScanQualitySettings(),
    this.sizeBytes = 0,
    this.width = 0,
    this.height = 0,
    this.filter = ScanFilter.auto,
    this.rotation = 0,
    this.crop,
    this.perspective = const [],
    this.favorite = false,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final ScanSource source;
  final DocumentKind kind;
  final String? localPath;
  final String? processedPath;
  final String fileName;
  final String mimeType;
  final String folder;
  final String ocrText;
  final String textPreview;
  final String notes;
  final List<String> tags;
  final ScanQuality quality;
  final ScanQualitySettings qualitySettings;
  final int sizeBytes;
  final int width;
  final int height;
  final ScanFilter filter;
  final int rotation;
  final CropRect? crop;
  final List<PerspectivePoint> perspective;
  final bool favorite;

  String get searchableText {
    return [
      title,
      fileName,
      folder,
      notes,
      ocrText,
      textPreview,
      ...tags,
    ].where((value) => value.trim().isNotEmpty).join(' ').toLowerCase();
  }

  String? get bestPath => processedPath ?? localPath;

  ScanPage copyWith({
    String? title,
    DocumentKind? kind,
    String? localPath,
    String? processedPath,
    String? fileName,
    String? mimeType,
    String? folder,
    String? ocrText,
    String? textPreview,
    String? notes,
    List<String>? tags,
    ScanQuality? quality,
    ScanQualitySettings? qualitySettings,
    int? sizeBytes,
    int? width,
    int? height,
    ScanFilter? filter,
    int? rotation,
    CropRect? crop,
    List<PerspectivePoint>? perspective,
    bool? favorite,
  }) {
    return ScanPage(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      source: source,
      kind: kind ?? this.kind,
      localPath: localPath ?? this.localPath,
      processedPath: processedPath ?? this.processedPath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      folder: folder ?? this.folder,
      ocrText: ocrText ?? this.ocrText,
      textPreview: textPreview ?? this.textPreview,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      quality: quality ?? this.quality,
      qualitySettings: qualitySettings ?? this.qualitySettings,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      filter: filter ?? this.filter,
      rotation: rotation ?? this.rotation,
      crop: crop ?? this.crop,
      perspective: perspective ?? this.perspective,
      favorite: favorite ?? this.favorite,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'source': source.name,
    'kind': kind.name,
    'localPath': localPath,
    'processedPath': processedPath,
    'fileName': fileName,
    'mimeType': mimeType,
    'folder': folder,
    'ocrText': ocrText,
    'textPreview': textPreview,
    'notes': notes,
    'tags': tags,
    'quality': quality.name,
    'qualitySettings': qualitySettings.toJson(),
    'sizeBytes': sizeBytes,
    'width': width,
    'height': height,
    'filter': filter.name,
    'rotation': rotation,
    'crop': crop?.toJson(),
    'perspective': perspective.map((point) => point.toJson()).toList(),
    'favorite': favorite,
  };

  factory ScanPage.fromJson(Map<String, Object?> json) {
    return ScanPage(
      id: (json['id'] as String?) ?? _createId(),
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title']! as String
          : 'Untitled scan',
      createdAt: _date(json['createdAt']),
      source: _enumByName(ScanSource.values, json['source'], ScanSource.file),
      kind: _enumByName(
        DocumentKind.values,
        json['kind'],
        DocumentKind.unknown,
      ),
      localPath: json['localPath'] as String?,
      processedPath: json['processedPath'] as String?,
      fileName: (json['fileName'] as String?) ?? '',
      mimeType: (json['mimeType'] as String?) ?? '',
      folder: (json['folder'] as String?)?.trim().isNotEmpty == true
          ? json['folder']! as String
          : 'Inbox',
      ocrText: (json['ocrText'] as String?) ?? '',
      textPreview: (json['textPreview'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
      tags: _strings(json['tags']),
      quality: _enumByName(
        ScanQuality.values,
        json['quality'],
        ScanQuality.standard,
      ),
      qualitySettings: json['qualitySettings'] is Map<String, Object?>
          ? ScanQualitySettings.fromJson(
              json['qualitySettings']! as Map<String, Object?>,
            )
          : const ScanQualitySettings(),
      sizeBytes: _int(json['sizeBytes']),
      width: _int(json['width']),
      height: _int(json['height']),
      filter: _enumByName(ScanFilter.values, json['filter'], ScanFilter.auto),
      rotation: _int(json['rotation']),
      crop: json['crop'] is Map<String, Object?>
          ? CropRect.fromJson(json['crop']! as Map<String, Object?>)
          : null,
      perspective: _maps(
        json['perspective'],
      ).map(PerspectivePoint.fromJson).toList(),
      favorite: json['favorite'] == true,
    );
  }
}

class ScanBatch {
  const ScanBatch({
    required this.id,
    required this.title,
    required this.createdAt,
    this.updatedAt,
    this.pages = const [],
    this.activePageId,
    this.exportSettings = const ExportSettings(),
    this.preferences = const ScanPreferences(),
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<ScanPage> pages;
  final String? activePageId;
  final ExportSettings exportSettings;
  final ScanPreferences preferences;

  static ScanBatch empty() {
    final now = DateTime.now();
    return ScanBatch(
      id: _createId(),
      title: 'Sap scan',
      createdAt: now,
      updatedAt: now,
    );
  }

  int get totalSizeBytes =>
      pages.fold<int>(0, (total, page) => total + page.sizeBytes);

  ScanPage? get activePage {
    if (pages.isEmpty) {
      return null;
    }

    return pages.firstWhere(
      (page) => page.id == activePageId,
      orElse: () => pages.first,
    );
  }

  ScanBatch copyWith({
    String? title,
    DateTime? updatedAt,
    List<ScanPage>? pages,
    String? activePageId,
    ExportSettings? exportSettings,
    ScanPreferences? preferences,
  }) {
    final nextPages = pages ?? this.pages;
    final nextActiveId = activePageId ?? this.activePageId;
    final normalizedActiveId = nextPages.any((page) => page.id == nextActiveId)
        ? nextActiveId
        : nextPages.isEmpty
        ? null
        : nextPages.first.id;

    return ScanBatch(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      pages: nextPages,
      activePageId: normalizedActiveId,
      exportSettings: exportSettings ?? this.exportSettings,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'pages': pages.map((page) => page.toJson()).toList(),
    'activePageId': activePageId,
    'exportSettings': exportSettings.toJson(),
    'preferences': preferences.toJson(),
  };

  factory ScanBatch.fromJson(Map<String, Object?> json) {
    final pages = _maps(json['pages']).map(ScanPage.fromJson).toList();

    return ScanBatch(
      id: (json['id'] as String?) ?? _createId(),
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title']! as String
          : 'Sap scan',
      createdAt: _date(json['createdAt']),
      updatedAt: json['updatedAt'] == null ? null : _date(json['updatedAt']),
      pages: pages,
      activePageId: pages.any((page) => page.id == json['activePageId'])
          ? json['activePageId'] as String?
          : pages.isEmpty
          ? null
          : pages.first.id,
      exportSettings: json['exportSettings'] is Map<String, Object?>
          ? ExportSettings.fromJson(
              json['exportSettings']! as Map<String, Object?>,
            )
          : const ExportSettings(),
      preferences: json['preferences'] is Map<String, Object?>
          ? ScanPreferences.fromJson(
              json['preferences']! as Map<String, Object?>,
            )
          : const ScanPreferences(),
    );
  }
}

class ConversionOption {
  const ConversionOption({
    required this.title,
    required this.subtitle,
    required this.format,
    this.sourceKind,
  });

  final String title;
  final String subtitle;
  final ExportFormat format;
  final DocumentKind? sourceKind;
}

class CompressionPreset {
  const CompressionPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.targetSavings,
    required this.imageQuality,
    required this.maxImageSide,
    required this.archiveLevel,
  });

  final String id;
  final String name;
  final String description;
  final double targetSavings;
  final double imageQuality;
  final int maxImageSide;
  final int archiveLevel;

  static const balanced = CompressionPreset(
    id: 'balanced',
    name: 'Balanced',
    description: 'Good quality and smaller files',
    targetSavings: 0.35,
    imageQuality: 0.84,
    maxImageSide: 2560,
    archiveLevel: 6,
  );

  static const saver = CompressionPreset(
    id: 'saver',
    name: 'Storage saver',
    description: 'Aggressive photo and file savings',
    targetSavings: 0.6,
    imageQuality: 0.72,
    maxImageSide: 1920,
    archiveLevel: 8,
  );

  static const maximum = CompressionPreset(
    id: 'maximum',
    name: 'Maximum',
    description: 'Targets up to 80% where the source allows it',
    targetSavings: 0.8,
    imageQuality: 0.48,
    maxImageSide: 1280,
    archiveLevel: 9,
  );

  static const values = [balanced, saver, maximum];
}

String documentKindLabel(DocumentKind kind) {
  return switch (kind) {
    DocumentKind.image => 'Image',
    DocumentKind.pdf => 'PDF',
    DocumentKind.word => 'Word',
    DocumentKind.spreadsheet => 'Excel',
    DocumentKind.presentation => 'PowerPoint',
    DocumentKind.text => 'Text',
    DocumentKind.video => 'Video',
    DocumentKind.archive => 'Archive',
    DocumentKind.unknown => 'File',
  };
}

String exportFormatLabel(ExportFormat format) {
  return switch (format) {
    ExportFormat.pdf => 'PDF',
    ExportFormat.jpg => 'JPEG',
    ExportFormat.text => 'Text',
    ExportFormat.word => 'Word',
    ExportFormat.excel => 'Excel',
    ExportFormat.powerPoint => 'PowerPoint',
    ExportFormat.zip => 'ZIP',
    ExportFormat.json => 'JSON',
  };
}

String languageLabel(AppLanguage language) {
  return switch (language) {
    AppLanguage.en => 'English',
    AppLanguage.lg => 'Luganda',
    AppLanguage.xog => 'Lusoga',
    AppLanguage.sw => 'Kiswahili',
    AppLanguage.fr => 'Francais',
    AppLanguage.es => 'Espanol',
    AppLanguage.ar => 'Arabic',
    AppLanguage.pt => 'Portuguese',
    AppLanguage.de => 'German',
    AppLanguage.hi => 'Hindi',
    AppLanguage.zh => 'Chinese',
    AppLanguage.ja => 'Japanese',
  };
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  final text = name?.toString();
  if (text == null) {
    return fallback;
  }

  for (final value in values) {
    if (value.name == text) {
      return value;
    }
  }

  return fallback;
}

DateTime _date(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

int _int(Object? value) {
  if (value is num) {
    return value.round();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _strings(Object? value) {
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  return const [];
}

List<Map<String, Object?>> _maps(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList();
  }

  return const [];
}

String _createId() => DateTime.now().microsecondsSinceEpoch.toString();
