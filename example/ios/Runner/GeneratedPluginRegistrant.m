//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<integration_test/IntegrationTestPlugin.h>)
#import <integration_test/IntegrationTestPlugin.h>
#else
@import integration_test;
#endif

#if __has_include(<music_notes/MusicNotesPlugin.h>)
#import <music_notes/MusicNotesPlugin.h>
#else
@import music_notes;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [IntegrationTestPlugin registerWithRegistrar:[registry registrarForPlugin:@"IntegrationTestPlugin"]];
  [MusicNotesPlugin registerWithRegistrar:[registry registrarForPlugin:@"MusicNotesPlugin"]];
}

@end
