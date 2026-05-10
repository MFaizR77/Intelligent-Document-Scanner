// lib/controllers/isolate_manager.dart
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../services/image_processing/edge_detection.dart';
import '../services/image_processing/enhancement.dart';
import '../services/image_processing/perspective_transform.dart';
import '../utils/image_utils.dart';

class IsolateManager {
  FlutterIsolate? _backgroundIsolate;
  ReceivePort? _mainPort;
  SendPort? _backgroundSendPort;
  bool _isListening = false;

  bool get isReady => _backgroundSendPort != null;

  Future<void> spawnProcessingIsolate(
    Function(Map<String, dynamic>) onResult,
  ) async {
    if (_isListening) {
      return;
    }

    _mainPort = ReceivePort();
    _backgroundIsolate = await FlutterIsolate.spawn(
      _backgroundTaskEntryPoint,
      _mainPort!.sendPort,
    );

    _isListening = true;
    _mainPort!.listen((message) {
      if (message is SendPort) {
        _backgroundSendPort = message;
      } else if (message is Map) {
        onResult(Map<String, dynamic>.from(message));
      }
    });
  }

  bool processFrame(CameraImage image) {
    final sendPort = _backgroundSendPort;
    if (sendPort == null || image.planes.isEmpty) {
      return false;
    }

    final yPlane = image.planes.first;
    sendPort.send(<String, dynamic>{
      'type': 'frame',
      'width': image.width,
      'height': image.height,
      'bytesPerRow': yPlane.bytesPerRow,
      'bytes': Uint8List.fromList(yPlane.bytes),
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
      }
    });
  }

  static Map<String, dynamic> _processFrame(Map<String, dynamic> frame) {
    cv.Mat? mat;
    cv.Mat? warped;
    cv.Mat? enhanced;

    try {
      final width = frame['width'] as int;
      final height = frame['height'] as int;
      final bytesPerRow = frame['bytesPerRow'] as int;
      final bytes = frame['bytes'] as Uint8List;

      mat = ImageUtils.convertYPlaneToMat(
        bytes: bytes,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
      );

      final corners = EdgeDetectionService.findDocumentCorners(mat);
      final hasDocument = corners.length == 4;
      final confidence = hasDocument
          ? _polygonArea(corners) / math.max(1, width * height)
          : 0.0;

      Uint8List? previewBytes;
      if (hasDocument) {
        warped = PerspectiveTransformService.applyPerspectiveTransform(
          mat,
          corners,
        );
        enhanced = EnhancementService.enhanceDocument(warped);
        previewBytes = ImageUtils.convertMatToUint8List(enhanced);
      }

      return <String, dynamic>{
        'corners': corners
            .map((p) => <double>[p.x / width, p.y / height])
            .toList(),
        'imageWidth': width,
        'imageHeight': height,
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
      mat?.dispose();
    }
  }

  static double _polygonArea(List<cv.Point> points) {
    if (points.length < 3) {
      return 0;
    }

    double area = 0;
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      area += (current.x * next.y) - (next.x * current.y);
    }
    return area.abs() / 2;
  }

  void dispose() {
    _backgroundSendPort?.send(<String, dynamic>{'type': 'dispose'});
    _backgroundIsolate?.kill();
    _mainPort?.close();
    _backgroundSendPort = null;
    _backgroundIsolate = null;
    _mainPort = null;
    _isListening = false;
  }
}
