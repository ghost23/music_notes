#include "include/music_notes/music_notes_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#include "music_notes_plugin_private.h"

#define MUSIC_NOTES_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), music_notes_plugin_get_type(), \
                              MusicNotesPlugin))

struct _MusicNotesPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(MusicNotesPlugin, music_notes_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void music_notes_plugin_handle_method_call(
    MusicNotesPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void music_notes_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(music_notes_plugin_parent_class)->dispose(object);
}

static void music_notes_plugin_class_init(MusicNotesPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = music_notes_plugin_dispose;
}

static void music_notes_plugin_init(MusicNotesPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  MusicNotesPlugin* plugin = MUSIC_NOTES_PLUGIN(user_data);
  music_notes_plugin_handle_method_call(plugin, method_call);
}

void music_notes_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  MusicNotesPlugin* plugin = MUSIC_NOTES_PLUGIN(
      g_object_new(music_notes_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "music_notes",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
