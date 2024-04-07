#include "include/music_notes/music_notes_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "music_notes_plugin.h"

void MusicNotesPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  music_notes::MusicNotesPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
