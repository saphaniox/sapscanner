import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as image;

void main() {
  final logo = _drawLogo();
  _writePng('assets/branding/sapscanner-logo.png', logo);
  _writePng('web/favicon.png', image.copyResize(logo, width: 64, height: 64));
  _writePng('web/icons/Icon-192.png', _iconCanvas(logo, 192, maskable: false));
  _writePng('web/icons/Icon-512.png', _iconCanvas(logo, 512, maskable: false));
  _writePng(
    'web/icons/Icon-maskable-192.png',
    _iconCanvas(logo, 192, maskable: true),
  );
  _writePng(
    'web/icons/Icon-maskable-512.png',
    _iconCanvas(logo, 512, maskable: true),
  );
  _writePng(
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
    _iconCanvas(logo, 48, maskable: true),
  );
  _writePng(
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
    _iconCanvas(logo, 72, maskable: true),
  );
  _writePng(
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
    _iconCanvas(logo, 96, maskable: true),
  );
  _writePng(
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
    _iconCanvas(logo, 144, maskable: true),
  );
  _writePng(
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    _iconCanvas(logo, 192, maskable: true),
  );
}

image.Image _drawLogo() {
  final canvas = image.Image(width: 1024, height: 1024, numChannels: 4);
  image.fill(canvas, color: _color(255, 255, 255, 0));

  image.fillCircle(
    canvas,
    x: 512,
    y: 430,
    radius: 360,
    color: _color(255, 255, 255),
    antialias: true,
  );
  _arc(canvas, 512, 430, 350, -152, -28, _color(16, 16, 16), 38);
  _arc(canvas, 512, 430, 352, 128, 254, _color(252, 220, 4), 38);
  _arc(canvas, 512, 430, 352, 18, 116, _color(217, 0, 0), 28);
  _arc(canvas, 512, 430, 320, -72, -26, _color(16, 16, 16), 10);
  _arc(canvas, 512, 430, 330, 74, 112, _color(217, 0, 0), 10);

  _shadow(canvas, 245, 628, 610, 120, 18);
  image.fillPolygon(
    canvas,
    vertices: [
      image.Point(250, 574),
      image.Point(780, 525),
      image.Point(870, 664),
      image.Point(335, 735),
    ],
    color: _color(22, 22, 22),
  );
  image.fillPolygon(
    canvas,
    vertices: [
      image.Point(302, 584),
      image.Point(750, 546),
      image.Point(802, 640),
      image.Point(365, 690),
    ],
    color: _color(58, 60, 60),
  );
  image.fillPolygon(
    canvas,
    vertices: [
      image.Point(328, 592),
      image.Point(726, 560),
      image.Point(768, 626),
      image.Point(384, 668),
    ],
    color: _color(240, 242, 241),
  );

  image.fillPolygon(
    canvas,
    vertices: [
      image.Point(310, 310),
      image.Point(710, 268),
      image.Point(760, 350),
      image.Point(378, 410),
    ],
    color: _color(20, 20, 20),
  );
  image.fillPolygon(
    canvas,
    vertices: [
      image.Point(360, 333),
      image.Point(687, 302),
      image.Point(715, 344),
      image.Point(390, 390),
    ],
    color: _color(225, 228, 227),
  );
  image.drawLine(
    canvas,
    x1: 330,
    y1: 414,
    x2: 385,
    y2: 584,
    color: _color(9, 9, 9),
    thickness: 18,
    antialias: true,
  );

  _paper(canvas);
  image.fillCircle(
    canvas,
    x: 695,
    y: 643,
    radius: 12,
    color: _color(65, 225, 26),
  );
  image.fillRect(
    canvas,
    x1: 738,
    y1: 622,
    x2: 790,
    y2: 652,
    color: _color(35, 35, 35),
    radius: 12,
  );
  image.fillRect(
    canvas,
    x1: 800,
    y1: 616,
    x2: 848,
    y2: 644,
    color: _color(35, 35, 35),
    radius: 12,
  );
  image.drawLine(
    canvas,
    x1: 752,
    y1: 637,
    x2: 770,
    y2: 635,
    color: _color(230, 230, 230),
    thickness: 4,
    antialias: true,
  );
  image.drawLine(
    canvas,
    x1: 815,
    y1: 630,
    x2: 833,
    y2: 628,
    color: _color(230, 230, 230),
    thickness: 4,
    antialias: true,
  );

  _formatTile(canvas, 78, 800, _color(217, 0, 0), 'PDF', 'A');
  _formatTile(canvas, 250, 800, _color(12, 98, 181), 'DOCX', 'W');
  _formatTile(canvas, 422, 800, _color(0, 135, 61), 'XLSX', 'X');
  _formatTile(canvas, 594, 800, _color(230, 88, 20), 'PPTX', 'P');
  _formatTile(canvas, 766, 800, _color(252, 196, 24), 'ZIP', 'Z');

  return canvas;
}

