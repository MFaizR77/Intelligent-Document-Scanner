// lib/controllers/isolate_manager.dart
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import '../utils/image_utils.dart';
import '../services/image_processing/edge_detection.dart';
import '../services/image_processing/perspective_transform.dart';
import '../services/image_processing/enhancement.dart';

class IsolateManager {
  FlutterIsolate? _backgroundIsolate;
  final ReceivePort _mainPort = ReceivePort();
  SendPort? _backgroundSendPort;
  
  bool get isReady => _backgroundSendPort != null;

  Future<void> spawnProcessingIsolate(Function(Map<String, dynamic>) onResult) async {
    _backgroundIsolate = await FlutterIsolate.spawn(
      _backgroundTaskEntryPoint,
      _mainPort.sendPort,
    );
    
    _mainPort.listen((message) {
      if (message is SendPort) {
        _backgroundSendPort = message; // Handshake successful
      } else if (message is Map<String, dynamic>) {
        onResult(message); // Forward results to caller
      }
    });
  }

  void processFrame(CameraImage image) {
    if (_backgroundSendPort != null) {
      _backgroundSendPort!.send(image);
    }
  }

  static void _backgroundTaskEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort); // Handshake
    
    receivePort.listen((message) {
      if (message is CameraImage) {
        final result = _processFrame(message);
        mainSendPort.send(result);
      }
    });
  }

  static Map<String, dynamic> _processFrame(CameraImage image) {
    // 1. Convert CameraImage → cv.Mat
    final mat = ImageUtils.convertCameraImageToMat(image);
    
    // 2. PCD Pipeline
    final corners = EdgeDetectionService.findDocumentCorners(mat);
    
    cv.Mat? enhanced;
    if (corners.length == 4) {
      final warped = PerspectiveTransformService.applyPerspectiveTransform(mat, corners);
      enhanced = EnhancementService.enhanceDocument(warped);
      warped.dispose();
    }
    
    // 3. Cleanup: WAJIB dispose semua intermediate Mat!
    mat.dispose();
    
    // Return result
    return {
      'corners': corners.map((p) => [p.x, p.y]).toList(),
      'status': corners.length == 4 ? 'ready' : 'searching',
      'preview': enhanced != null ? ImageUtils.convertMatToUint8List(enhanced) : null,
    };
  }

  void dispose() {
    _backgroundIsolate?.kill();
    _mainPort.close();
  }
}
