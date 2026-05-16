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

@pragma('vm:entry-point')
class IsolateManager {
  FlutterIsolate? _backgroundIsolate;
  ReceivePort? _mainPort;
  SendPort? _backgroundSendPort;
  StreamSubscription<dynamic>? _mainPortSubscription;
  bool _isListening = false;
  bool _isDisposed = false;

  bool get isReady => _backgroundSendPort != null;

  Future<void> spawnProcessingIsolate(
    Function(Map<String, dynamic>) onResult,
  ) async {
    if (_isListening || _isDisposed) {
      return;
    }

    _mainPort = ReceivePort();
    _backgroundIsolate = await FlutterIsolate.spawn(
      _backgroundTaskEntryPoint,
      _mainPort!.sendPort,
    );

    _isListening = true;
    _mainPortSubscription = _mainPort!.listen((message) {
      if (_isDisposed) {
        return;
      }

      if (message is SendPort) {
        _backgroundSendPort = message;
      } else if (message is Map) {
        onResult(Map<String, dynamic>.from(message));
      }
    });
  }

  bool processFrame(CameraImage image) {
    final sendPort = _backgroundSendPort;
    if (_isDisposed || sendPort == null || image.planes.isEmpty) {
      return false;
    }

    final yPlane = image.planes.first;
    sendPort.send(<String, dynamic>{
      'type': 'frame',
      'width': image.width,
      'height': image.height,
      'bytesPerRow': yPlane.bytesPerRow,
      'bytes': TransferableTypedData.fromList([
        Uint8List.fromList(yPlane.bytes),
      ]),
    });
    return true;
  }

  @pragma('vm:entry-point')
  static void _backgroundTaskEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is Map && message['type'] == 'frame') {
        final result = _processFrame(Map<String, dynamic>.from(message));
        mainSendPort.send(result);
      } else if (message is Map && message['type'] == 'dispose') {
        receivePort.close();
      }
    });
  }

  static Map<String, dynamic> _processFrame(Map<String, dynamic> frame) {
    cv.Mat? mat;
    cv.Mat? rotatedMat;
    cv.Mat? warped;
    cv.Mat? enhanced;

    try {
      final width = frame['width'] as int;
      final height = frame['height'] as int;
      final bytesPerRow = frame['bytesPerRow'] as int;
      final bytes = (frame['bytes'] as TransferableTypedData)
          .materialize()
          .asUint8List();

      // Bersihkan padding bytesPerRow bawaan Android agar gambar tidak rusak
      final matBytes = bytesPerRow == width
          ? bytes
          : _packYPlaneBytes(bytes, width, height, bytesPerRow);

      mat = cv.Mat.fromList(height, width, cv.MatType.CV_8UC1, matBytes);

      // Putar gambar 90 derajat supaya OpenCV memproses secara Portrait
      rotatedMat = cv.rotate(mat, cv.ROTATE_90_CLOCKWISE);

      // Jalankan deteksi
      final detectionResult = EdgeDetectionService.findDocumentCorners(
        rotatedMat,
      );
      final cornersList = detectionResult['corners'] as List;
      final isPerfect = detectionResult['isPerfect'] as bool? ?? false;
      final corners = cornersList
          .map(
            (m) => m is Map
                ? cv.Point((m['x'] as num).toInt(), (m['y'] as num).toInt())
                : cv.Point(0, 0),
          )
          .toList();

      final hasDocument = isPerfect;
      final rotatedWidth = rotatedMat.cols;
      final rotatedHeight = rotatedMat.rows;

      final confidence = hasDocument
          ? _polygonArea(corners) / math.max(1, rotatedWidth * rotatedHeight)
          : 0.0;

      Uint8List? previewBytes;
      if (hasDocument) {
        // Abaikan error di tahap Transform & Enhancement jika file service-nya belum sempurna
        try {
          warped = PerspectiveTransformService.applyPerspectiveTransform(
            rotatedMat,
            corners,
          );
          enhanced = EnhancementService.enhanceDocument(warped);
          previewBytes = ImageUtils.convertMatToUint8List(enhanced);
        } catch (_) {
          // Biarkan previewBytes null jika fungsi di atas belum siap
        }
      }

      // Kembalikan koordinat dalam bentuk skala rasio (0.0 - 1.0) untuk dirender UI
      return <String, dynamic>{
        'corners': cornersList
            .map(
              (m) => m is Map
                  ? <double>[
                      (m['x'] as num).toDouble() / rotatedWidth,
                      (m['y'] as num).toDouble() / rotatedHeight,
                    ]
                  : <double>[0.0, 0.0],
            )
            .toList(),
        'imageWidth': rotatedWidth,
        'imageHeight': rotatedHeight,
        'status': hasDocument ? 'ready' : 'searching',
        'confidence': confidence.clamp(0.0, 1.0),
        'preview': previewBytes,
      };
    } catch (error) {
      return <String, dynamic>{
        'corners': <List<double>>[],
        'status': 'error',
        'confidence': 0.0,
        'error': error.toString(),
      };
    } finally {
      enhanced?.dispose();
      warped?.dispose();
      rotatedMat?.dispose();
      mat?.dispose();
    }
  }

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

  static Uint8List _packYPlaneBytes(
    Uint8List bytes,
    int width,
    int height,
    int bytesPerRow,
  ) {
    final packed = Uint8List(width * height);
    for (var row = 0; row < height; row++) {
      final srcOffset = row * bytesPerRow;
      final dstOffset = row * width;
      packed.setRange(dstOffset, dstOffset + width, bytes, srcOffset);
    }
    return packed;
  }

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
