import 'dart:math' as math;
import 'dart:ui';

/// Hand-inked drawing helpers shared by every entity, so the whole game uses
/// one outline weight and one kind of "wobble".
///
/// All jitter is derived from a seed, so a shape looks hand-drawn but stays
/// perfectly still from frame to frame.
class Doodle {
  Doodle._();

  static const Color ink = Color(0xFF22252B);
  static const double outline = 3;

  /// Deterministic pseudo-noise in [-1, 1].
  static double noise(int seed, int i) {
    var h = seed * 374761393 + i * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    h = h ^ (h >> 16);
    return ((h & 0xFFFF) / 0xFFFF) * 2 - 1;
  }

  static final Map<int, Paint> _strokeCache = {};
  static final Map<int, Paint> _fillCache = {};

  /// Cached rounded ink stroke.
  static Paint stroke([Color color = ink, double width = outline]) {
    final key = color.toARGB32() ^ (width * 1000).round() * 31;
    return _strokeCache.putIfAbsent(
      key,
      () => Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Cached solid fill.
  static Paint fill(Color color) =>
      _fillCache.putIfAbsent(color.toARGB32(), () => Paint()..color = color);

  /// A closed blob around [center] with radii [rx]/[ry] and gentle wobble.
  static Path blob(
    Offset center,
    double rx,
    double ry, {
    int seed = 1,
    double wobble = 0.05,
    int segments = 18,
  }) {
    final path = Path();
    for (var i = 0; i <= segments; i++) {
      final a = i / segments * math.pi * 2;
      final j = 1 + noise(seed, i % segments) * wobble;
      final p = Offset(
        center.dx + math.cos(a) * rx * j,
        center.dy + math.sin(a) * ry * j,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  /// A polyline through [points] with small perpendicular jitter.
  static Path line(
    List<Offset> points, {
    int seed = 1,
    double jitter = 1.2,
    bool close = false,
  }) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final q = Offset(
        p.dx + noise(seed, i * 2) * jitter,
        p.dy + noise(seed, i * 2 + 1) * jitter,
      );
      if (i == 0) {
        path.moveTo(q.dx, q.dy);
      } else {
        path.lineTo(q.dx, q.dy);
      }
    }
    if (close) path.close();
    return path;
  }

  /// A slightly wonky rounded rectangle.
  static Path box(Rect r, {double radius = 6, int seed = 1}) {
    final j = radius * 0.25;
    return Path()..addRRect(
      RRect.fromRectAndCorners(
        r.translate(noise(seed, 0) * j * 0.3, noise(seed, 1) * j * 0.3),
        topLeft: Radius.circular(radius + noise(seed, 2) * j),
        topRight: Radius.circular(radius + noise(seed, 3) * j),
        bottomLeft: Radius.circular(radius + noise(seed, 4) * j),
        bottomRight: Radius.circular(radius + noise(seed, 5) * j),
      ),
    );
  }

  /// Fills then outlines [path] in one call.
  static void inked(Canvas canvas, Path path, Color color, {double? width}) {
    canvas.drawPath(path, fill(color));
    canvas.drawPath(path, stroke(ink, width ?? outline));
  }

  /// Draws a wavy horizontal line, used for water and wind.
  static Path wave(
    double x0,
    double x1,
    double y, {
    double amplitude = 4,
    double wavelength = 40,
    double phase = 0,
  }) {
    final path = Path()..moveTo(x0, y);
    for (var x = x0; x <= x1; x += 6) {
      path.lineTo(
        x,
        y + math.sin((x / wavelength) * math.pi * 2 + phase) * amplitude,
      );
    }
    return path;
  }

  /// A puffy cloud made of overlapping blobs.
  static Path cloud(Offset c, double w, {int seed = 3}) {
    final h = w * 0.42;
    final parts = [
      blob(c.translate(-w * 0.28, h * 0.12), w * 0.24, h * 0.42, seed: seed),
      blob(c.translate(0, -h * 0.12), w * 0.3, h * 0.55, seed: seed + 1),
      blob(c.translate(w * 0.28, h * 0.1), w * 0.24, h * 0.4, seed: seed + 2),
      blob(c.translate(0, h * 0.24), w * 0.46, h * 0.3, seed: seed + 3),
    ];
    var out = parts.first;
    for (final p in parts.skip(1)) {
      out = Path.combine(PathOperation.union, out, p);
    }
    return out;
  }

  /// Short diagonal hatching strokes inside [r], for paper and shading.
  static void hatch(
    Canvas canvas,
    Rect r,
    Color color, {
    double gap = 9,
    int seed = 5,
  }) {
    final p = stroke(color, 1.4);
    var i = 0;
    for (var x = r.left; x < r.right; x += gap) {
      final l = 6 + noise(seed, i) * 3;
      final y = r.top + (noise(seed, i + 100) + 1) / 2 * r.height;
      canvas.drawLine(Offset(x, y), Offset(x + l, y - l), p);
      i++;
    }
  }

  /// Comic "pow" star burst.
  static Path burst(Offset c, double r, {int points = 9, int seed = 7}) {
    final pts = <Offset>[];
    for (var i = 0; i < points * 2; i++) {
      final a = i / (points * 2) * math.pi * 2;
      final rr = (i.isEven ? r : r * 0.55) * (1 + noise(seed, i) * 0.12);
      pts.add(Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr));
    }
    return line(pts, seed: seed, jitter: 0, close: true);
  }

  /// Builds a reusable paper-grain picture for a [size] area.
  static Picture paperGrain(
    Size size,
    Color base,
    Color grain, {
    int seed = 11,
  }) {
    final rec = PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Offset.zero & size, fill(base));
    final dot = Paint()..color = grain;
    var i = 0;
    for (var y = 0.0; y < size.height; y += 14) {
      for (var x = 0.0; x < size.width; x += 14) {
        final n = noise(seed, i++);
        if (n > 0.35) {
          c.drawCircle(
            Offset(x + noise(seed, i + 7) * 7, y + noise(seed, i + 9) * 7),
            0.9 + n * 0.6,
            dot,
          );
        }
      }
    }
    // Faint notebook rules.
    final rule = stroke(grain.withValues(alpha: grain.a * 0.6), 1);
    for (var y = 60.0; y < size.height; y += 64) {
      c.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    return rec.endRecording();
  }
}
