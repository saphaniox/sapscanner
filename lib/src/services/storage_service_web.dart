// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';

import 'dart:html' as html;

import '../models/scan_models.dart';

abstract class StorageService {
  Future<void> saveBatch(ScanBatch batch);

  Future<ScanBatch?> loadBatch();

  Future<void> clearBatch();
}

class JsonStorageService implements StorageService {
  JsonStorageService({Object? directory});

  static const _storageKey = 'sapscanner-workspace';

  @override
  Future<void> saveBatch(ScanBatch batch) async {
    const encoder = JsonEncoder.withIndent('  ');
    html.window.localStorage[_storageKey] = encoder.convert(batch.toJson());
  }

  @override
  Future<ScanBatch?> loadBatch() async {
    final raw = html.window.localStorage[_storageKey];
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final json = jsonDecode(raw);
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
    html.window.localStorage.remove(_storageKey);
  }
}
