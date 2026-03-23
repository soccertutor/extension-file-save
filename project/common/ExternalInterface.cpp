#ifndef STATIC_LINK
#define IMPLEMENT_API
#endif

#if defined(HX_WINDOWS) || defined(HX_MACOS) || defined(HX_LINUX)
#define NEKO_COMPATIBLE
#endif

#include <hx/CFFIPrime.h>

extern "C" {
void filesave_requestSavePath(const char* name, const char* mime,
                              value onSelect, value onCancel);
void filesave_releasePath(void);
void filesave_saveFile(const char* src, const char* name, const char* mime,
                       value callback);
}

void fs_requestSavePath(const char* name, const char* mime, value onSelect,
                        value onCancel) {
  filesave_requestSavePath(name, mime, onSelect, onCancel);
}
DEFINE_PRIME4v(fs_requestSavePath);

void fs_releasePath() { filesave_releasePath(); }
DEFINE_PRIME0v(fs_releasePath);

void fs_saveFile(const char* src, const char* name, const char* mime,
                 value callback) {
  filesave_saveFile(src, name, mime, callback);
}
DEFINE_PRIME4v(fs_saveFile);

extern "C" void extension_file_save_main() { val_int(0); }
DEFINE_ENTRY_POINT(extension_file_save_main);

extern "C" int extension_file_save_register_prims() { return 0; }
