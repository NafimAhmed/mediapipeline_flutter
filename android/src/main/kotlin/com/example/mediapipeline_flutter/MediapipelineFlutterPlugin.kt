




package com.example.mediapipeline_flutter

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max

class MediapipelineFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

  private lateinit var channel: MethodChannel
  private lateinit var context: Context

  private var handLandmarker: HandLandmarker? = null

  private val mainHandler = Handler(Looper.getMainLooper())
  private var executor: ExecutorService = Executors.newSingleThreadExecutor()

  private var lastTimestampMs = 0L

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext

    channel = MethodChannel(
      binding.binaryMessenger,
      "mediapipeline_flutter"
    )

    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(
    call: MethodCall,
    result: MethodChannel.Result
  ) {
    when (call.method) {
      "initHandLandmarker" -> {
        try {
          initHandLandmarker(call)
          result.success(true)
        } catch (e: Exception) {
          result.error(
            "INIT_HAND_LANDMARKER_ERROR",
            e.message ?: "Failed to initialize HandLandmarker",
            e.stackTraceToString()
          )
        }
      }

      "detectYuv420" -> {
        val args = call.arguments as? Map<*, *>

        if (args == null) {
          result.error(
            "INVALID_ARGS",
            "Arguments are null",
            null
          )
          return
        }

        if (handLandmarker == null) {
          result.error(
            "MODEL_NOT_READY",
            "HandLandmarker is not initialized. Call initializeHandLandmarker() first.",
            null
          )
          return
        }

        if (executor.isShutdown || executor.isTerminated) {
          executor = Executors.newSingleThreadExecutor()
        }

        executor.execute {
          try {
            val response = detectYuv420(args)

            mainHandler.post {
              result.success(response)
            }
          } catch (e: Exception) {
            mainHandler.post {
              result.error(
                "DETECT_YUV420_ERROR",
                e.message ?: "Failed to detect hand",
                e.stackTraceToString()
              )
            }
          }
        }
      }

      "closeHandLandmarker" -> {
        try {
          closeHandLandmarker()
          result.success(true)
        } catch (e: Exception) {
          result.error(
            "CLOSE_HAND_LANDMARKER_ERROR",
            e.message ?: "Failed to close HandLandmarker",
            e.stackTraceToString()
          )
        }
      }

      else -> result.notImplemented()
    }
  }

  private fun initHandLandmarker(call: MethodCall) {
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()

    val modelAssetPath = args["modelAssetPath"] as? String
      ?: "models/hand_landmarker.task"

    val useFlutterAsset = args["useFlutterAsset"] as? Boolean ?: false

    val maxHands = (args["maxHands"] as? Number)?.toInt() ?: 1

    val minHandDetectionConfidence =
      (args["minHandDetectionConfidence"] as? Number)?.toFloat() ?: 0.5f

    val minHandPresenceConfidence =
      (args["minHandPresenceConfidence"] as? Number)?.toFloat() ?: 0.5f

    val minTrackingConfidence =
      (args["minTrackingConfidence"] as? Number)?.toFloat() ?: 0.5f

    closeHandLandmarker()
    lastTimestampMs = 0L

    val finalModelAssetPath = if (useFlutterAsset) {
      FlutterInjector
        .instance()
        .flutterLoader()
        .getLookupKeyForAsset(modelAssetPath)
    } else {
      modelAssetPath
    }

    val baseOptions = BaseOptions.builder()
      .setModelAssetPath(finalModelAssetPath)
      .build()

    val options = HandLandmarker.HandLandmarkerOptions.builder()
      .setBaseOptions(baseOptions)
      .setRunningMode(RunningMode.VIDEO)
      .setNumHands(maxHands)
      .setMinHandDetectionConfidence(minHandDetectionConfidence)
      .setMinHandPresenceConfidence(minHandPresenceConfidence)
      .setMinTrackingConfidence(minTrackingConfidence)
      .build()

    handLandmarker = HandLandmarker.createFromOptions(
      context,
      options
    )
  }

  private fun detectYuv420(args: Map<*, *>): Map<String, Any> {
    val width = (args["width"] as Number).toInt()
    val height = (args["height"] as Number).toInt()

    val y = args["y"] as? ByteArray
      ?: throw IllegalArgumentException("Y plane is missing")

    val u = args["u"] as? ByteArray
      ?: throw IllegalArgumentException("U plane is missing")

    val v = args["v"] as? ByteArray
      ?: throw IllegalArgumentException("V plane is missing")

    val yRowStride = (args["yRowStride"] as Number).toInt()
    val uvRowStride = (args["uvRowStride"] as Number).toInt()
    val uvPixelStride = (args["uvPixelStride"] as Number).toInt()

    val rotationDegrees = (args["rotationDegrees"] as Number).toInt()

    val bitmap = yuv420ToBitmap(
      width = width,
      height = height,
      y = y,
      u = u,
      v = v,
      yRowStride = yRowStride,
      uvRowStride = uvRowStride,
      uvPixelStride = uvPixelStride
    )

    val rotatedBitmap = rotateBitmap(
      bitmap = bitmap,
      rotationDegrees = rotationDegrees
    )

    val mpImage = BitmapImageBuilder(rotatedBitmap).build()

    val now = SystemClock.uptimeMillis()
    lastTimestampMs = max(now, lastTimestampMs + 1)

    val detectionResult = handLandmarker?.detectForVideo(
      mpImage,
      lastTimestampMs
    )

    val hands = mutableListOf<Map<String, Any>>()

    val landmarksList = detectionResult?.landmarks() ?: emptyList()
    val handednessList = detectionResult?.handedness() ?: emptyList()

    for (i in landmarksList.indices) {
      val landmarkMaps = landmarksList[i].map { landmark ->
        mapOf(
          "x" to landmark.x().toDouble(),
          "y" to landmark.y().toDouble(),
          "z" to landmark.z().toDouble()
        )
      }

      val category = handednessList.getOrNull(i)?.firstOrNull()

      hands.add(
        mapOf(
          "handedness" to (category?.categoryName() ?: "Unknown"),
          "score" to (category?.score()?.toDouble() ?: 0.0),
          "landmarks" to landmarkMaps
        )
      )
    }

    if (rotatedBitmap != bitmap && !rotatedBitmap.isRecycled) {
      rotatedBitmap.recycle()
    }

    if (!bitmap.isRecycled) {
      bitmap.recycle()
    }

    return mapOf(
      "imageWidth" to if (rotationDegrees == 90 || rotationDegrees == 270) height else width,
      "imageHeight" to if (rotationDegrees == 90 || rotationDegrees == 270) width else height,
      "hands" to hands
    )
  }

  private fun yuv420ToBitmap(
    width: Int,
    height: Int,
    y: ByteArray,
    u: ByteArray,
    v: ByteArray,
    yRowStride: Int,
    uvRowStride: Int,
    uvPixelStride: Int
  ): Bitmap {
    val nv21 = ByteArray(width * height + width * height / 2)

    var outputOffset = 0

    for (row in 0 until height) {
      val inputOffset = row * yRowStride

      if (
        inputOffset + width <= y.size &&
        outputOffset + width <= nv21.size
      ) {
        System.arraycopy(
          y,
          inputOffset,
          nv21,
          outputOffset,
          width
        )
      }

      outputOffset += width
    }

    val chromaHeight = height / 2
    val chromaWidth = width / 2

    for (row in 0 until chromaHeight) {
      for (col in 0 until chromaWidth) {
        val uvOffset = row * uvRowStride + col * uvPixelStride

        if (
          uvOffset < v.size &&
          uvOffset < u.size &&
          outputOffset + 1 < nv21.size
        ) {
          nv21[outputOffset++] = v[uvOffset]
          nv21[outputOffset++] = u[uvOffset]
        }
      }
    }

    val yuvImage = YuvImage(
      nv21,
      ImageFormat.NV21,
      width,
      height,
      null
    )

    val outputStream = ByteArrayOutputStream()

    val compressed = yuvImage.compressToJpeg(
      Rect(0, 0, width, height),
      80,
      outputStream
    )

    if (!compressed) {
      throw IllegalStateException("Failed to convert YUV image to JPEG")
    }

    val imageBytes = outputStream.toByteArray()

    return BitmapFactory.decodeByteArray(
      imageBytes,
      0,
      imageBytes.size
    ) ?: throw IllegalStateException("Failed to decode JPEG to Bitmap")
  }

  private fun rotateBitmap(
    bitmap: Bitmap,
    rotationDegrees: Int
  ): Bitmap {
    if (rotationDegrees == 0) return bitmap

    val matrix = Matrix()
    matrix.postRotate(rotationDegrees.toFloat())

    return Bitmap.createBitmap(
      bitmap,
      0,
      0,
      bitmap.width,
      bitmap.height,
      matrix,
      true
    )
  }

  private fun closeHandLandmarker() {
    try {
      handLandmarker?.close()
    } catch (_: Exception) {
    }

    handLandmarker = null
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    closeHandLandmarker()

    try {
      executor.shutdownNow()
    } catch (_: Exception) {
    }

    channel.setMethodCallHandler(null)
  }
}