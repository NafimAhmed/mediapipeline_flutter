


import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mediapipeline_flutter/mediapipeline_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final List<CameraDescription> cameras = await availableCameras();

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.cameras,
  });

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mediapipeline Flutter Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: HandGestureExamplePage(cameras: cameras),
    );
  }
}

class HandGestureExamplePage extends StatefulWidget {
  const HandGestureExamplePage({
    super.key,
    required this.cameras,
  });

  final List<CameraDescription> cameras;

  @override
  State<HandGestureExamplePage> createState() => _HandGestureExamplePageState();
}

class _HandGestureExamplePageState extends State<HandGestureExamplePage> {
  CameraController? _cameraController;
  CameraDescription? _selectedCamera;

  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _isDisposed = false;

  DateTime _lastProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);

  String _statusText = 'Starting...';
  String _gestureText = 'No gesture';
  String _handInfoText = 'Hand: -';

  List<HandLandmark> _landmarks = [];

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      // IMPORTANT:
      // Model file plugin native asset e ache:
      // mediapipeline_flutter/android/src/main/assets/models/hand_landmarker.task
      await MediapipelineFlutter.initializeHandLandmarker(
        modelAssetPath: 'models/hand_landmarker.task',
        useFlutterAsset: false,
        maxHands: 1,
      );

      await _initCamera();
    } catch (e, st) {
      debugPrint('START ERROR => $e');
      debugPrint('STACK => $st');

      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _statusText = 'Init failed: $e';
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      if (widget.cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _statusText = 'No camera found';
        });
        return;
      }

      _selectedCamera = widget.cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => widget.cameras.first,
      );

      final CameraController controller = CameraController(
        _selectedCamera!,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _cameraController = controller;

      await controller.initialize();

      if (!mounted || _isDisposed) return;

      await controller.startImageStream(_onCameraImage);

      if (!mounted || _isDisposed) return;

      setState(() {
        _isInitializing = false;
        _statusText = 'Show your hand';
      });
    } catch (e, st) {
      debugPrint('CAMERA INIT ERROR => $e');
      debugPrint('STACK => $st');

      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _statusText = 'Camera failed: $e';
      });
    }
  }

  Future<void> _onCameraImage(CameraImage image) async {
    if (_isDisposed || _isProcessing || _selectedCamera == null) return;

    final DateTime now = DateTime.now();

    // ANR safe: every frame process korbo na.
    if (now.difference(_lastProcessedAt).inMilliseconds < 180) {
      return;
    }

    _lastProcessedAt = now;
    _isProcessing = true;

    try {
      final HandLandmarkerResult result =
      await MediapipelineFlutter.detectCameraImage(
        image: image,
        rotationDegrees: _selectedCamera!.sensorOrientation,
      ).timeout(const Duration(seconds: 2));

      if (!mounted || _isDisposed) return;

      if (!result.hasHand) {
        setState(() {
          _statusText = 'No hand';
          _gestureText = 'No gesture';
          _handInfoText = 'Hand: -';
          _landmarks = [];
        });
        return;
      }

      final DetectedHand hand = result.hands.first;

      setState(() {
        _statusText = 'Detected';
        _gestureText = hand.gesture;
        _handInfoText =
        'Hand: ${hand.handedness} | Score: ${hand.score.toStringAsFixed(2)}';
        _landmarks = hand.landmarks;
      });
    } catch (e, st) {
      debugPrint('DETECT ERROR => $e');
      debugPrint('STACK => $st');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) return;

    final CameraDescription? currentCamera = _selectedCamera;
    if (currentCamera == null) return;

    final CameraDescription nextCamera = widget.cameras.firstWhere(
          (camera) => camera.lensDirection != currentCamera.lensDirection,
      orElse: () => widget.cameras.first,
    );

    await _stopCamera();

    if (!mounted || _isDisposed) return;

    setState(() {
      _isInitializing = true;
      _statusText = 'Switching camera...';
      _gestureText = 'No gesture';
      _handInfoText = 'Hand: -';
      _landmarks = [];
    });

    _selectedCamera = nextCamera;

    final CameraController controller = CameraController(
      _selectedCamera!,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    _cameraController = controller;

    try {
      await controller.initialize();

      if (!mounted || _isDisposed) return;

      await controller.startImageStream(_onCameraImage);

      if (!mounted || _isDisposed) return;

      setState(() {
        _isInitializing = false;
        _statusText = 'Show your hand';
      });
    } catch (e, st) {
      debugPrint('SWITCH CAMERA ERROR => $e');
      debugPrint('STACK => $st');

      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _statusText = 'Camera switch failed';
      });
    }
  }

  Future<void> _stopCamera() async {
    final CameraController? controller = _cameraController;

    if (controller == null) return;

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (e) {
      debugPrint('STOP STREAM ERROR => $e');
    }

    try {
      await controller.dispose();
    } catch (e) {
      debugPrint('CAMERA DISPOSE ERROR => $e');
    }

    _cameraController = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_stopCamera());
    unawaited(MediapipelineFlutter.closeHandLandmarker());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = _cameraController;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isInitializing ||
            controller == null ||
            !controller.value.isInitialized
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        )
            : Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: CameraPreview(controller),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: LandmarkPainter(
                    landmarks: _landmarks,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 80,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: _switchCamera,
                child: const Icon(Icons.cameraswitch),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _gestureText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _handInfoText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LandmarkPainter extends CustomPainter {
  LandmarkPainter({
    required this.landmarks,
  });

  final List<HandLandmark> landmarks;

  static const List<List<int>> _connections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [17, 18],
    [18, 19],
    [19, 20],
    [0, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.length < 21) return;

    final Paint linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final Paint pointPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    Offset point(int index) {
      final HandLandmark landmark = landmarks[index];

      return Offset(
        landmark.x * size.width,
        landmark.y * size.height,
      );
    }

    for (final List<int> connection in _connections) {
      canvas.drawLine(
        point(connection[0]),
        point(connection[1]),
        linePaint,
      );
    }

    for (int i = 0; i < landmarks.length; i++) {
      canvas.drawCircle(
        point(i),
        5,
        pointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant LandmarkPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks;
  }
}