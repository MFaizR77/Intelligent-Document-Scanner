import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../services/image_processing/edge_detection.dart';
import '../services/image_processing/enhancement.dart';
import '../services/image_processing/perspective_transform.dart';
import '../utils/image_utils.dart';

/// Manages a dedicated [FlutterIsolate] that runs the OpenCV processing
/// pipeline off the main thread to keep the camera preview at 60 fps.
@pragma('vm:entry-point')
class IsolateManager {
  FlutterIsolate? _backgroundIsolate;
  ReceivePort? _mainPort;
  SendPort? _backgroundSendPort;
  StreamSubscription<dynamic>? _mainPortSubscription;
  bool _isListening = false;
  bool _isDisposed = false;

  bool get isReady => _backgroundSendPort != null;

  /// Spawns the background isolate and wires the bidirectional [SendPort] channel.
  ///
  /// [onResult] is called on the main isolate whenever the background isolate
  /// returns a processing result.
  Future<void> spawnProcessingIsolate(
    Function(Map<String, dynamic>) onResult,
  ) async {
    if (_isListening || _isDisposed) return;

    _mainPort = ReceivePort();
    _backgroundIsolate = await FlutterIsolate.spawn(
      _backgroundTaskEntryPoint,
      _mainPort!.sendPort,
    );

    _isListening = true;
    _mainPortSubscription = _mainPort!.listen((message) {
      if (_isDisposed) return;
      if (message is SendPort) {
        _backgroundSendPort = message;
      } else if (message is Map) {
        onResult(Map<String, dynamic>.from(message));
      }
    });
  }

  /// Serialises [image] and forwards it to the background isolate for processing.
  ///
  /// [sensorOrientation] (degrees: 0, 90, 180, 270) is forwarded so the isolate
  /// can derive the correct rotation code without accessing platform APIs.
  /// Returns `false` if the isolate is not ready or already disposed.
  bool processFrame(CameraImage image, {required int sensorOrientation}) {
    final sendPort = _backgroundSendPort;
    if (_isDisposed || sendPort == null || image.planes.isEmpty) return false;

    final yPlane = image.planes.first;
    sendPort.send(<String, dynamic>{
      'type': 'frame',
      'width': image.width,
      'height': image.height,
      'bytesPerRow': yPlane.bytesPerRow,
      'sensorOrientation': sensorOrientation,
      'bytes': TransferableTypedData.fromList([Uint8List.fromList(yPlane.bytes)]),
    });
    return true;
  }

