import 'package:camera/camera.dart';

class AppCameraController {
  List<CameraDescription> _availableCameras = const [];
  CameraController? _controller;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  Future<void> initialize() async {
    _availableCameras = await availableCameras();
    if (_availableCameras.isEmpty) {
      throw Exception('Tidak ada kamera yang tersedia di perangkat.');
    }

    final CameraDescription selectedCamera =
        _availableCameras
            .where((camera) => camera.lensDirection == CameraLensDirection.back)
            .isNotEmpty
        ? _availableCameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
          )
        : _availableCameras.first;

    _controller = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
