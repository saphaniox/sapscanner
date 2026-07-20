import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sapscanner/main.dart';
import 'package:sapscanner/src/controllers/scanner_controller.dart';
import 'package:sapscanner/src/models/scan_models.dart';
import 'package:sapscanner/src/services/scanner_services.dart';
import 'package:sapscanner/src/views/sap_scanner_home.dart';

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('renders SapScanner native shell', (tester) async {
    final controller = ScannerController(
      scannerService: NativeScannerService(),
      exportService: DocumentExportService(),
      compressionService: NativeCompressionService(),
    );

    await tester.pumpWidget(SapScannerApp(controller: controller));

    expect(find.text('SapScanner'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) {
        return widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/branding/sapscanner_logo.png';
      }),
      findsOneWidget,
    );
    expect(
      find.text('Scan with clarity. Work with confidence.'),
      findsOneWidget,
    );
    expect(find.text('Scan workspace'), findsOneWidget);
    expect(find.text('Import files'), findsOneWidget);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
  });

  testWidgets('shows conversion PDF tools and compression workspace', (
    tester,
  ) async {
    final controller = ScannerController(
      scannerService: NativeScannerService(),
      exportService: DocumentExportService(),
      compressionService: NativeCompressionService(),
    );

    await tester.pumpWidget(SapScannerApp(controller: controller));

    await tester.tap(find.text('Convert'));
    await tester.pumpAndSettle();

    expect(find.text('Open document'), findsOneWidget);
    expect(find.text('Image to PDF'), findsOneWidget);
    expect(find.text('Merge pages to PDF'), findsOneWidget);
    expect(find.text('Compress page PDF'), findsOneWidget);

    await tester.tap(find.text('Compress'));
    await tester.pumpAndSettle();

    expect(find.text('Compression studio'), findsOneWidget);
    expect(find.text('Compress files'), findsOneWidget);
    expect(find.text('Compress folder'), findsOneWidget);
    expect(find.text('Maximum'), findsOneWidget);
  });

  testWidgets('uses Arabic labels with right-to-left layout', (tester) async {
    final controller = ScannerController(
      scannerService: NativeScannerService(),
      exportService: DocumentExportService(),
      compressionService: NativeCompressionService(),
    );
    controller.updateLanguage(AppLanguage.ar);

    await tester.pumpWidget(SapScannerApp(controller: controller));

    final directions = tester.widgetList<Directionality>(
      find.byType(Directionality),
    );
    expect(
      directions.any((widget) => widget.textDirection == TextDirection.rtl),
      isTrue,
    );
    expect(find.text('الإعدادات'), findsOneWidget);
  });

  testWidgets('uses navigation rail on wider devices', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 800);

    final controller = ScannerController(
      scannerService: NativeScannerService(),
      exportService: DocumentExportService(),
      compressionService: NativeCompressionService(),
    );

    await tester.pumpWidget(SapScannerApp(controller: controller));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Scan workspace'), findsOneWidget);
  });

  testWidgets('keeps phone layout usable on narrow screens', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);

    final controller = ScannerController(
      scannerService: NativeScannerService(),
      exportService: DocumentExportService(),
      compressionService: NativeCompressionService(),
    );

    await tester.pumpWidget(SapScannerApp(controller: controller));

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  test('conversion workspace exposes the office conversion matrix', () {
    final titles = ConvertWorkspace.options.map((option) => option.title);

    expect(
      titles,
      containsAll([
        'Image to PDF',
        'Image to DOC',
        'OCR to XLS',
        'Image to PPT',
        'Image to JPG',
        'Document to TXT',
        'PDF to Word',
        'PDF to Excel',
        'PDF to PowerPoint',
        'Word to PDF',
        'Word to Excel',
        'Word to PowerPoint',
        'Excel to PDF',
        'Excel to Word',
        'Excel to PowerPoint',
        'PowerPoint to PDF',
        'PowerPoint to Word',
        'PowerPoint to Excel',
        'Pages to ZIP',
      ]),
    );
  });
}
