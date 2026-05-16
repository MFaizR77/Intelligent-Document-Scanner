import 'package:camera/camera.dart';

class AppCameraController {
  bool _isDisposed = false;
  List<CameraDescription> _availableCameras = const [];
  CameraController? _controller;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isStreamingImages => _controller?.value.isStreamingImages ?? false;

  Future<void> initialize() async {
    if (_isDisposed) {
      return;
    }

    if (_controller != null) {
      await stopImageStream();
      await _controller?.dispose();
      _controller = null;
    }

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

  Future<void> startImageStream(
    void Function(CameraImage image) onImage,
  ) async {
    final controller = _controller;
    if (_isDisposed || controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isStreamingImages) {
      return;
    }

    await controller.startImageStream(onImage);
  }

  Future<void> stopImageStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (!controller.value.isStreamingImages) {
      return;
    }

    try {
      await controller.stopImageStream();
    } catch (_) {
      // The native camera stream may already have been torn down by lifecycle.
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }
}
