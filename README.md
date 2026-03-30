# extension-file-save

[![Build](https://img.shields.io/github/actions/workflow/status/soccertutor/extension-file-save/build.yml)](https://github.com/soccertutor/extension-file-save/actions/workflows/build.yml) [![Haxelib](https://img.shields.io/badge/haxelib-v0.3.4-blue)](https://lib.haxe.org/p/extension-file-save/) [![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A cross-platform OpenFL/Lime native extension for saving files via native OS file pickers. Supports desktop (direct path write) and mobile (copy-to-destination) workflows.

## Platform Support

| Platform | Implementation |
|----------|----------------|
| macOS    | `NSSavePanel` (security-scoped URL) |
| Windows  | Lime `FileDialog` wrapper |
| Linux    | Lime `FileDialog` wrapper |
| iOS      | `UIDocumentPickerViewController` |
| Android  | `ACTION_CREATE_DOCUMENT` Intent |

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

Or directly via hxcpp:

```sh
haxelib run hxcpp project/Build.xml -D<platform> -DHXCPP_ARM64
```

| Target   | lime rebuild          | hxcpp flags                    |
|----------|-----------------------|--------------------------------|
| macOS    | `lime rebuild . macos -release`  | `-Dmacos -DHXCPP_ARM64`  |
| iOS      | `lime rebuild . ios -release`    | `-Diphoneos -DHXCPP_ARM64`|
| Android  | Built automatically by Gradle    |                           |

Windows and Linux use Lime's built-in `FileDialog` and do not require a native library build.

## macOS Sandbox Note

`requestSavePath` calls `NSSavePanel` and retains a security-scoped URL for the chosen file. This keeps sandbox access open while your code writes to the path. Call `releasePath()` as soon as writing is complete to release the resource.

## License

MIT
