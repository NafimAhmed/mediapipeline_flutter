#include "include/mediapipeline_flutter/mediapipeline_flutter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "mediapipeline_flutter_plugin.h"

void MediapipelineFlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  mediapipeline_flutter::MediapipelineFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
