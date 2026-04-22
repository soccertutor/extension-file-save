package extension.filesave;

#if (macos || ios)
import cpp.Callable;
import cpp.ConstCharStar;
import cpp.Object;
import cpp.Prime;
#elseif android
import lime.system.JNI;
#elseif (windows || linux)
import haxe.Exception;

import lime.ui.FileDialog;
import lime.ui.FileDialogType;

import sys.io.File;
#end

/**
 * Cross-platform file save dialog.
 *
 * Desktop: requestSavePath → write directly to path → releasePath.
 * Mobile: saveFile moves (default) or copies an existing file to user-chosen location.
 */
@:nullSafety(Strict) final class FileSave {

	#if (macos || ios)
	private static final _fs_requestSavePath: Callable<ConstCharStar -> ConstCharStar -> Object -> Object ->
		cpp.Void> = Prime.load('extension_file_save', 'fs_requestSavePath', 'ccoov', false);

	private static final _fs_releasePath: Callable<Void -> cpp.Void> = Prime.load('extension_file_save', 'fs_releasePath', 'v', false);

	private static final _fs_saveFile: Callable<ConstCharStar -> ConstCharStar -> ConstCharStar -> Bool -> Object ->
		cpp.Void> = Prime.load('extension_file_save', 'fs_saveFile', 'cccbov', false);

	/**
	 * Show "Save As" dialog, return chosen path for direct writing.
	 * Caller MUST call releasePath() when done writing.
	 * On Mac sandbox: holds security-scoped access until releasePath().
	 */
	public static function requestSavePath(suggestedName: String, mimeType: String, onSelect: (path: String) -> Void,
			onCancel: () -> Void): Void _fs_requestSavePath(suggestedName, mimeType, onSelect, onCancel);

	/** Release security-scoped access acquired by requestSavePath. */
	public static function releasePath(): Void _fs_releasePath();

	/**
	 * Show file picker, move or copy source file to user-chosen location.
	 * File must already exist at sourcePath.
	 * By default moves the file (source is deleted). Pass asCopy=true to keep the source.
	 */
	public static function saveFile(sourcePath: String, suggestedName: String, mimeType: String, callback: (success: Bool) -> Void,
			asCopy: Bool = false): Void _fs_saveFile(sourcePath, suggestedName, mimeType, asCopy, callback);

	#elseif (windows || linux)
	/**
	 * Show "Save As" dialog, return chosen path for direct writing.
	 * releasePath() is no-op on Windows/Linux.
	 */
	public static function requestSavePath(suggestedName: String, mimeType: String, onSelect: (path: String) -> Void,
			onCancel: () -> Void): Void {
		final dialog: FileDialog = new FileDialog();
		dialog.onSelect.add(onSelect);
		dialog.onCancel.add(onCancel);
		dialog.browse(FileDialogType.SAVE, extensionFromMime(mimeType), suggestedName);
	}

	/** No-op on Windows/Linux. */
	public static function releasePath(): Void {}

	/**
	 * Show file picker, move or copy source file to user-chosen location.
	 * File must already exist at sourcePath.
	 * By default moves the file (source is deleted). Pass asCopy=true to keep the source.
	 */
	public static function saveFile(sourcePath: String, suggestedName: String, mimeType: String, callback: (success: Bool) -> Void,
			asCopy: Bool = false): Void {
		final dialog: FileDialog = new FileDialog();
		dialog.onSelect.add(path -> {
			try {
				File.saveBytes(path, File.getBytes(sourcePath));
				if (!asCopy)
					sys.FileSystem.deleteFile(sourcePath);
				callback(true);
			} catch (exception:Exception) {
				callback(false);
			}
		});
		dialog.onCancel.add(() -> callback(false));
		dialog.browse(FileDialogType.SAVE, extensionFromMime(mimeType), suggestedName);
	}

	private static function extensionFromMime(mime: String): String {
		return switch mime {
			case 'video/mp4': 'mp4';
			case 'application/pdf': 'pdf';
			case 'image/jpeg': 'jpg';
			case 'image/png': 'png';
			case _: '';
		};
	}
	#elseif android
	private static final _jni_initialize: Dynamic -> Void = JNI.createStaticMethod('org.haxe.extension.FileSaveExtension', 'initialize',
		'(Lorg/haxe/lime/HaxeObject;)V');

	private static final _jni_saveFile: String -> String -> String -> Bool ->
		Void = JNI.createStaticMethod('org.haxe.extension.FileSaveExtension', 'saveFile',
		'(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Z)V');

	private static var _initialized: Bool = false;

	private static var _saveCallback: Null<(Bool) -> Void> = null;

	private static function _ensureInit(): Void {
		if (!_initialized) {
			_jni_initialize(new AndroidHandler());
			_initialized = true;
		}
	}

	public static function requestSavePath(suggestedName: String, mimeType: String, onSelect: (path: String) -> Void,
			onCancel: () -> Void): Void onCancel();

	public static function releasePath(): Void {}

	/**
	 * Show file picker, move or copy source file to user-chosen location.
	 * File must already exist at sourcePath.
	 * By default moves the file (source is deleted). Pass asCopy=true to keep the source.
	 */
	public static function saveFile(sourcePath: String, suggestedName: String, mimeType: String, callback: (success: Bool) -> Void,
			asCopy: Bool = false): Void {
		_ensureInit();
		if (_saveCallback != null)
			_saveCallback(false);
		_saveCallback = callback;
		_jni_saveFile(sourcePath, suggestedName, mimeType, asCopy);
	}
	#end

}

#if android
@:access(extension.filesave.FileSave)
@:nullSafety(Strict) private final class AndroidHandler {

	public function new() {}

	public function onSaveResult(success: Dynamic): Void {
		final cb: Null<(Bool) -> Void> = FileSave._saveCallback;
		FileSave._saveCallback = null;
		if (cb != null)
			cb(cast success);
	}

}
#end