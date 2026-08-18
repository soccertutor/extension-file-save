# extension-file-save

[![Build](https://img.shields.io/github/actions/workflow/status/soccertutor/extension-file-save/build.yml)](https://github.com/soccertutor/extension-file-save/actions/workflows/build.yml) [![Haxelib](https://img.shields.io/badge/haxelib-v0.3.9-blue)](https://lib.haxe.org/p/extension-file-save/) [![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A cross-platform OpenFL/Lime native extension for native OS file pickers — saving (desktop direct-path write, mobile copy-to-destination) and, on desktop, opening.

## Platform Support

| Platform | Save                                | Open                      |
| -------- | ----------------------------------- | ------------------------- |
| macOS    | `NSSavePanel` (security-scoped URL) | `NSOpenPanel`             |
| Windows  | Lime `FileDialog` wrapper           | Lime `FileDialog` wrapper |
| Linux    | Lime `FileDialog` wrapper           | Lime `FileDialog` wrapper |
| iOS      | `UIDocumentPickerViewController`    | not supported             |
| Android  | `ACTION_CREATE_DOCUMENT` Intent     | not supported             |

On macOS both panels are shown as a **sheet attached to the app window** (`beginSheetModalForWindow:`), so the dialog cannot end up behind the window or on another Space, and the completion handler always fires. Where a platform does not support an operation, its function calls the cancel/failure callback immediately rather than doing nothing.

## Installation

```sh
haxelib dev extension-file-save path/to/extension-file-save
```

Add to `project.xml`:

```xml
<haxelib name="extension-file-save" />
```

## API

### Desktop — `requestSavePath` / `releasePath`

The user picks a save location; your code writes directly to that path. On macOS the extension holds a security-scoped bookmark until `releasePath()` is called.

```haxe
// Ask the user where to save, then write directly to the returned path
FileSave.requestSavePath('animation.mp4', 'video/mp4', (path:String) -> {
    beginEncoding(path, () -> {
        FileSave.releasePath(); // Release security-scoped access (macOS sandbox)
    });
}, () -> {
    trace('User cancelled');
});
```

### Desktop — `requestOpenPath`

The user picks an existing file; your code reads it directly from the returned path. `extensions` is a comma-separated list without dots (empty = any file), `defaultPath` is the directory to start in (empty = system default), `title` labels the dialog (empty = none — the panel header on macOS, the window title on Windows/Linux).

```haxe
FileSave.requestOpenPath('gif,jpg,jpeg,png', '', 'Select an image', (path:String) -> {
    final bytes:Bytes = sys.io.File.getBytes(path);
    // ...
}, () -> {
    trace('User cancelled');
});
```

Read the file **inside the callback**: on macOS the extension holds sandbox access to the chosen file only for the duration of that call. Do NOT call `releasePath()` afterwards — it belongs to `requestSavePath` and would release that panel's URL instead.

### Mobile — `saveFile`

Copies an existing file to a user-chosen location via the native picker.

```haxe
FileSave.saveFile('/tmp/output.mp4', 'animation.mp4', 'video/mp4', (success:Bool) -> {
    if (success) trace('Saved');
});
```

## Building the Native Library

```sh
lime rebuild . <target> -release
```

Or directly via hxcpp — **run it from `project/`**, not from the repository root:

```sh
cd project
haxelib run hxcpp Build.xml -D<platform> -DHXCPP_ARM64
```

`Build.xml` declares `<outdir name="../ndll/${BINDIR}" />`, and a relative `outdir` is resolved against the **current working directory**, not the Build.xml location. Invoked from the repository root it writes to `../ndll/` *above* the repository while still printing `Link: ../ndll/…` and exiting 0 — the build looks fine and the app keeps linking the old library. `lime rebuild` handles the directory itself, so it is the safer entry point.

| Target  | lime rebuild                    | hxcpp flags (from `project/`)      |
| ------- | ------------------------------- | ---------------------------------- |
| macOS   | `lime rebuild . macos -release` | `-Dmacos -DHXCPP_ARM64`            |
| macOS   | `lime rebuild . macos -64 -release` | `-Dmacos -DHXCPP_M64`          |
| iOS     | `lime rebuild . ios -release`   | `-Diphoneos -DHXCPP_ARM64`         |
| Android | Built automatically by Gradle   |                                    |

macOS ships as a universal binary, so both architectures must be built before a release. Verify a rebuild landed by checking the artifact rather than the exit status:

```sh
nm -gU ndll/MacArm64/extension_file_save.ndll | grep fs_request
```

Windows and Linux use Lime's built-in `FileDialog` and do not require a native library build.

## macOS Sandbox Note

`requestSavePath` calls `NSSavePanel` and retains a security-scoped URL for the chosen file. This keeps sandbox access open while your code writes to the path. Call `releasePath()` as soon as writing is complete to release the resource.

`requestOpenPath` calls `NSOpenPanel` and holds access only for the duration of its own callback — nothing is retained, and `releasePath()` must not be called for it. A sandboxed app needs `com.apple.security.files.user-selected.read-write` (or `read-only` if it never writes); the panel itself runs out-of-process in the powerbox, which is what extends the sandbox to the file the user picked.

This is also why a sandboxed app must not fall back to Lime's `FileDialog` on macOS: that path goes through tinyfiledialogs, which shells out to `osascript` via `popen`, and the sandbox denies executing binaries outside the app bundle.

## License

MIT
