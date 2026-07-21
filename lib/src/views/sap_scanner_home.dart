import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controllers/scanner_controller.dart';
import '../models/scan_models.dart';
import '../services/scanner_services.dart';
import '../theme/sap_theme.dart';

class SapScannerHome extends StatefulWidget {
  const SapScannerHome({super.key, required this.controller});

  final ScannerController controller;

  @override
  State<SapScannerHome> createState() => _SapScannerHomeState();
}

class _SapScannerHomeState extends State<SapScannerHome> {
  int pageIndex = 0;

  ScannerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_refresh);
    controller.restore();
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ScanWorkspace(controller: controller),
      LibraryWorkspace(controller: controller),
      ConvertWorkspace(controller: controller),
      CompressWorkspace(controller: controller),
      SettingsWorkspace(controller: controller),
    ];
    final navigationItems = [
      _NavigationItem(
        icon: Icons.document_scanner_outlined,
        label: controller.t('scan'),
      ),
      _NavigationItem(
        icon: Icons.folder_copy_outlined,
        label: controller.t('library'),
      ),
      _NavigationItem(icon: Icons.swap_horiz, label: controller.t('convert')),
      _NavigationItem(icon: Icons.compress, label: controller.t('compress')),
      _NavigationItem(
        icon: Icons.settings_outlined,
        label: controller.t('settings'),
      ),
    ];

    return Directionality(
      textDirection: controller.language == AppLanguage.ar
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useRail = constraints.maxWidth >= 840;
          final content = SafeArea(
            child: Column(
              children: [
                if (controller.notice.isNotEmpty)
                  NoticeBanner(message: controller.notice),
                Expanded(child: pages[pageIndex]),
              ],
            ),
          );

          return Scaffold(
            appBar: AppBar(
              titleSpacing: 16,
              title: Row(
                children: [
                  const SapMark(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SapScanner',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          controller.t('nativeStudio'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                if (controller.isBusy)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
            body: useRail
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: pageIndex,
                        labelType: NavigationRailLabelType.all,
                        minWidth: 82,
                        destinations: [
                          for (final item in navigationItems)
                            NavigationRailDestination(
                              icon: Icon(item.icon),
                              label: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onDestinationSelected: (index) {
                          setState(() => pageIndex = index);
                        },
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: content),
                    ],
                  )
                : content,
            bottomNavigationBar: useRail
                ? null
                : NavigationBar(
                    selectedIndex: pageIndex,
                    onDestinationSelected: (index) {
                      setState(() => pageIndex = index);
                    },
                    destinations: [
                      for (final item in navigationItems)
                        NavigationDestination(
                          icon: Icon(item.icon),
                          label: item.label,
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class ResponsiveListView extends StatelessWidget {
  const ResponsiveListView({
    super.key,
    required this.children,
    this.maxWidth = 1040,
  });

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 380
            ? 12.0
            : constraints.maxWidth < 720
            ? 16.0
            : 24.0;
        final bottomPadding = 24.0 + MediaQuery.paddingOf(context).bottom;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            bottomPadding,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ScanWorkspace extends StatelessWidget {
  const ScanWorkspace({super.key, required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    final activePage = controller.activePage;

    return ResponsiveListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle(
                  icon: Icons.document_scanner_outlined,
                  title: 'Scan workspace',
                  subtitle: 'Capture, refine, and export documents locally.',
                ),
                const SizedBox(height: 16),
                activePage == null
                    ? const ScanPreviewFrame()
                    : ActivePagePreview(page: activePage),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: controller.isBusy
                          ? null
                          : () => _openFullScreenScanner(context),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(controller.t('startScan')),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.isBusy
                          ? null
                          : () => controller.importFiles(),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(controller.t('importFiles')),
                    ),
                    IconButton.filledTonal(
                      tooltip: controller.t('clear'),
                      onPressed: controller.isBusy
                          ? null
                          : controller.clearWorkspace,
                      icon: const Icon(Icons.cleaning_services_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (activePage != null) ...[
          const SizedBox(height: 12),
          PageTools(controller: controller),
        ],
        const SizedBox(height: 12),
        MetricStrip(controller: controller),
      ],
    );
  }

  void _openFullScreenScanner(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullScreenScannerView(controller: controller),
      ),
    );
  }
}

class FullScreenScannerView extends StatefulWidget {
  const FullScreenScannerView({super.key, required this.controller});

  final ScannerController controller;

  @override
  State<FullScreenScannerView> createState() => _FullScreenScannerViewState();
}

class _FullScreenScannerViewState extends State<FullScreenScannerView> {
  CameraController? camera;
  List<CameraDescription> cameras = const [];
  int cameraIndex = 0;
  bool isInitializing = true;
  bool isCapturing = false;
  FlashMode flashMode = FlashMode.off;
  String? errorMessage;

  bool get canCapture {
    final activeCamera = camera;
    return activeCamera != null &&
        activeCamera.value.isInitialized &&
        !isInitializing &&
        !isCapturing;
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    camera?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          isInitializing = false;
          errorMessage = 'No camera was found on this device.';
        });
        return;
      }

      await _startCamera(_preferredCameraIndex(cameras));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        isInitializing = false;
        errorMessage = 'Camera could not start. $error';
      });
    }
  }

  Future<void> _startCamera(int index) async {
    final previous = camera;
    final nextCamera = CameraController(
      cameras[index],
      kIsWeb ? ResolutionPreset.high : ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    setState(() {
      isInitializing = true;
      errorMessage = null;
    });

    await previous?.dispose();
    await nextCamera.initialize().timeout(const Duration(seconds: 14));

    if (!mounted) {
      await nextCamera.dispose();
      return;
    }

    try {
      await nextCamera.setFlashMode(FlashMode.off);
    } catch (_) {
      // Some web and front-facing cameras do not expose flash controls.
    }
    try {
      await nextCamera.setFocusMode(FocusMode.auto);
      await nextCamera.setExposureMode(ExposureMode.auto);
    } catch (_) {
      // Browser camera streams often skip focus and exposure controls.
    }

    setState(() {
      camera = nextCamera;
      cameraIndex = index;
      flashMode = FlashMode.off;
      isInitializing = false;
    });
  }

  int _preferredCameraIndex(List<CameraDescription> available) {
    final backIndex = available.indexWhere(
      (item) => item.lensDirection == CameraLensDirection.back,
    );
    return backIndex < 0 ? 0 : backIndex;
  }

  Future<void> _captureImage() async {
    final activeCamera = camera;
    if (activeCamera == null ||
        !activeCamera.value.isInitialized ||
        activeCamera.value.isTakingPicture ||
        isCapturing) {
      return;
    }

    setState(() => isCapturing = true);

    try {
      final beforeCount = widget.controller.batch.pages.length;
      final photo = await activeCamera.takePicture().timeout(
        const Duration(seconds: 15),
      );
      final bytes = await photo.readAsBytes().timeout(
        const Duration(seconds: 10),
      );
      final fileName =
          'Scan-${DateTime.now().millisecondsSinceEpoch.toString()}.jpg';

      await widget.controller.addCameraCaptures([
        CapturedScanImage(
          fileName: fileName,
          path: photo.path,
          bytes: bytes,
          mimeType: 'image/jpeg',
        ),
      ]);

      if (!mounted) {
        return;
      }

      if (widget.controller.batch.pages.length > beforeCount) {
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        isCapturing = false;
        errorMessage = 'The photo could not be saved. Try upload instead.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        isCapturing = false;
        errorMessage = 'Capture failed. $error';
      });
    }
  }

  Future<void> _useCameraUpload() async {
    final beforeCount = widget.controller.batch.pages.length;
    await widget.controller.startNativeScan();
    if (!mounted) {
      return;
    }

    if (widget.controller.batch.pages.length > beforeCount) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      errorMessage = widget.controller.notice.isEmpty
          ? 'No image was selected.'
          : widget.controller.notice;
    });
  }

  Future<void> _toggleFlash() async {
    final activeCamera = camera;
    if (activeCamera == null || !activeCamera.value.isInitialized) {
      return;
    }

    final nextMode = flashMode == FlashMode.off
        ? FlashMode.torch
        : FlashMode.off;
    try {
      await activeCamera.setFlashMode(nextMode);
      if (mounted) {
        setState(() => flashMode = nextMode);
      }
    } catch (_) {
      if (mounted) {
        setState(() => errorMessage = 'Flash is not available here.');
      }
    }
  }

  Future<void> _switchCamera() async {
    if (cameras.length < 2 || isInitializing || isCapturing) {
      return;
    }

    final nextIndex = (cameraIndex + 1) % cameras.length;
    try {
      await _startCamera(nextIndex);
    } catch (error) {
      if (mounted) {
        setState(() => errorMessage = 'Could not switch camera. $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(child: _buildCameraBody()),
            const Positioned.fill(child: _ScannerGuideOverlay()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filled(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Flash',
                          onPressed: isInitializing || isCapturing
                              ? null
                              : _toggleFlash,
                          icon: Icon(
                            flashMode == FlashMode.off
                                ? Icons.flash_off
                                : Icons.flash_on,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Switch camera',
                          onPressed:
                              cameras.length < 2 ||
                                  isInitializing ||
                                  isCapturing
                              ? null
                              : _switchCamera,
                          icon: const Icon(Icons.cameraswitch_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (errorMessage != null)
              Positioned(
                left: 16,
                right: 16,
                top: MediaQuery.paddingOf(context).top + 74,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xDDFFF4DE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: widget.controller.isBusy
                              ? null
                              : _useCameraUpload,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Upload image'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 84,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: SapTheme.black,
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: canCapture ? _captureImage : null,
                          child: isCapturing
                              ? const SizedBox.square(
                                  dimension: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Icon(Icons.camera, size: 34),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraBody() {
    final activeCamera = camera;
    if (isInitializing) {
      return const SizedBox.expand(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (activeCamera == null || !activeCamera.value.isInitialized) {
      return const SizedBox.expand(
        child: Center(
          child: Icon(
            Icons.no_photography_outlined,
            color: Colors.white54,
            size: 72,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = activeCamera.value.previewSize;
        if (previewSize == null) {
          return SizedBox.expand(child: CameraPreview(activeCamera));
        }

        final isPortrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;
        final previewWidth = isPortrait
            ? previewSize.height
            : previewSize.width;
        final previewHeight = isPortrait
            ? previewSize.width
            : previewSize.height;

        final viewportAspect = constraints.maxWidth / constraints.maxHeight;
        final previewAspect = previewWidth / previewHeight;
        final coverWidth = viewportAspect > previewAspect
            ? constraints.maxWidth
            : constraints.maxHeight * previewAspect;
        final coverHeight = viewportAspect > previewAspect
            ? constraints.maxWidth / previewAspect
            : constraints.maxHeight;

        return SizedBox.expand(
          child: ClipRect(
            child: OverflowBox(
              maxWidth: coverWidth,
              maxHeight: coverHeight,
              alignment: Alignment.center,
              child: SizedBox(
                width: coverWidth,
                height: coverHeight,
                child: CameraPreview(activeCamera),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScannerGuideOverlay extends StatelessWidget {
  const _ScannerGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.84,
          heightFactor: 0.58,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SapTheme.yellow, width: 3),
            ),
            child: const Stack(
              children: [
                Positioned(left: 12, top: 12, child: CornerGuide()),
                Positioned(right: 12, top: 12, child: CornerGuide(flipX: true)),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: CornerGuide(flipY: true),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: CornerGuide(flipX: true, flipY: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ActivePagePreview extends StatelessWidget {
  const ActivePagePreview({super.key, required this.page});

  final ScanPage page;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SapTheme.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_kindIcon(page.kind), color: SapTheme.black),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          page.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (page.favorite)
                        const Icon(Icons.star, color: SapTheme.yellow),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    documentKindLabel(page.kind),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: PageVisualPreview(page: page)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PageVisualPreview extends StatelessWidget {
  const PageVisualPreview({super.key, required this.page, this.minHeight});

  final ScanPage page;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: loadScanPageImageBytes(page),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: BoxConstraints(minHeight: minHeight ?? 0),
              color: const Color(0xFFF8FAF9),
              alignment: Alignment.center,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            ),
          );
        }

        return Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: minHeight ?? 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAF9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDDE5E1)),
          ),
          child: Text(
            _previewText(page),
            maxLines: minHeight == null ? 8 : null,
            overflow: minHeight == null ? TextOverflow.fade : null,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      },
    );
  }
}

class PageTools extends StatelessWidget {
  const PageTools({super.key, required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    final page = controller.activePage;
    if (page == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                IconButton.outlined(
                  tooltip: 'Move up',
                  onPressed: () => controller.moveActivePage(-1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton.outlined(
                  tooltip: 'Move down',
                  onPressed: () => controller.moveActivePage(1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton.outlined(
                  tooltip: 'Rotate left',
                  onPressed: () => controller.rotateActivePage(-90),
                  icon: const Icon(Icons.rotate_left),
                ),
                IconButton.outlined(
                  tooltip: 'Rotate right',
                  onPressed: () => controller.rotateActivePage(90),
                  icon: const Icon(Icons.rotate_right),
                ),
                IconButton.outlined(
                  tooltip: 'Favorite',
                  onPressed: () => controller.toggleFavorite(page.id),
                  icon: Icon(page.favorite ? Icons.star : Icons.star_border),
                ),
                IconButton.outlined(
                  tooltip: 'Duplicate',
                  onPressed: controller.duplicateActivePage,
                  icon: const Icon(Icons.content_copy),
                ),
                IconButton.outlined(
                  tooltip: 'Delete',
                  onPressed: controller.deleteActivePage,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ScanFilter>(
                segments: const [
                  ButtonSegment(
                    value: ScanFilter.auto,
                    label: Text('Auto'),
                    icon: Icon(Icons.auto_fix_high),
                  ),
                  ButtonSegment(
                    value: ScanFilter.color,
                    label: Text('Color'),
                    icon: Icon(Icons.palette_outlined),
                  ),
                  ButtonSegment(
                    value: ScanFilter.grayscale,
                    label: Text('Gray'),
                    icon: Icon(Icons.tonality),
                  ),
                  ButtonSegment(
                    value: ScanFilter.blackAndWhite,
                    label: Text('B/W'),
                    icon: Icon(Icons.contrast),
                  ),
                ],
                selected: {page.filter},
                onSelectionChanged: (value) =>
                    controller.applyFilterToActivePage(value.first),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LibraryWorkspace extends StatelessWidget {
  const LibraryWorkspace({super.key, required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    final pages = controller.filteredPages;

    return ResponsiveListView(
      children: [
        _LibraryFilterBar(controller: controller),
        const SizedBox(height: 14),
        if (pages.isEmpty)
          const EmptyState(
            icon: Icons.folder_open_outlined,
            title: 'No scans yet',
            body: 'Start with the scanner or import a document.',
          )
        else
          for (final page in pages) ...[
            Card(
              child: ListTile(
                selected: page.id == controller.activePage?.id,
                leading: Icon(_kindIcon(page.kind)),
                title: Text(
                  page.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${documentKindLabel(page.kind)}  ${page.folder}  ${_formatBytes(page.sizeBytes)}',
                ),
                trailing: page.favorite
                    ? const Icon(Icons.star, color: SapTheme.yellow)
                    : const Icon(Icons.chevron_right),
                onTap: () {
                  controller.selectPageById(page.id);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DocumentViewerScreen(page: page),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _LibraryFilterBar extends StatelessWidget {
  const _LibraryFilterBar({required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    final searchField = TextField(
      decoration: InputDecoration(
        labelText: controller.t('search'),
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
      ),
      onChanged: controller.setSearchQuery,
    );
    final folderField = DropdownButtonFormField<String>(
      initialValue: controller.activeFolder,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: controller.t('folder'),
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final folder in controller.folders)
          DropdownMenuItem(
            value: folder,
            child: Text(
              folder == 'All' ? controller.t('all') : folder,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null) {
          controller.setActiveFolder(value);
        }
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [searchField, const SizedBox(height: 10), folderField],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 10),
            SizedBox(width: 180, child: folderField),
          ],
        );
      },
    );
  }
}

class ConvertWorkspace extends StatelessWidget {
  const ConvertWorkspace({super.key, required this.controller});

  final ScannerController controller;

  static const options = [
    ConversionOption(
      title: 'Image to PDF',
      subtitle: 'PDF',
      format: ExportFormat.pdf,
      sourceKind: DocumentKind.image,
    ),
    ConversionOption(
      title: 'Image to DOC',
      subtitle: 'Word',
      format: ExportFormat.word,
      sourceKind: DocumentKind.image,
    ),
    ConversionOption(
      title: 'OCR to XLS',
      subtitle: 'Excel',
      format: ExportFormat.excel,
      sourceKind: DocumentKind.image,
    ),
    ConversionOption(
      title: 'Image to PPT',
      subtitle: 'PowerPoint',
      format: ExportFormat.powerPoint,
      sourceKind: DocumentKind.image,
    ),
    ConversionOption(
      title: 'Image to JPG',
      subtitle: 'Image',
      format: ExportFormat.jpg,
      sourceKind: DocumentKind.image,
    ),
    ConversionOption(
      title: 'Document to TXT',
      subtitle: 'Text',
      format: ExportFormat.text,
    ),
    ConversionOption(
      title: 'PDF to Word',
      subtitle: 'Word',
      format: ExportFormat.word,
      sourceKind: DocumentKind.pdf,
    ),
    ConversionOption(
      title: 'PDF to Excel',
      subtitle: 'Excel',
      format: ExportFormat.excel,
      sourceKind: DocumentKind.pdf,
    ),
    ConversionOption(
      title: 'PDF to PowerPoint',
      subtitle: 'PowerPoint',
      format: ExportFormat.powerPoint,
      sourceKind: DocumentKind.pdf,
    ),
    ConversionOption(
      title: 'Word to PDF',
      subtitle: 'PDF',
      format: ExportFormat.pdf,
      sourceKind: DocumentKind.word,
    ),
    ConversionOption(
      title: 'Word to Excel',
      subtitle: 'Excel',
      format: ExportFormat.excel,
      sourceKind: DocumentKind.word,
    ),
    ConversionOption(
      title: 'Word to PowerPoint',
      subtitle: 'PowerPoint',
      format: ExportFormat.powerPoint,
      sourceKind: DocumentKind.word,
    ),
    ConversionOption(
      title: 'Excel to PDF',
      subtitle: 'PDF',
      format: ExportFormat.pdf,
      sourceKind: DocumentKind.spreadsheet,
    ),
    ConversionOption(
      title: 'Excel to Word',
      subtitle: 'Word',
      format: ExportFormat.word,
      sourceKind: DocumentKind.spreadsheet,
    ),
    ConversionOption(
      title: 'Excel to PowerPoint',
      subtitle: 'PowerPoint',
      format: ExportFormat.powerPoint,
      sourceKind: DocumentKind.spreadsheet,
    ),
    ConversionOption(
      title: 'PowerPoint to PDF',
      subtitle: 'PDF',
      format: ExportFormat.pdf,
      sourceKind: DocumentKind.presentation,
    ),
    ConversionOption(
      title: 'PowerPoint to Word',
      subtitle: 'Word',
      format: ExportFormat.word,
      sourceKind: DocumentKind.presentation,
    ),
    ConversionOption(
      title: 'PowerPoint to Excel',
      subtitle: 'Excel',
      format: ExportFormat.excel,
      sourceKind: DocumentKind.presentation,
    ),
    ConversionOption(
      title: 'Pages to ZIP',
      subtitle: 'ZIP',
      format: ExportFormat.zip,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final activePage = controller.activePage;

    return ResponsiveListView(
      children: [
        const SectionTitle(
          icon: Icons.swap_horiz,
          title: 'Convert',
          subtitle: 'Review each file before creating the final document.',
        ),
        const SizedBox(height: 12),
        _ActiveDocumentCard(controller: controller),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : () => controller.importFiles(),
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Open document'),
            ),
            OutlinedButton.icon(
              onPressed: activePage == null
                  ? null
                  : () => _openDocumentViewer(context, activePage),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('View document'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isBusy || controller.batch.pages.isEmpty
                  ? null
                  : controller.mergeWorkspaceToPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Merge pages to PDF'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isBusy || activePage == null
                  ? null
                  : controller.compressActivePageToPdf,
              icon: const Icon(Icons.compress),
              label: const Text('Compress page PDF'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisExtent: 146,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            final isWorking = controller.isBusy;

            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: isWorking
                    ? null
                    : () => _startConversion(context, option),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _exportIcon(option.format),
                            color: isWorking ? Colors.black38 : SapTheme.black,
                          ),
                          const Spacer(),
                          Text(
                            option.subtitle,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: isWorking
                                      ? Colors.black45
                                      : SapTheme.black,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        option.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: isWorking ? Colors.black45 : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isWorking ? 'Working...' : conversionInputLabel(option),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static String conversionInputLabel(ConversionOption option) {
    final sourceKind = option.sourceKind;
    if (sourceKind == null) {
      return 'Upload document';
    }

    return 'Upload ${documentKindLabel(sourceKind).toLowerCase()}';
  }

  Future<void> _startConversion(
    BuildContext context,
    ConversionOption option,
  ) async {
    final pages = await controller.prepareConversion(option);
    if (!context.mounted || pages.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversionPreviewScreen(
          controller: controller,
          option: option,
          pages: pages,
        ),
      ),
    );
  }

  void _openDocumentViewer(BuildContext context, ScanPage page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DocumentViewerScreen(page: page)),
    );
  }
}

class _ActiveDocumentCard extends StatelessWidget {
  const _ActiveDocumentCard({required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    final page = controller.activePage;
    if (page == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.insert_drive_file_outlined),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Open a PDF, Word, Excel, PowerPoint, image, or text file when you are ready.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(_kindIcon(page.kind), color: SapTheme.black),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${documentKindLabel(page.kind)} - ${_formatBytes(page.sizeBytes)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConversionPreviewScreen extends StatelessWidget {
  const ConversionPreviewScreen({
    super.key,
    required this.controller,
    required this.option,
    required this.pages,
  });

  final ScannerController controller;
  final ConversionOption option;
  final List<ScanPage> pages;

  @override
  Widget build(BuildContext context) {
    final firstPage = pages.first;
    final content = _previewText(firstPage);
    final target = option.subtitle;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              option.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: FilledButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () async {
                        await controller.convertPreparedFiles(option, pages);
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.notice.isEmpty
                                  ? 'Conversion complete'
                                  : controller.notice,
                            ),
                          ),
                        );
                      },
                icon: controller.isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_done_outlined),
                label: Text(
                  controller.isBusy ? 'Converting...' : 'Convert to $target',
                ),
              ),
            ),
          ),
          body: ResponsiveListView(
            maxWidth: 920,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: SapTheme.black,
                        foregroundColor: Colors.white,
                        child: Icon(_exportIcon(option.format)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pages.length == 1
                                  ? firstPage.title
                                  : '${pages.length} files selected',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${documentKindLabel(firstPage.kind)} to $target',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ActivePagePreview(page: firstPage),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File preview',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 180),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAF9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFDDE5E1)),
                        ),
                        child: SelectableText(
                          content,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (pages.length > 1) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected files',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final page in pages)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(_kindIcon(page.kind)),
                            title: Text(
                              page.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(_formatBytes(page.sizeBytes)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class DocumentViewerScreen extends StatelessWidget {
  const DocumentViewerScreen({super.key, required this.page});

  final ScanPage page;

  @override
  Widget build(BuildContext context) {
    final content = _previewText(page);

    return Scaffold(
      appBar: AppBar(
        title: Text(page.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ResponsiveListView(
        maxWidth: 920,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: SapTheme.black,
                        foregroundColor: Colors.white,
                        child: Icon(_kindIcon(page.kind)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              page.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${documentKindLabel(page.kind)} - ${_formatBytes(page.sizeBytes)}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(page.folder)),
                      for (final tag in page.tags) Chip(label: Text(tag)),
                      if (page.favorite) const Chip(label: Text('Favorite')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          PageVisualPreview(page: page, minHeight: 280),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Document preview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 260),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAF9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDDE5E1)),
                    ),
                    child: SelectableText(
                      content,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FeatureGrid(
            items: [
              FeatureItem('Type', documentKindLabel(page.kind)),
              FeatureItem(
                'Original file',
                page.fileName.isEmpty ? page.title : page.fileName,
              ),
              FeatureItem('Size', _formatBytes(page.sizeBytes)),
              FeatureItem('Folder', page.folder),
            ],
          ),
        ],
      ),
    );
  }
}

class CompressWorkspace extends StatelessWidget {
  const CompressWorkspace({super.key, required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ResponsiveListView(
      children: [
        const SectionTitle(
          icon: Icons.compress,
          title: 'Compression studio',
          subtitle: 'Reduce file size while keeping files clean and shareable.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : () => controller.compress(CompressionPreset.balanced),
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Compress files'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : () => controller.compressFolder(CompressionPreset.maximum),
              icon: const Icon(Icons.folder_zip_outlined),
              label: const Text('Compress folder'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final preset in CompressionPreset.values)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: SapTheme.black,
                foregroundColor: Colors.white,
                child: Text('${(preset.targetSavings * 100).round()}'),
              ),
              title: Text(preset.name),
              subtitle: Text(preset.description),
              trailing: const Icon(Icons.play_arrow_rounded),
              onTap: controller.isBusy
                  ? null
                  : () => controller.compress(preset),
            ),
          ),
      ],
    );
  }
}

class SettingsWorkspace extends StatelessWidget {
  const SettingsWorkspace({super.key, required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ResponsiveListView(
      children: [
        SectionTitle(
          icon: Icons.verified_user_outlined,
          title: controller.t('releaseReadiness'),
          subtitle: controller.t('releaseSubtitle'),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: DropdownButtonFormField<AppLanguage>(
              initialValue: controller.language,
              decoration: InputDecoration(
                labelText: controller.t('language'),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final language in appLanguageMenuOrder)
                  DropdownMenuItem(
                    value: language,
                    child: Text(languageLabel(language)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  controller.updateLanguage(value);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _NotificationSettingsCard(controller: controller),
        const SizedBox(height: 12),
        MetricStrip(controller: controller),
        const SizedBox(height: 12),
        FeatureGrid(
          items: [
            FeatureItem(
              controller.t('languages'),
              controller.t('languageCoverage'),
            ),
            FeatureItem(controller.t('rtlReady'), controller.t('rtlCoverage')),
            FeatureItem(
              controller.t('localPrivacy'),
              controller.t('localPrivacyDetail'),
            ),
            FeatureItem(controller.t('ocr'), controller.t('ocrDetail')),
            FeatureItem(
              controller.t('officeExports'),
              controller.t('officeExportsDetail'),
            ),
            FeatureItem(
              'Install-ready',
              'Prepared for mobile packaging and web deployment',
            ),
          ],
        ),
      ],
    );
  }
}

class _NotificationSettingsCard extends StatelessWidget {
  const _NotificationSettingsCard({required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.notificationState;
    final status = state == null
        ? 'Not enabled yet'
        : state.granted
        ? 'Enabled'
        : state.message;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(status)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : controller.enableNotifications,
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('Enable'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : controller.sendTestNotification,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send test'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MetricStrip extends StatelessWidget {
  const MetricStrip({super.key, required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    return FeatureGrid(
      items: [
        FeatureItem('Pages', '${controller.batch.pages.length}'),
        FeatureItem('Storage', _formatBytes(controller.batch.totalSizeBytes)),
        FeatureItem(
          'Estimated export',
          _formatBytes(controller.estimatedExportSize),
        ),
        FeatureItem('Language', languageLabel(controller.language)),
      ],
    );
  }
}

class SapMark extends StatelessWidget {
  const SapMark({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/branding/sapscanner_logo.png',
        width: 46,
        height: 46,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => const _FallbackSapMark(),
      ),
    );
  }
}

class _FallbackSapMark extends StatelessWidget {
  const _FallbackSapMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SapTheme.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const SizedBox.square(
        dimension: 46,
        child: Center(
          child: Text(
            'SAP',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class ScanPreviewFrame extends StatelessWidget {
  const ScanPreviewFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SapTheme.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 180,
                height: 230,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 18),
                  ],
                ),
                child: const Icon(Icons.description_outlined, size: 64),
              ),
            ),
            const Positioned(left: 22, top: 22, child: CornerGuide()),
            const Positioned(
              right: 22,
              top: 22,
              child: CornerGuide(flipX: true),
            ),
            const Positioned(
              left: 22,
              bottom: 22,
              child: CornerGuide(flipY: true),
            ),
            const Positioned(
              right: 22,
              bottom: 22,
              child: CornerGuide(flipX: true, flipY: true),
            ),
          ],
        ),
      ),
    );
  }
}

class CornerGuide extends StatelessWidget {
  const CornerGuide({super.key, this.flipX = false, this.flipY = false});

  final bool flipX;
  final bool flipY;

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: flipX,
      flipY: flipY,
      child: const SizedBox(
        width: 34,
        height: 34,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: SapTheme.yellow, width: 4),
              top: BorderSide(color: SapTheme.yellow, width: 4),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: SapTheme.black),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class FeatureGrid extends StatelessWidget {
  const FeatureGrid({super.key, required this.items});

  final List<FeatureItem> items;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final cardHeight = textScale > 1.15 ? 138.0 : 118.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: cardHeight,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  item.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FeatureItem {
  const FeatureItem(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1D395)),
      ),
      child: Text(message),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.black45),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

IconData _kindIcon(DocumentKind kind) {
  return switch (kind) {
    DocumentKind.image => Icons.image_outlined,
    DocumentKind.pdf => Icons.picture_as_pdf_outlined,
    DocumentKind.word => Icons.article_outlined,
    DocumentKind.spreadsheet => Icons.table_chart_outlined,
    DocumentKind.presentation => Icons.slideshow_outlined,
    DocumentKind.text => Icons.text_snippet_outlined,
    DocumentKind.video => Icons.video_file_outlined,
    DocumentKind.archive => Icons.folder_zip_outlined,
    DocumentKind.unknown => Icons.insert_drive_file_outlined,
  };
}

IconData _exportIcon(ExportFormat format) {
  return switch (format) {
    ExportFormat.pdf => Icons.picture_as_pdf_outlined,
    ExportFormat.jpg => Icons.image_outlined,
    ExportFormat.text => Icons.text_snippet_outlined,
    ExportFormat.word => Icons.article_outlined,
    ExportFormat.excel => Icons.table_chart_outlined,
    ExportFormat.powerPoint => Icons.slideshow_outlined,
    ExportFormat.zip => Icons.folder_zip_outlined,
    ExportFormat.json => Icons.data_object,
  };
}

String _previewText(ScanPage page) {
  final text = [
    page.ocrText,
    page.textPreview,
    page.notes,
  ].where((value) => value.trim().isNotEmpty).join('\n\n');
  return text.isEmpty
      ? page.fileName.isEmpty
            ? 'Preview will appear when text is available.'
            : page.fileName
      : text;
}

String _formatBytes(int value) {
  if (value < 1024) {
    return '$value B';
  }
  if (value < 1024 * 1024) {
    return '${(value / 1024).toStringAsFixed(1)} KB';
  }
  return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
}
