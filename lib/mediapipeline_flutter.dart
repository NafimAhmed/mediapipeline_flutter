




library mediapipeline_flutter;

import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

class MediapipelineFlutter {
  MediapipelineFlutter._();

  static const MethodChannel _channel = MethodChannel('mediapipeline_flutter');

  static bool _handLandmarkerInitialized = false;

  static Future<void> initializeHandLandmarker({
    String modelAssetPath = 'models/hand_landmarker.task',
    bool useFlutterAsset = false,
    int maxHands = 1,
    double minHandDetectionConfidence = 0.5,
    double minHandPresenceConfidence = 0.5,
    double minTrackingConfidence = 0.5,
  }) async {
    await _channel.invokeMethod<void>(
      'initHandLandmarker',
      {
        'modelAssetPath': modelAssetPath,
        'useFlutterAsset': useFlutterAsset,
        'maxHands': maxHands,
        'minHandDetectionConfidence': minHandDetectionConfidence,
        'minHandPresenceConfidence': minHandPresenceConfidence,
        'minTrackingConfidence': minTrackingConfidence,
      },
    );

    _handLandmarkerInitialized = true;
  }

  static Future<HandLandmarkerResult> detectCameraImage({
    required CameraImage image,
    required int rotationDegrees,
  }) async {
    if (!_handLandmarkerInitialized) {
      throw StateError(
        'HandLandmarker is not initialized. Call initializeHandLandmarker() first.',
      );
    }

    if (image.planes.length < 3) {
      return HandLandmarkerResult.empty();
    }

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    return detectYuv420(
      width: image.width,
      height: image.height,
      y: Uint8List.fromList(yPlane.bytes),
      u: Uint8List.fromList(uPlane.bytes),
      v: Uint8List.fromList(vPlane.bytes),
      yRowStride: yPlane.bytesPerRow,
      uvRowStride: uPlane.bytesPerRow,
      uvPixelStride: uPlane.bytesPerPixel ?? 1,
      rotationDegrees: rotationDegrees,
    );
  }

  static Future<HandLandmarkerResult> detectYuv420({
    required int width,
    required int height,
    required Uint8List y,
    required Uint8List u,
    required Uint8List v,
    required int yRowStride,
    required int uvRowStride,
    required int uvPixelStride,
    required int rotationDegrees,
  }) async {
    if (!_handLandmarkerInitialized) {
      throw StateError(
        'HandLandmarker is not initialized. Call initializeHandLandmarker() first.',
      );
    }

    final Map<dynamic, dynamic>? response =
    await _channel.invokeMapMethod<dynamic, dynamic>(
      'detectYuv420',
      {
        'width': width,
        'height': height,
        'y': y,
        'u': u,
        'v': v,
        'yRowStride': yRowStride,
        'uvRowStride': uvRowStride,
        'uvPixelStride': uvPixelStride,
        'rotationDegrees': rotationDegrees,
      },
    );

    if (response == null) {
      return HandLandmarkerResult.empty();
    }

    return HandLandmarkerResult.fromMap(response);
  }

  static Future<void> closeHandLandmarker() async {
    try {
      await _channel.invokeMethod<void>('closeHandLandmarker');
    } finally {
      _handLandmarkerInitialized = false;
    }
  }
}

class HandLandmarkerResult {
  const HandLandmarkerResult({
    required this.imageWidth,
    required this.imageHeight,
    required this.hands,
  });

  final int imageWidth;
  final int imageHeight;
  final List<DetectedHand> hands;

  bool get hasHand => hands.isNotEmpty;

  factory HandLandmarkerResult.empty() {
    return const HandLandmarkerResult(
      imageWidth: 0,
      imageHeight: 0,
      hands: [],
    );
  }

