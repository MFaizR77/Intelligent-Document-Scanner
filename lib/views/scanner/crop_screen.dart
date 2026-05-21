// lib/views/scanner/crop_screen.dart
//
// Layar koreksi 4 titik manual setelah capture.
// Output: CapturePayload baru dengan [suggestedCornersImage] terisi 4 titik
// dalam koordinat IMAGE pixel (raw file).
//
// Flow konversi koordinat:
//   image-coord (pixel pada file)  ←→  screen-coord (offset di Stack)
//
// Layout: gambar di-fit "contain" ke dalam viewport (letterbox), lalu kita
// hitung rect-nya dan rasio scale. Konversi:
//   screen.x = imageRect.left + imagePoint.x * scale
//   image.x  = (screen.x - imageRect.left) / scale
//
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/models/capture_payload.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';
import 'package:tugasbesar_pcd/widgets/scanner/draggable_corner.dart';

class CropScreen extends StatefulWidget {
  const CropScreen({super.key, required this.payload});

  final CapturePayload payload;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  ui.Image? _decoded;
  Size? _imageSize;
  bool _decoding = true;
  String? _error;

  /// 4 titik dalam koordinat IMAGE pixel (TL, TR, BR, BL).
  List<Offset> _cornersImage = const [];

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.payload.rawImagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;

      final img = frame.image;
      final size = Size(img.width.toDouble(), img.height.toDouble());

      // Inisialisasi korner: kalau payload bawa hint dari realtime detection,
      // konversi dari koordinat ternormalisasi → image pixel. Kalau tidak,
      // pakai default rectangle 80% di tengah.
      final initial = _initialCorners(
        size,
        widget.payload.suggestedCornersImage,
      );

      setState(() {
        _decoded = img;
        _imageSize = size;
        _cornersImage = initial;
        _decoding = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal load gambar: $e';
        _decoding = false;
      });
    }
  }

  /// Tentukan 4 titik awal di koordinat image pixel.
  ///
  /// Hint dari ScannerController berupa Offset(0..1, 0..1) terhadap UKURAN
  /// FRAME STREAM (bukan ukuran foto hi-res). Karena rasio biasanya sama,
  /// kita pakai rasio itu langsung untuk memetakan ke ukuran foto. Kalau
  /// rasio berbeda jauh / tidak ada hint, fallback ke rectangle 80%.
  List<Offset> _initialCorners(Size imgSize, List<Offset>? hint) {
    if (hint != null && hint.length == 4) {
      // Hint dianggap koordinat ternormalisasi 0..1.
      final corners = hint
          .map((o) => Offset(o.dx * imgSize.width, o.dy * imgSize.height))
          .toList();
      // Validasi cepat: pastikan dalam bound dan luas masuk akal.
      final inside = corners.every(
        (c) =>
            c.dx >= 0 &&
            c.dx <= imgSize.width &&
            c.dy >= 0 &&
            c.dy <= imgSize.height,
      );
      if (inside) return corners;
    }
    // Default: rectangle 80% di tengah, urutan TL-TR-BR-BL.
    final w = imgSize.width;
    final h = imgSize.height;
    final dx = w * 0.10;
    final dy = h * 0.10;
    return <Offset>[
      Offset(dx, dy),
      Offset(w - dx, dy),
      Offset(w - dx, h - dy),
      Offset(dx, h - dy),
    ];
  }

  /// Hitung rect dimana gambar akan tampil (BoxFit.contain) dalam viewport.
  Rect _computeImageRect(Size viewport, Size image) {
    final scale =
        (viewport.width / image.width < viewport.height / image.height)
        ? viewport.width / image.width
        : viewport.height / image.height;
    final w = image.width * scale;
    final h = image.height * scale;
    final left = (viewport.width - w) / 2;
    final top = (viewport.height - h) / 2;
    return Rect.fromLTWH(left, top, w, h);
  }

  Offset _imageToScreen(Offset p, Rect rect, Size image) {
    final sx = rect.width / image.width;
    final sy = rect.height / image.height;
    return Offset(rect.left + p.dx * sx, rect.top + p.dy * sy);
  }

  Offset _screenToImage(Offset s, Rect rect, Size image) {
    final sx = rect.width / image.width;
    final sy = rect.height / image.height;
    return Offset((s.dx - rect.left) / sx, (s.dy - rect.top) / sy);
  }

  void _onCornerDrag(int idx, Offset newScreenPos, Rect rect, Size image) {
    // Clamp screen position ke dalam image rect supaya korner tidak keluar.
    final clamped = Offset(
      newScreenPos.dx.clamp(rect.left, rect.right),
      newScreenPos.dy.clamp(rect.top, rect.bottom),
    );
    final newImagePoint = _screenToImage(clamped, rect, image);
    setState(() {
      final list = List<Offset>.from(_cornersImage);
      list[idx] = newImagePoint;
      _cornersImage = list;
    });
  }

  void _confirm() {
    final updated = CapturePayload(
      rawImagePath: widget.payload.rawImagePath,
      documentPlan: widget.payload.documentPlan,
      suggestedCornersImage: List<Offset>.unmodifiable(_cornersImage),
      imageWidth: _imageSize?.width.round(),
      imageHeight: _imageSize?.height.round(),
    );
    Navigator.of(context).pop(updated);
  }

  void _resetCorners() {
    if (_imageSize != null) {
      setState(() {
        _cornersImage = _initialCorners(_imageSize!, null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Sesuaikan Sudut',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset',
            onPressed: _resetCorners,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: AppPrimaryButton(
              label: 'Lanjutkan',
              icon: Icons.check,
              onPressed: _decoded == null ? () {} : _confirm,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_decoding) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final image = _imageSize!;
    return LayoutBuilder(
      builder: (context, c) {
        final viewport = Size(c.maxWidth, c.maxHeight);
        final rect = _computeImageRect(viewport, image);

        // Build polygon path di koordinat layar.
        final screenPoints = _cornersImage
            .map((p) => _imageToScreen(p, rect, image))
            .toList();

        return Stack(
          children: [
            // Gambar
            Positioned.fromRect(
              rect: rect,
              child: Image.file(
                File(widget.payload.rawImagePath),
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
            // Polygon overlay
            Positioned.fromRect(
              rect: rect,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PolygonPainter(
                    pointsScreenLocal: screenPoints
                        .map((p) => p - rect.topLeft)
                        .toList(),
                  ),
                ),
              ),
            ),
            // Handle
            for (var i = 0; i < screenPoints.length; i++)
              DraggableCornerHandle(
                position: screenPoints[i],
                onDrag: (newPos) => _onCornerDrag(i, newPos, rect, image),
              ),
            // Hint label
            Positioned(
              left: 24,
              right: 24,
              bottom: 12,
              child: Text(
                'Geser 4 titik untuk menyesuaikan tepi dokumen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PolygonPainter extends CustomPainter {
  _PolygonPainter({required this.pointsScreenLocal});

  final List<Offset> pointsScreenLocal;

  @override
  void paint(Canvas canvas, Size size) {
    if (pointsScreenLocal.length != 4) return;
    final path = Path()
      ..moveTo(pointsScreenLocal.first.dx, pointsScreenLocal.first.dy);
    for (final p in pointsScreenLocal.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    final fill = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _PolygonPainter oldDelegate) =>
      oldDelegate.pointsScreenLocal != pointsScreenLocal;
}