  @pragma('vm:entry-point')
  static void _backgroundTaskEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is Map && message['type'] == 'frame') {
        mainSendPort.send(_processFrame(Map<String, dynamic>.from(message)));
      } else if (message is Map && message['type'] == 'dispose') {
        receivePort.close();
      }
    });
  }

  static Map<String, dynamic> _processFrame(Map<String, dynamic> frame) {
    cv.Mat? mat;
    cv.Mat? warped;
    cv.Mat? enhanced;
    // Declared outside try so that detectionResult['rotatedMat'] can be
    // disposed in the finally block regardless of where an exception occurs.
    Map<String, dynamic>? detectionResult;

    try {
      final width = frame['width'] as int;
      final height = frame['height'] as int;
      final bytesPerRow = frame['bytesPerRow'] as int;
      final sensorOrientation = frame['sensorOrientation'] as int? ?? 90;
      final bytes = (frame['bytes'] as TransferableTypedData).materialize().asUint8List();

      // Remove Android's row-stride padding so the Mat is packed correctly.
      final matBytes = bytesPerRow == width
          ? bytes
          : _packYPlaneBytes(bytes, width, height, bytesPerRow);

      mat = cv.Mat.fromList(height, width, cv.MatType.CV_8UC1, matBytes);

      // Map sensor orientation to a cv.rotate constant.
      // Rotation is intentionally delegated to EdgeDetectionService and applied
      // *after* downscaling, so only a ~500 px matrix is rotated.
      final int? rotateCode = switch (sensorOrientation) {
        90  => cv.ROTATE_90_CLOCKWISE,
        270 => cv.ROTATE_90_COUNTERCLOCKWISE,
        180 => cv.ROTATE_180,
        _   => null,
      };

      detectionResult = EdgeDetectionService.findDocumentCorners(
        mat,
        rotateCode: rotateCode,
      );

      final cornersList = detectionResult['corners'] as List;
      final isPerfect = detectionResult['isPerfect'] as bool? ?? false;
      final corners = cornersList
          .map((m) => m is Map
              ? cv.Point((m['x'] as num).toInt(), (m['y'] as num).toInt())
              : cv.Point(0, 0))
          .toList();

      // Dokumen dianggap "ready" hanya saat detector yakin. Kalau isPerfect
      // false tapi cornersList tidak kosong, itu kandidat tentative — UI
      // akan menggambarnya merah supaya user tahu detector sedang melihat
      // sesuatu, tapi belum boleh trigger auto-capture.
      final hasDocument = isPerfect;
      final hasCornersToDraw = cornersList.isNotEmpty;
      // Dimensions of the frame after rotation — used to normalise corners.
      final processedWidth  = detectionResult['processedWidth']  as int? ?? mat.cols;
      final processedHeight = detectionResult['processedHeight'] as int? ?? mat.rows;

      final confidence = hasDocument
          ? _polygonArea(corners) / math.max(1, processedWidth * processedHeight)
          : 0.0;

      Uint8List? previewBytes;
      if (hasDocument) {
        try {
          // EdgeDetectionService returns the full-resolution rotated Mat so
          // that PerspectiveTransformService can sample at native quality.
          final rotatedForTransform = detectionResult['rotatedMat'] as cv.Mat?;
          if (rotatedForTransform != null) {
            warped   = PerspectiveTransformService.applyPerspectiveTransform(rotatedForTransform, corners);
            enhanced = EnhancementService.enhanceDocument(warped);
            previewBytes = ImageUtils.convertMatToUint8List(enhanced);
          }
        } catch (_) {
          // Preview is optional; continue without it if the transform fails.
        }
      }

      // Return corners normalised to the [0.0, 1.0] ratio space for the UI.
      // Status "ready" hanya kalau detector yakin (isPerfect). Kalau ada
      // korner tentative, kirim status "searching" tapi tetap dengan korner
      // supaya overlay merah tergambar sebagai feedback.
      return <String, dynamic>{
        'corners': hasCornersToDraw
            ? cornersList
                .map((m) => m is Map
                    ? <double>[
                        (m['x'] as num).toDouble() / processedWidth,
                        (m['y'] as num).toDouble() / processedHeight,
                      ]
                    : <double>[0.0, 0.0])
                .toList()
            : <List<double>>[],
        'imageWidth':  processedWidth,
        'imageHeight': processedHeight,
        'status':     hasDocument ? 'ready' : 'searching',
        'confidence': confidence.clamp(0.0, 1.0),
        'preview':    previewBytes,
      };
    } catch (error) {
      return <String, dynamic>{
        'corners':    <List<double>>[],
        'status':     'error',
        'confidence': 0.0,
        'error':      error.toString(),
      };
    } finally {
      enhanced?.dispose();
      warped?.dispose();
      // Dispose the full-res rotated Mat whose ownership was transferred from
      // EdgeDetectionService.
      (detectionResult?['rotatedMat'] as cv.Mat?)?.dispose();
      mat?.dispose();
    }
  }

  /// Computes the area of an arbitrary polygon via the shoelace formula.
  static double _polygonArea(List<cv.Point> points) {
    if (points.length < 3) return 0;
    double area = 0;
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      area += (current.x * next.y) - (next.x * current.y);
    }
    return area.abs() / 2;
  }

  /// Strips the row-stride padding that Android adds to YUV plane buffers.
  static Uint8List _packYPlaneBytes(
    Uint8List bytes,
    int width,
    int height,
    int bytesPerRow,
  ) {
    final packed = Uint8List(width * height);
    for (var row = 0; row < height; row++) {
      packed.setRange(row * width, row * width + width, bytes, row * bytesPerRow);
    }
    return packed;
  }

  /// Terminates the background isolate and releases all ports.
  void dispose() {
    _isDisposed = true;
    _backgroundSendPort?.send(<String, dynamic>{'type': 'dispose'});
    _backgroundIsolate?.kill();
    _mainPortSubscription?.cancel();
    _mainPort?.close();
    _backgroundSendPort = null;
    _backgroundIsolate = null;
    _mainPort = null;
    _mainPortSubscription = null;
    _isListening = false;
  }
}
