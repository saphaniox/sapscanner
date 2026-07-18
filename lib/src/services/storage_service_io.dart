import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/scan_models.dart';

abstract class StorageService {
  Future<void> saveBatch(ScanBatch batch);

  Future<ScanBatch?> loadBatch();

  Future<void> clearBatch();
}

class JsonStorageService implements StorageService {
  JsonStorageService({Directory? directory}) : _directory = directory;

  final Directory? _directory;

  Future<File> get _file async {
    final directory = _directory ?? await getApplicationDocumentsDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return File(
      '${directory.path}${Platform.pathSeparator}sapscanner-workspace.json',
    );
  }

  @override
  Future<void> saveBatch(ScanBatch batch) async {
    final file = await _file;
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(batch.toJson()), flush: true);
  }

  @override
  Future<ScanBatch?> loadBatch() async {
    final file = await _file;
    if (!await file.exists()) {
      return null;
    }

    final json = jsonDecode(await file.readAsString());
    if (json is Map<String, Object?>) {
      return ScanBatch.fromJson(json);
    }

    if (json is Map) {
      return ScanBatch.fromJson(json.cast<String, Object?>());
    }

    return null;
  }

  @override
  Future<void> clearBatch() async {
    final file = await _file;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
        return;
      } on FileSystemException {
        if (attempt == 2) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    }
  }
}
