import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipeline_flutter/mediapipeline_flutter.dart';
import 'package:mediapipeline_flutter/mediapipeline_flutter_platform_interface.dart';
import 'package:mediapipeline_flutter/mediapipeline_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMediapipelineFlutterPlatform
    with MockPlatformInterfaceMixin
    implements MediapipelineFlutterPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MediapipelineFlutterPlatform initialPlatform = MediapipelineFlutterPlatform.instance;

  test('$MethodChannelMediapipelineFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMediapipelineFlutter>());
  });

  test('getPlatformVersion', () async {
    MediapipelineFlutter mediapipelineFlutterPlugin = MediapipelineFlutter();
    MockMediapipelineFlutterPlatform fakePlatform = MockMediapipelineFlutterPlatform();
    MediapipelineFlutterPlatform.instance = fakePlatform;

    expect(await mediapipelineFlutterPlugin.getPlatformVersion(), '42');
  });
}
