#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <hx/CFFI.h>

// File-scope statics
static AutoGCRoot* callback_root_ = nullptr;
static id delegate_ = nil;

@interface FileSaveDelegate : NSObject <UIDocumentPickerDelegate>
@end

@implementation FileSaveDelegate

- (void)documentPicker:(UIDocumentPickerViewController*)controller
didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
    if (callback_root_) {
        value cb = callback_root_->get();
        delete callback_root_;
        callback_root_ = nullptr;
        val_call1(cb, alloc_bool(true));
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller {
    if (callback_root_) {
        value cb = callback_root_->get();
        delete callback_root_;
        callback_root_ = nullptr;
        val_call1(cb, alloc_bool(false));
    }
}

@end

extern "C" {

void filesave_requestSavePath(const char* name, const char* mime, value onSelect, value onCancel) {
    val_call0(onCancel);
}

void filesave_releasePath(void) {
    // no-op on iOS
}

void filesave_saveFile(const char* src, const char* name, const char* mime, value callback) {
    // Store callback in AutoGCRoot for async use
    if (callback_root_) {
        delete callback_root_;
        callback_root_ = nullptr;
    }
    callback_root_ = new AutoGCRoot(callback);

    // Allocate delegate singleton on first use
    if (!delegate_) {
        delegate_ = [[FileSaveDelegate alloc] init];
    }

    NSURL* fileURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:src]];

    UIDocumentPickerViewController* picker = nil;
    if (@available(iOS 14.0, *)) {
        picker = [[UIDocumentPickerViewController alloc]
                  initForExportingURLs:@[fileURL]];
    } else {
        picker = [[UIDocumentPickerViewController alloc]
                  initWithURL:fileURL
                       inMode:UIDocumentPickerModeExportToService];
    }

    picker.delegate = delegate_;

    UIViewController* root =
        [UIApplication sharedApplication].keyWindow.rootViewController;
    [root presentViewController:picker animated:YES completion:nil];
}

} // extern "C"
