



# mediapipeline_flutter

A Flutter plugin for building **MediaPipe-powered vision pipelines** with native Android performance.

`mediapipeline_flutter` allows Flutter developers to use Android native MediaPipe Tasks from Flutter using a clean MethodChannel API.

The first version supports **real-time hand landmark detection** and **basic hand gesture recognition**.

---

## ✨ Features

- ✅ Android native MediaPipe Tasks integration
- ✅ Real-time hand landmark detection
- ✅ Flutter `CameraImage` YUV420 support
- ✅ Built-in `hand_landmarker.task` model support
- ✅ Basic hand gesture recognition
- ✅ MethodChannel based native bridge
- ✅ ANR-safe processing pattern
- ✅ Simple Flutter API
- ✅ Easy to extend for Pose, Face, Object Detection and more

---

## 🚀 Supported Gestures

| Gesture | Description |
|---|---|
| Open Palm | Most fingers are open |
| Fist | All fingers are folded |
| One Finger | Only index finger is open |
| Two Fingers | Index and middle fingers are open |
| Thumb Up | Thumb is open and other fingers are folded |
| Unknown Gesture | Gesture could not be classified |

---

## 📦 Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  mediapipeline_flutter: ^0.0.1
  camera: 0.11.2+1
```

Then run:

```bash
flutter pub get
```

---

## 🤖 Android Setup

### Minimum SDK

MediaPipe Tasks requires Android `minSdk` 24 or higher.

For Kotlin Gradle:

```kotlin
// android/app/build.gradle.kts

defaultConfig {
    minSdk = 24
}
```

For Groovy Gradle:

```gradle
// android/app/build.gradle

defaultConfig {
    minSdkVersion 24
}
```

---

## 📷 Camera Permission

Add camera permission in:

```text
android/app/src/main/AndroidManifest.xml
```

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

Example:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.CAMERA" />

    <application
        android:label="your_app"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <!-- MainActivity here -->

    </application>
</manifest>
```

---

## 🧠 Built-in Model

This plugin includes the MediaPipe Hand Landmarker model inside the Android plugin assets.

Model location inside the plugin:

```text
mediapipeline_flutter/android/src/main/assets/models/hand_landmarker.task
```

Default native model path:

```text
models/hand_landmarker.task
```

So the app does not need to add the model manually.

---

## ⚡ Quick Start

### 1. Import packages

```dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mediapipeline_flutter/mediapipeline_flutter.dart';
```

---

### 2. Get available cameras and create camera controller

```dart
Future<CameraController> createCameraController() async {
  final List<CameraDescription> cameras = await availableCameras();

  final CameraDescription selectedCamera = cameras.firstWhere(
    (CameraDescription camera) =>
        camera.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );

  final CameraController controller = CameraController(
    selectedCamera,
    ResolutionPreset.low,
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.yuv420,
  );

  await controller.initialize();

  return controller;
}
```

---

### 3. Initialize Hand Landmarker

```dart
Future<void> initializeMediaPipeline() async {
  await MediapipelineFlutter.initializeHandLandmarker();
}
```

This uses the built-in native model by default.

Default values:

```text
modelAssetPath = models/hand_landmarker.task
useFlutterAsset = false
```

You can also configure it manually:

```dart
Future<void> initializeMediaPipelineWithOptions() async {
  await MediapipelineFlutter.initializeHandLandmarker(
    modelAssetPath: 'models/hand_landmarker.task',
    useFlutterAsset: false,
    maxHands: 1,
    minHandDetectionConfidence: 0.5,
    minHandPresenceConfidence: 0.5,
    minTrackingConfidence: 0.5,
  );
}
```

---

### 4. Detect hand from camera stream

```dart
Future<void> startHandDetectionStream({
  required CameraController controller,
  required CameraDescription selectedCamera,
}) async {
  bool isProcessing = false;
  DateTime lastProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);

  await controller.startImageStream((CameraImage image) async {
    if (isProcessing) return;

    final DateTime now = DateTime.now();

    // Process one frame every 180ms to avoid UI lag and ANR.
    if (now.difference(lastProcessedAt).inMilliseconds < 180) {
      return;
    }

    lastProcessedAt = now;
    isProcessing = true;

    try {
      final HandLandmarkerResult result =
          await MediapipelineFlutter.detectCameraImage(
        image: image,
        rotationDegrees: selectedCamera.sensorOrientation,
      );

      if (result.hasHand) {
        final DetectedHand hand = result.hands.first;

        debugPrint('Gesture: ${hand.gesture}');
        debugPrint('Hand: ${hand.handedness}');
        debugPrint('Score: ${hand.score}');
        debugPrint('Landmarks: ${hand.landmarks.length}');
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    } finally {
      isProcessing = false;
    }
  });
}
```

---

## 📌 Full Usage Example

```dart
Future<void> detectFromCameraImage({
  required CameraImage cameraImage,
  required int rotationDegrees,
}) async {
  final HandLandmarkerResult result =
      await MediapipelineFlutter.detectCameraImage(
    image: cameraImage,
    rotationDegrees: rotationDegrees,
  );

  if (result.hasHand) {
    final DetectedHand hand = result.hands.first;

    debugPrint(hand.gesture);
    debugPrint(hand.handedness);
    debugPrint(hand.score.toString());
    debugPrint(hand.landmarks.length.toString());
  }
}
```

---

## 📍 Hand Landmark Data

Each detected hand returns 21 landmarks.

```dart
class ExampleHandLandmark {
  const ExampleHandLandmark({
    required this.x,
    required this.y,
    required this.z,
  });

  final double x;
  final double y;
  final double z;
}
```

Example:

