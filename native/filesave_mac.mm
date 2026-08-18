#import <AppKit/AppKit.h>
#import <CoreServices/CoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <hx/CFFI.h>

static NSURL* security_scoped_url_ = nil;
static AutoGCRoot* on_select_root_ = nullptr;
static AutoGCRoot* on_cancel_root_ = nullptr;
static bool panel_open_ = false;

static void applyMimeFilter(NSSavePanel* panel, const char* mime) {
	if (@available(macOS 11.0, *)) {
		UTType* type = [UTType typeWithMIMEType:[NSString stringWithUTF8String:mime]];
		if (type != nil) [panel setAllowedContentTypes:@[ type ]];
	} else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		CFStringRef cf_mime = CFStringCreateWithCString(kCFAllocatorDefault, mime, kCFStringEncodingUTF8);
		CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, cf_mime, NULL);
		CFRelease(cf_mime);
		if (uti != NULL) {
			CFStringRef ext = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
			CFRelease(uti);
			if (ext != NULL) {
				[panel setAllowedFileTypes:@[ (__bridge NSString*)ext ]];
				CFRelease(ext);
			}
		}
#pragma clang diagnostic pop
	}
}

static void applyExtensionFilter(NSOpenPanel* panel, const char* extensions) {
	if (extensions == NULL || extensions[0] == '\0') return;

	NSArray<NSString*>* list = [[NSString stringWithUTF8String:extensions] componentsSeparatedByString:@","];

	if (@available(macOS 11.0, *)) {
		NSMutableArray<UTType*>* types = [NSMutableArray array];
		for (NSString* extension in list) {
			UTType* type = [UTType typeWithFilenameExtension:extension];
			if (type != nil) [types addObject:type];
		}
		if ([types count] > 0) [panel setAllowedContentTypes:types];
	} else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		[panel setAllowedFileTypes:list];
#pragma clang diagnostic pop
	}
}

extern "C" void filesave_requestSavePath(const char* name, const char* mime, value onSelect, value onCancel) {
	if (panel_open_) {
		val_call0(onCancel);
		return;
	}

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

		panel_open_ = true;
		[panel beginSheetModalForWindow:keyWindow
					  completionHandler:^(NSModalResponse result) {
						  // Handler fires inside SDL_WaitEvent (which called gc_enter_blocking).
						  // Temporarily exit blocking to safely call into Haxe, then re-enter.
						  gc_exit_blocking();

						  // Release the shared state BEFORE calling into Haxe: the callback is where the file
						  // actually gets written, so a throwing listener must not leave the panel marked open —
						  // that would refuse every later dialog, save and open alike, for the rest of the session.
						  AutoGCRoot* select_root = on_select_root_;
						  AutoGCRoot* cancel_root = on_cancel_root_;
						  on_select_root_ = nullptr;
						  on_cancel_root_ = nullptr;
						  panel_open_ = false;

						  NSURL* url = result == NSModalResponseOK ? [panel URL] : nil;

						  if (url != nil) {
							  [url startAccessingSecurityScopedResource];
							  if (security_scoped_url_ != nil) [security_scoped_url_ stopAccessingSecurityScopedResource];
							  [security_scoped_url_ release];
							  security_scoped_url_ = [url retain];

							  const char* path = [[url path] UTF8String];
							  if (select_root != nullptr) val_call1(select_root->get(), alloc_string(path));
						  } else if (cancel_root != nullptr) {
							  val_call0(cancel_root->get());
						  }

						  delete select_root;
						  delete cancel_root;

						  gc_enter_blocking();
					  }];
	}
}