void _paper(image.Image canvas) {
  image.fillPolygon(
    canvas,
    vertices: [
      image.Point(452, 365),
      image.Point(620, 338),
      image.Point(718, 628),
      image.Point(520, 666),
    ],
    color: _color(190, 190, 190, 120),
  );
  image.fillPolygon(
    canvas,
    vertices: [
      image.Point(430, 340),
      image.Point(622, 315),
      image.Point(710, 605),
      image.Point(515, 635),
    ],
    color: _color(255, 255, 255),
  );
  image.fillPolygon(
    canvas,
    vertices: [
      image.Point(470, 440),
      image.Point(515, 505),
      image.Point(562, 457),
      image.Point(612, 532),
      image.Point(492, 552),
    ],
    color: _color(86, 89, 89),
  );
  image.drawLine(
    canvas,
    x1: 458,
    y1: 376,
    x2: 520,
    y2: 369,
    color: _color(217, 0, 0),
    thickness: 20,
  );
  image.drawLine(
    canvas,
    x1: 565,
    y1: 373,
    x2: 635,
    y2: 365,
    color: _color(158, 158, 158),
    thickness: 5,
  );
  image.drawLine(
    canvas,
    x1: 572,
    y1: 421,
    x2: 655,
    y2: 409,
    color: _color(158, 158, 158),
    thickness: 5,
  );
  image.drawLine(
    canvas,
    x1: 582,
    y1: 464,
    x2: 668,
    y2: 450,
    color: _color(158, 158, 158),
    thickness: 5,
  );
  image.drawLine(
    canvas,
    x1: 594,
    y1: 507,
    x2: 682,
    y2: 492,
    color: _color(158, 158, 158),
    thickness: 5,
  );
  image.drawLine(
    canvas,
    x1: 507,
    y1: 575,
    x2: 672,
    y2: 548,
    color: _color(252, 220, 4),
    thickness: 9,
  );
  image.drawLine(
    canvas,
    x1: 520,
    y1: 612,
    x2: 690,
    y2: 584,
    color: _color(217, 0, 0),
    thickness: 9,
  );
}

void _formatTile(
  image.Image canvas,
  int x,
  int y,
  image.Color color,
  String label,
  String letter,
) {
  image.fillRect(
    canvas,
    x1: x,
    y1: y,
    x2: x + 122,
    y2: y + 154,
    color: color,
    radius: 12,
  );
  image.fillPolygon(
    canvas,
    vertices: [
      image.Point(x + 88, y),
      image.Point(x + 122, y + 34),
      image.Point(x + 122, y),
    ],
    color: _color(255, 255, 255, 150),
  );
  image.drawString(
    canvas,
    letter,
    font: image.arial48,
    x: x + 35,
    y: y + 34,
    color: _color(255, 255, 255),
  );
  image.drawString(
    canvas,
    label,
    font: image.arial24,
    x: x + 27,
    y: y + 110,
    color: _color(255, 255, 255),
  );
}

image.Image _iconCanvas(image.Image logo, int size, {required bool maskable}) {
  final canvas = image.Image(width: size, height: size, numChannels: 4);
  image.fill(canvas, color: _color(255, 255, 255));
  final padding = maskable ? (size * 0.16).round() : (size * 0.06).round();
  final mark = image.copyResize(
    logo,
    width: size - padding * 2,
    height: size - padding * 2,
    interpolation: image.Interpolation.average,
  );
  image.compositeImage(canvas, mark, dstX: padding, dstY: padding);
  return canvas;
}

void _arc(
  image.Image canvas,
  int centerX,
  int centerY,
  int radius,
  double startDegrees,
  double endDegrees,
  image.Color color,
  int thickness,
) {
  final half = thickness / 2;
  final inner = radius - half;
  final outer = radius + half;
  final start = _normalizeDegrees(startDegrees);
  final end = _normalizeDegrees(endDegrees);
  final minX = math.max(0, centerX - outer.ceil());
  final maxX = math.min(canvas.width - 1, centerX + outer.ceil());
  final minY = math.max(0, centerY - outer.ceil());
  final maxY = math.min(canvas.height - 1, centerY + outer.ceil());

  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final dx = x - centerX;
      final dy = y - centerY;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance < inner || distance > outer) {
        continue;
      }

      final angle = _normalizeDegrees(math.atan2(dy, dx) * 180 / math.pi);
      if (_angleInSweep(angle, start, end)) {
        image.drawPixel(canvas, x, y, color);
      }
    }
  }

  final startRadians = _radians(startDegrees);
  final endRadians = _radians(endDegrees);
  image.fillCircle(
    canvas,
    x: (centerX + math.cos(startRadians) * radius).round(),
    y: (centerY + math.sin(startRadians) * radius).round(),
    radius: half.round(),
    color: color,
    antialias: true,
  );
  image.fillCircle(
    canvas,
    x: (centerX + math.cos(endRadians) * radius).round(),
    y: (centerY + math.sin(endRadians) * radius).round(),
    radius: half.round(),
    color: color,
    antialias: true,
  );
}

void _shadow(
  image.Image canvas,
  int x,
  int y,
  int width,
  int height,
  int alpha,
) {
  for (var offset = 0; offset < 18; offset++) {
    image.fillRect(
      canvas,
      x1: x + offset,
      y1: y + offset,
      x2: x + width - offset,
      y2: y + height - offset,
      color: _color(0, 0, 0, math.max(0, alpha - offset)),
      radius: 36,
    );
  }
}

double _radians(double degrees) => degrees * math.pi / 180;

double _normalizeDegrees(double degrees) {
  final normalized = degrees % 360;
  return normalized < 0 ? normalized + 360 : normalized;
}

bool _angleInSweep(double angle, double start, double end) {
  if (start <= end) {
    return angle >= start && angle <= end;
  }

  return angle >= start || angle <= end;
}

image.Color _color(int r, int g, int b, [int a = 255]) {
  return image.ColorRgba8(r, g, b, a);
}

void _writePng(String path, image.Image output) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(image.encodePng(output));
}
