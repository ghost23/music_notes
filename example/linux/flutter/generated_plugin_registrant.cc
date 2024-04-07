//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <music_notes/music_notes_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) music_notes_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MusicNotesPlugin");
  music_notes_plugin_register_with_registrar(music_notes_registrar);
}
