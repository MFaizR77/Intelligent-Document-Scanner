import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Service Hibrida AI + PCD
/// Menangani inferensi model Semantic Segmentation (TFLite)
class MLScannerService {
  static tfl.Interpreter? _interpreter;
  static bool _isLoaded = false;
  static int _inputSize = 256; // Ukuran standar default model DeepLab

  static bool get isReady => _isLoaded && _interpreter != null;

  /// Memuat model TFLite ke dalam memori Isolate
  static Future<void> loadModel() async {
    if (_isLoaded) return;
    try {
      _interpreter = await tfl.Interpreter.fromAsset('assets/models/fairscan-segmentation-model.tflite');
      _isLoaded = true;
      debugPrint('[MLScanner] Model loaded successfully!');
      
      // Inspeksi Tensor (Akan dicetak di terminal untuk debugging kita)
      final inputTensors = _interpreter!.getInputTensors();
      for (var tensor in inputTensors) {
        debugPrint('[MLScanner] Input: ${tensor.name}, Shape: ${tensor.shape}, Type: ${tensor.type}');
        if (tensor.shape.length == 4) {
          _inputSize = tensor.shape[1]; // Auto-detect input size (e.g. 256)
        }
      }
      
      final outputTensors = _interpreter!.getOutputTensors();
      for (var tensor in outputTensors) {
        debugPrint('[MLScanner] Output: ${tensor.name}, Shape: ${tensor.shape}, Type: ${tensor.type}');
      }
    } catch (e) {
      debugPrint('[MLScanner] Failed to load TFLite model: $e');
    }
  }

  /// Menghasilkan Mask hitam putih (Document = Putih 255, Background = Hitam 0)
  /// Output dari fungsi ini siap dilempar ke `cv.findContours`!
  static cv.Mat? getSegmentationMask(cv.Mat inputMat) {
    if (!isReady) return null;

    try {
      // 1. Pre-processing: RGB & Resize
      cv.Mat rgb;
      if (inputMat.channels == 1) {
        rgb = cv.cvtColor(inputMat, cv.COLOR_GRAY2RGB);
      } else {
        rgb = cv.cvtColor(inputMat, cv.COLOR_BGR2RGB);
      }
      
      final resized = cv.resize(rgb, (_inputSize, _inputSize), interpolation: cv.INTER_AREA);
      
      final inputType = _interpreter!.getInputTensor(0).type;
      final bytes = resized.data; 
      
      Object inputObject;
      if (inputType == tfl.TensorType.float32) {
        // Normalisasi [0..1] (standar model segmentasi)
        final floatList = Float32List(_inputSize * _inputSize * 3);
        for (int i = 0; i < bytes.length; i++) {
          floatList[i] = bytes[i] / 255.0; 
        }
        // Reshape List ke bentuk 4D [1, H, W, 3]
        inputObject = [
          List.generate(_inputSize, (y) => 
            List.generate(_inputSize, (x) {
              final idx = (y * _inputSize + x) * 3;
              return [floatList[idx], floatList[idx+1], floatList[idx+2]];
            })
          )
        ];
      } else {
        // Uint8 format
        inputObject = [
          List.generate(_inputSize, (y) => 
            List.generate(_inputSize, (x) {
              final idx = (y * _inputSize + x) * 3;
              return [bytes[idx], bytes[idx+1], bytes[idx+2]];
            })
          )
        ];
      }
      
      // 2. Output Buffer Initialization
      final outputType = _interpreter!.getOutputTensor(0).type;
      final outputShape = _interpreter!.getOutputTensor(0).shape; 
      final numClasses = outputShape.last; 
      
      Object outputObject;
      if (outputType == tfl.TensorType.float32) {
        outputObject = List.generate(1, (_) => List.generate(_inputSize, (_) => List.generate(_inputSize, (_) => List.filled(numClasses, 0.0))));
      } else {
        outputObject = List.generate(1, (_) => List.generate(_inputSize, (_) => List.generate(_inputSize, (_) => List.filled(numClasses, 0))));
      }

      // 3. Inference AI (Sihir terjadi di sini!)
      _interpreter!.run(inputObject, outputObject);
      
      // 4. Post-processing: Buat gambar Mask Biner
      final maskBytes = Uint8List(_inputSize * _inputSize);
      int maskIdx = 0;
      
      final outputList = (outputObject as List)[0];
      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final pixelClasses = outputList[y][x];
          if (numClasses == 1) {
            // Jika output berupa probabilitas 1 kelas (0..1)
            final prob = pixelClasses[0];
            maskBytes[maskIdx] = prob > (outputType == tfl.TensorType.float32 ? 0.5 : 127) ? 255 : 0;
          } else {
            // Argmax: Kelas 1 (Kertas) vs Kelas 0 (Background)
            final bg = pixelClasses[0];
            final doc = pixelClasses[1];
            maskBytes[maskIdx] = doc > bg ? 255 : 0;
          }
          maskIdx++;
        }
      }
      
      final maskMat = cv.Mat.fromList(_inputSize, _inputSize, cv.MatType.CV_8UC1, maskBytes);
      
      // Resize kembali ke ukuran input aslinya (processTarget)
      final finalMask = cv.resize(maskMat, (inputMat.cols, inputMat.rows), interpolation: cv.INTER_NEAREST);
      
      rgb.dispose();
      resized.dispose();
      maskMat.dispose();
      
      return finalMask;
    } catch (e) {
      debugPrint('[MLScanner] Error during Inference: $e');
      return null;
    }
  }

  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
