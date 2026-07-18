# Migration Plan

## Phase 1 - Native Foundation

- Create Android and iOS Flutter platform folders.
- Add app icons, splash screen, permissions, and app signing placeholders.
- Connect MVC layers: models, controllers, services, and views.
- Keep all processing local by default.

## Phase 2 - Scanner Core

- Android: use ML Kit document scanner for automatic capture, edge detection, crop, filters, PDF/JPEG output.
- iOS: add VisionKit document scanner through a Swift platform channel.
- Add manual camera mode with live scan guides, torch, grid, auto-capture, and batch scan.
- Add manual crop handles and perspective correction.

## Phase 3 - Professional Documents

- PDF merge, split, reorder, rotate, compress, watermark, page numbers, lock/unlock where locally possible.
- Image to PDF, PDF to images, OCR text layer, searchable PDF.
- Word, Excel, and PowerPoint export from OCR/layout data.
- Local import previews for Office files where possible.

## Phase 4 - Compression

- Photo compression with size estimate and quality presets.
- Video compression through platform channels, because serious video compression should use native codecs.
- Folder compression workflow for user-selected files.
- Safe savings reporting: never claim 80% unless the output actually achieves it.

## Phase 5 - International Polish

- English, Luganda, Swahili, French, and Spanish.
- Offline-first storage.
- Accessibility audit.
- Privacy policy and local-processing data statement.
- Play Store and App Store release setup.