extern "C" void
filesave_requestOpenPath(const char* extensions, const char* defaultPath, const char* title, value onSelect, value onCancel) {
	if (panel_open_) {
		val_call0(onCancel);
		return;
	}

	delete on_select_root_;
	delete on_cancel_root_;
	on_select_root_ = new AutoGCRoot(onSelect);
	on_cancel_root_ = new AutoGCRoot(onCancel);

	@autoreleasepool {
		NSOpenPanel* panel = [NSOpenPanel openPanel];
		[panel setCanChooseFiles:YES];
		[panel setCanChooseDirectories:NO];
		[panel setAllowsMultipleSelection:NO];
		[panel setCanCreateDirectories:NO];

		if (defaultPath != NULL && defaultPath[0] != '\0')
			[panel setDirectoryURL:[NSURL fileURLWithPath:[NSString stringWithUTF8String:defaultPath] isDirectory:YES]];

		// setMessage:, not setTitle: — the panel's title property is ignored since macOS 10.11,
		// and a sheet has no title bar at all. The message shows in the panel header.
		if (title != NULL && title[0] != '\0') [panel setMessage:[NSString stringWithUTF8String:title]];

		applyExtensionFilter(panel, extensions);

		NSWindow* keyWindow = [[NSApplication sharedApplication] keyWindow];
		if (keyWindow == nil) {
			val_call0(on_cancel_root_->get());
			delete on_select_root_;
			delete on_cancel_root_;
			on_select_root_ = nullptr;
			on_cancel_root_ = nullptr;
			return;
		}

		panel_open_ = true;
		[panel beginSheetModalForWindow:keyWindow
					  completionHandler:^(NSModalResponse result) {
						  // Handler fires inside SDL_WaitEvent (which called gc_enter_blocking).
						  // Temporarily exit blocking to safely call into Haxe, then re-enter.
						  gc_exit_blocking();

						  // Release the shared state BEFORE calling into Haxe: a throwing listener must not
						  // leave the panel marked open, which would refuse every later dialog this session.
						  AutoGCRoot* select_root = on_select_root_;
						  AutoGCRoot* cancel_root = on_cancel_root_;
						  on_select_root_ = nullptr;
						  on_cancel_root_ = nullptr;
						  panel_open_ = false;

						  NSURL* url = result == NSModalResponseOK ? [panel URL] : nil;

						  if (url != nil) {
							  // Sandboxed builds need scoped access for the synchronous read the callback does.
							  BOOL scoped = [url startAccessingSecurityScopedResource];
							  const char* path = [[url path] UTF8String];
							  if (select_root != nullptr) val_call1(select_root->get(), alloc_string(path));
							  if (scoped) [url stopAccessingSecurityScopedResource];
						  } else if (cancel_root != nullptr) {
							  val_call0(cancel_root->get());
						  }

						  delete select_root;
						  delete cancel_root;

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

extern "C" void filesave_saveFile(const char* src, const char* name, const char* mime, bool as_copy, value callback) {
	if (panel_open_) {
		val_call1(callback, alloc_bool(false));
		return;
	}

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

		panel_open_ = true;
		[panel beginSheetModalForWindow:keyWindow
					  completionHandler:^(NSModalResponse result) {
						  gc_exit_blocking();

						  // Cleared before calling into Haxe — see requestSavePath for why.
						  panel_open_ = false;

						  bool success = false;
						  NSURL* destURL = result == NSModalResponseOK ? [panel URL] : nil;
						  if (destURL != nil) {
							  [destURL startAccessingSecurityScopedResource];

							  NSFileManager* fm = [NSFileManager defaultManager];
							  NSError* removeError = nil;
							  [fm removeItemAtURL:destURL error:&removeError];
							  if (removeError != nil && removeError.code != NSFileNoSuchFileError)
								  NSLog(@"FileSave: removeItemAtURL failed: %@", removeError);

							  NSError* error = nil;
							  if (as_copy)
								  success = [fm copyItemAtPath:sourcePath toPath:[destURL path] error:&error];
							  else
								  success = [fm moveItemAtPath:sourcePath toPath:[destURL path] error:&error];

							  [destURL stopAccessingSecurityScopedResource];
						  }

						  val_call1(callback_root_->get(), alloc_bool(success));
						  delete callback_root_;

						  gc_enter_blocking();
					  }];
	}
}
