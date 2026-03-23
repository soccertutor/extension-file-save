#import <AppKit/AppKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <hx/CFFI.h>

static NSURL* security_scoped_url_ = nil;
static AutoGCRoot* on_select_root_ = nullptr;
static AutoGCRoot* on_cancel_root_ = nullptr;

static void applyMimeFilter(NSSavePanel* panel, const char* mime) {
  if (@available(macOS 11.0, *)) {
    UTType* type = [UTType typeWithMIMEType:[NSString stringWithUTF8String:mime]];
    if (type != nil) [panel setAllowedContentTypes:@[ type ]];
  }
}

extern "C" void filesave_requestSavePath(const char* name, const char* mime, value onSelect,
                                         value onCancel) {
  delete on_select_root_;
  delete on_cancel_root_;
  on_select_root_ = new AutoGCRoot(onSelect);
  on_cancel_root_ = new AutoGCRoot(onCancel);

  @autoreleasepool {
    NSSavePanel* panel = [NSSavePanel savePanel];
    [panel setNameFieldStringValue:[NSString stringWithUTF8String:name]];
    [panel setCanCreateDirectories:YES];
    [panel setExtensionHidden:NO];

    applyMimeFilter(panel, mime);

    NSWindow* keyWindow = [[NSApplication sharedApplication] keyWindow];
    if (keyWindow == nil) {
      val_call0(on_cancel_root_->get());
      delete on_select_root_;
      delete on_cancel_root_;
      on_select_root_ = nullptr;
      on_cancel_root_ = nullptr;
      return;
    }

    [panel beginSheetModalForWindow:keyWindow
                  completionHandler:^(NSModalResponse result) {
                    // Handler fires inside SDL_WaitEvent (which called gc_enter_blocking).
                    // Temporarily exit blocking to safely call into Haxe, then re-enter.
                    gc_exit_blocking();

                    if (result == NSModalResponseOK) {
                      NSURL* url = [panel URL];
                      [url startAccessingSecurityScopedResource];
                      [security_scoped_url_ release];
                      security_scoped_url_ = [url retain];

                      const char* path = [[url path] UTF8String];
                      if (on_select_root_ != nullptr)
                        val_call1(on_select_root_->get(), alloc_string(path));
                    } else {
                      if (on_cancel_root_ != nullptr) val_call0(on_cancel_root_->get());
                    }

                    delete on_select_root_;
                    delete on_cancel_root_;
                    on_select_root_ = nullptr;
                    on_cancel_root_ = nullptr;

                    gc_enter_blocking();
                  }];
  }
}

extern "C" void filesave_releasePath(void) {
  if (security_scoped_url_ != nil) {
    [security_scoped_url_ stopAccessingSecurityScopedResource];
    [security_scoped_url_ release];
    security_scoped_url_ = nil;
  }
}

extern "C" void filesave_saveFile(const char* src, const char* name, const char* mime,
                                  value callback) {
  AutoGCRoot* callback_root_ = new AutoGCRoot(callback);

  @autoreleasepool {
    NSSavePanel* panel = [NSSavePanel savePanel];
    [panel setNameFieldStringValue:[NSString stringWithUTF8String:name]];
    [panel setCanCreateDirectories:YES];
    [panel setExtensionHidden:NO];

    applyMimeFilter(panel, mime);

    NSString* sourcePath = [NSString stringWithUTF8String:src];

    NSWindow* keyWindow = [[NSApplication sharedApplication] keyWindow];
    if (keyWindow == nil) {
      val_call1(callback_root_->get(), alloc_bool(false));
      delete callback_root_;
      return;
    }

    [panel beginSheetModalForWindow:keyWindow
                  completionHandler:^(NSModalResponse result) {
                    gc_exit_blocking();

                    bool success = false;
                    if (result == NSModalResponseOK) {
                      NSURL* destURL = [panel URL];
                      [destURL startAccessingSecurityScopedResource];

                      NSFileManager* fm = [NSFileManager defaultManager];
                      [fm removeItemAtURL:destURL error:nil];

                      NSError* error = nil;
                      success = [fm copyItemAtPath:sourcePath toPath:[destURL path] error:&error];

                      [destURL stopAccessingSecurityScopedResource];
                    }

                    val_call1(callback_root_->get(), alloc_bool(success));
                    delete callback_root_;

                    gc_enter_blocking();
                  }];
  }
}
