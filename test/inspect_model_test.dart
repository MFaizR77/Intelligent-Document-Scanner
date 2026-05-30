import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';

void main() {
  test('Inspect TFLite Model', () {
    final modelPath = 'assets/models/fairscan-segmentation-model.tflite';
    if (!File(modelPath).existsSync()) {
      print('Model not found at $modelPath');
      return;
    }
    try {
      final interpreter = Interpreter.fromFile(File(modelPath));
      final inputTensors = interpreter.getInputTensors();
      final outputTensors = interpreter.getOutputTensors();

      print('\n=== INPUT TENSORS ===');
      for (var tensor in inputTensors) {
        print('Name: ${tensor.name}');
        print('Shape: ${tensor.shape}');
        print('Type: ${tensor.type}');
      }

      print('\n=== OUTPUT TENSORS ===');
      for (var tensor in outputTensors) {
        print('Name: ${tensor.name}');
        print('Shape: ${tensor.shape}');
        print('Type: ${tensor.type}');
      }
      print('=====================\n');
    } catch (e) {
      print('Error loading model: $e');
    }
  });
}