```dart
void printIndexFingerTip(DetectedHand hand) {
  final HandLandmark indexFingerTip = hand.landmarks[8];

  debugPrint(indexFingerTip.x.toString());
  debugPrint(indexFingerTip.y.toString());
  debugPrint(indexFingerTip.z.toString());
}
```

Common landmark indexes:

| Index | Landmark |
|---|---|
| 0 | Wrist |
| 4 | Thumb Tip |
| 8 | Index Finger Tip |
| 12 | Middle Finger Tip |
| 16 | Ring Finger Tip |
| 20 | Pinky Finger Tip |

---

## 🧩 API Reference

### Initialize Hand Landmarker

```dart
Future<void> initializeHandLandmarkerExample() async {
  await MediapipelineFlutter.initializeHandLandmarker();
}
```

With options:

```dart
Future<void> initializeHandLandmarkerWithOptionsExample() async {
  await MediapipelineFlutter.initializeHandLandmarker(
    modelAssetPath: 'models/hand_landmarker.task',
    useFlutterAsset: false,
    maxHands: 1,
    minHandDetectionConfidence: 0.5,
    minHandPresenceConfidence: 0.5,
    minTrackingConfidence: 0.5,
  );
}
```

---

### Detect from CameraImage

```dart
Future<HandLandmarkerResult> detectFromCameraImageExample({
  required CameraImage cameraImage,
  required int rotationDegrees,
}) async {
  return MediapipelineFlutter.detectCameraImage(
    image: cameraImage,
    rotationDegrees: rotationDegrees,
  );
}
```

---

### Detect from YUV420 Planes

```dart
Future<HandLandmarkerResult> detectFromYuv420Example({
  required int width,
  required int height,
  required Uint8List yBytes,
  required Uint8List uBytes,
  required Uint8List vBytes,
  required int yRowStride,
  required int uvRowStride,
  required int uvPixelStride,
  required int rotationDegrees,
}) async {
  return MediapipelineFlutter.detectYuv420(
    width: width,
    height: height,
    y: yBytes,
    u: uBytes,
    v: vBytes,
    yRowStride: yRowStride,
    uvRowStride: uvRowStride,
    uvPixelStride: uvPixelStride,
    rotationDegrees: rotationDegrees,
  );
}
```

Required import for `Uint8List`:

```dart
import 'dart:typed_data';
```

---

### Close Hand Landmarker

```dart
Future<void> closeHandLandmarkerExample() async {
  await MediapipelineFlutter.closeHandLandmarker();
}
```

---

## 🛡️ Performance Tips

For real-time camera detection, follow these rules:

- Do not process every camera frame
- Use frame throttling
- Use a processing lock
- Use low camera resolution
- Do not call detection inside `build()`
- Stop image stream before disposing camera controller
- Close the landmarker when the screen is disposed

Recommended frame throttle:

```dart
bool shouldSkipFrame(DateTime lastProcessedAt) {
  final DateTime now = DateTime.now();

  return now.difference(lastProcessedAt).inMilliseconds < 180;
}
```

Recommended processing lock:

```dart
Future<void> processSafely({
  required Future<void> Function() task,
}) async {
  bool isProcessing = false;

  if (isProcessing) return;

  isProcessing = true;

  try {
    await task();
  } finally {
    isProcessing = false;
  }
}
```

---

## 🧪 Example App

Run the example project:

```bash
cd example
flutter clean
flutter pub get
flutter run
```

---

## 📁 Plugin Structure

```text
mediapipeline_flutter/
├── android/
│   └── src/
│       └── main/
│           ├── assets/
│           │   └── models/
│           │       └── hand_landmarker.task
│           └── kotlin/
│               └── com/example/mediapipeline_flutter/
│                   └── MediapipelineFlutterPlugin.kt
├── lib/
│   └── mediapipeline_flutter.dart
└── example/
    └── lib/
        └── main.dart
```

---

## 🧱 Platform Support

| Platform | Status |
|---|---|
| Android | ✅ Supported |
| iOS | 🚧 Coming soon |
| Web | ❌ Not supported |
| Windows | ❌ Not supported |
| macOS | ❌ Not supported |
| Linux | ❌ Not supported |

---

## 🗺️ Roadmap

- [x] Android Hand Landmarker
- [x] Basic gesture recognition
- [x] CameraImage YUV420 support
- [x] Built-in native model asset
- [ ] Pose Landmarker
- [ ] Face Landmarker
- [ ] Object Detector
- [ ] Image Segmenter
- [ ] Native CameraX real-time pipeline
- [ ] EventChannel result stream
- [ ] iOS support

---

## ❓ Troubleshooting

### Model file not found

Error example:

```text
Unable to open file at flutter_assets/assets/models/hand_landmarker.task
```

Fix:

```dart
Future<void> fixModelPathExample() async {
  await MediapipelineFlutter.initializeHandLandmarker(
    modelAssetPath: 'models/hand_landmarker.task',
    useFlutterAsset: false,
  );
}
```

Make sure the model exists inside the plugin:

```text
android/src/main/assets/models/hand_landmarker.task
```

---

### App crashes on start

Make sure Android `minSdk` is 24 or higher:

```kotlin
defaultConfig {
    minSdk = 24
}
```

---

### Camera is not opening

Make sure camera permission exists:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

Also test on a real Android device. Some emulators may not support camera image stream properly.

---

## 🤝 Contributing

Contributions are welcome.

You can help by adding:

- Pose Landmarker
- Face Landmarker
- Object Detector
- Image Segmenter
- iOS support
- Better gesture classifier
- Native CameraX pipeline

---

## 📄 License

See the `LICENSE` file for details.

---

## 👨‍💻 Author

Created by **Nafim Ahmed**

Flutter developer focused on AI vision, automation, ERP integrations, and real-time mobile applications.