#ifndef FLUTTER_PLUGIN_MUSIC_NOTES_PLUGIN_H_
#define FLUTTER_PLUGIN_MUSIC_NOTES_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

typedef struct _MusicNotesPlugin MusicNotesPlugin;
typedef struct {
  GObjectClass parent_class;
} MusicNotesPluginClass;

FLUTTER_PLUGIN_EXPORT GType music_notes_plugin_get_type();

FLUTTER_PLUGIN_EXPORT void music_notes_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_MUSIC_NOTES_PLUGIN_H_