  factory HandLandmarkerResult.fromMap(Map<dynamic, dynamic> map) {
    final rawHands = map['hands'];

    return HandLandmarkerResult(
      imageWidth: (map['imageWidth'] as num?)?.toInt() ?? 0,
      imageHeight: (map['imageHeight'] as num?)?.toInt() ?? 0,
      hands: rawHands is List
          ? rawHands
          .whereType<Map<dynamic, dynamic>>()
          .map(DetectedHand.fromMap)
          .toList()
          : [],
    );
  }
}

class DetectedHand {
  const DetectedHand({
    required this.handedness,
    required this.score,
    required this.landmarks,
    required this.gesture,
  });

  final String handedness;
  final double score;
  final List<HandLandmark> landmarks;
  final String gesture;

  factory DetectedHand.fromMap(Map<dynamic, dynamic> map) {
    final rawLandmarks = map['landmarks'];

    final List<HandLandmark> landmarks = rawLandmarks is List
        ? rawLandmarks
        .whereType<Map<dynamic, dynamic>>()
        .map(HandLandmark.fromMap)
        .toList()
        : <HandLandmark>[];

    final String handedness = map['handedness']?.toString() ?? 'Unknown';

    return DetectedHand(
      handedness: handedness,
      score: (map['score'] as num?)?.toDouble() ?? 0,
      landmarks: landmarks,
      gesture: GestureClassifier.classify(
        landmarks,
        handedness: handedness,
      ),
    );
  }
}

class HandLandmark {
  const HandLandmark({
    required this.x,
    required this.y,
    required this.z,
  });

  final double x;
  final double y;
  final double z;

  factory HandLandmark.fromMap(Map<dynamic, dynamic> map) {
    return HandLandmark(
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      z: (map['z'] as num?)?.toDouble() ?? 0,
    );
  }
}

class GestureClassifier {
  GestureClassifier._();

  static String classify(
      List<HandLandmark> lm, {
        required String handedness,
      }) {
    if (lm.length < 21) return 'No hand';

    final bool thumbOpen = _isThumbOpen(lm);
    final bool indexOpen = _isFingerOpen(lm, tip: 8, pip: 6);
    final bool middleOpen = _isFingerOpen(lm, tip: 12, pip: 10);
    final bool ringOpen = _isFingerOpen(lm, tip: 16, pip: 14);
    final bool pinkyOpen = _isFingerOpen(lm, tip: 20, pip: 18);

    final int openCount = [
      thumbOpen,
      indexOpen,
      middleOpen,
      ringOpen,
      pinkyOpen,
    ].where((value) => value).length;

    final bool fourFingersClosed =
        !indexOpen && !middleOpen && !ringOpen && !pinkyOpen;

    if (openCount >= 4) {
      return 'Open Palm';
    }

    if (openCount == 0) {
      return 'Fist';
    }

    if (indexOpen && !middleOpen && !ringOpen && !pinkyOpen && !thumbOpen) {
      return 'One Finger';
    }

    if (indexOpen && middleOpen && !ringOpen && !pinkyOpen) {
      return 'Two Fingers';
    }

    if (thumbOpen && fourFingersClosed && lm[4].y < lm[3].y) {
      return 'Thumb Up';
    }

    return 'Unknown Gesture';
  }

  static bool _isFingerOpen(
      List<HandLandmark> lm, {
        required int tip,
        required int pip,
      }) {
    return lm[tip].y < lm[pip].y;
  }

  static bool _isThumbOpen(List<HandLandmark> lm) {
    final double wristToThumbTip = _distance(lm[0], lm[4]);
    final double wristToThumbIp = _distance(lm[0], lm[3]);
    final double horizontalGap = (lm[4].x - lm[2].x).abs();

    return wristToThumbTip > wristToThumbIp && horizontalGap > 0.04;
  }

  static double _distance(HandLandmark a, HandLandmark b) {
    final double dx = a.x - b.x;
    final double dy = a.y - b.y;
    final double dz = a.z - b.z;

    return sqrt(dx * dx + dy * dy + dz * dz);
  }
}