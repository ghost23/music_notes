#ifndef FLUTTER_PLUGIN_MUSIC_NOTES_PLUGIN_H_
#define FLUTTER_PLUGIN_MUSIC_NOTES_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace music_notes {

class MusicNotesPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  MusicNotesPlugin();

  virtual ~MusicNotesPlugin();

  // Disallow copy and assign.
  MusicNotesPlugin(const MusicNotesPlugin&) = delete;
  MusicNotesPlugin& operator=(const MusicNotesPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace music_notes

#endif  // FLUTTER_PLUGIN_MUSIC_NOTES_PLUGIN_H_
