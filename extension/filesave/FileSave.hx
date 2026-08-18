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
	// The library name is repeated on purpose: Prime.load is a macro and wants a string LITERAL
	// per call site — passing a constant fails with "haxe.macro.Expr should be String".
	private static final _fs_requestSavePath:Callable<ConstCharStar->ConstCharStar->Object->Object->cpp.Void> = Prime.load(
		'extension_file_save', 'fs_requestSavePath', 'ccoov', false
	);

	private static final _fs_releasePath:Callable<Void->cpp.Void> = Prime.load('extension_file_save', 'fs_releasePath', 'v', false);

	private static final _fs_saveFile:Callable<ConstCharStar->ConstCharStar->ConstCharStar->Bool->Object->cpp.Void> = Prime.load(
		'extension_file_save', 'fs_saveFile', 'cccbov', false
	);

	#if macos
	private static final _fs_requestOpenPath:Callable<ConstCharStar->ConstCharStar->ConstCharStar->Object->Object->cpp.Void> = Prime.load(
		'extension_file_save', 'fs_requestOpenPath', 'cccoov', false
	);
	#end

	/**
	 * Show "Save As" dialog, return chosen path for direct writing.
	 * Caller MUST call releasePath() when done writing.
	 * On Mac sandbox: holds security-scoped access until releasePath().
	 */
	public static inline function requestSavePath(
		suggestedName:String, mimeType:String, onSelect:(path:String)->Void, onCancel:()->Void
	):Void _fs_requestSavePath(suggestedName, mimeType, onSelect, onCancel);

	/**
	 * Show "Open" dialog, return the chosen path for direct reading.
	 * extensions is a comma-separated list without dots ('gif,jpg,png'); empty means any file.
	 * defaultPath is the directory to start in; empty means the system default.
	 * title is shown in the panel header; empty means none.
	 * On Mac the panel is a sheet attached to the app window, so one of the callbacks always fires.
	 */
	public static function requestOpenPath(
		extensions:String, defaultPath:String, title:String, onSelect:(path:String)->Void, onCancel:()->Void
	):Void {
		#if macos
		_fs_requestOpenPath(extensions, defaultPath, title, onSelect, onCancel);
		#else
		onCancel();
		#end
	}

	/** Release security-scoped access acquired by requestSavePath. */
	public static inline function releasePath():Void _fs_releasePath();

	/**
	 * Show file picker, move or copy source file to user-chosen location.
	 * File must already exist at sourcePath.
	 * By default moves the file (source is deleted). Pass asCopy=true to keep the source.
	 */
	public static inline function saveFile(
		sourcePath:String, suggestedName:String, mimeType:String, callback:(success:Bool)->Void, asCopy:Bool = false
	):Void _fs_saveFile(sourcePath, suggestedName, mimeType, asCopy, callback);
	#elseif (windows || linux)
	/**
	 * Show "Save As" dialog, return chosen path for direct writing.
	 * releasePath() is no-op on Windows/Linux.
	 */
	public static function requestSavePath(suggestedName:String, mimeType:String, onSelect:(path:String)->Void, onCancel:()->Void):Void
		browseDialog(FileDialogType.SAVE, extensionFromMime(mimeType), suggestedName, null, onSelect, onCancel);

	/**
	 * Show "Open" dialog, return the chosen path for direct reading.
	 * extensions is a comma-separated list without dots ('gif,jpg,png'); empty means any file.
	 * defaultPath is the directory to start in; empty means the system default.
	 * title is used as the dialog window title; empty means the system default.
	 */
	public static function requestOpenPath(
		extensions:String, defaultPath:String, title:String, onSelect:(path:String)->Void, onCancel:()->Void
	):Void {
		browseDialog(
			FileDialogType.OPEN, extensions == '' ? null : extensions, defaultPath, title == '' ? null : title, onSelect, onCancel
		);
	}

	/** No-op on Windows/Linux. */
	public static inline function releasePath():Void {}

	/**
	 * Show file picker, move or copy source file to user-chosen location.
	 * File must already exist at sourcePath.
	 * By default moves the file (source is deleted). Pass asCopy=true to keep the source.
	 */
	public static function saveFile(
		sourcePath:String, suggestedName:String, mimeType:String, callback:(success:Bool)->Void, asCopy:Bool = false
	):Void {
		browseDialog(FileDialogType.SAVE, extensionFromMime(mimeType), suggestedName, null, path -> {
			try {
				File.saveBytes(path, File.getBytes(sourcePath));
				if (!asCopy) sys.FileSystem.deleteFile(sourcePath);
				callback(true);
			} catch (_:Exception) {
				callback(false);
			}
		}, callback.bind(false));
	}

	private static function browseDialog(
		type:FileDialogType, filter:Null<String>, defaultPath:Null<String>, title:Null<String>, onSelect:(path:String)->Void,
		onCancel:()->Void
	):Void {
		final dialog:FileDialog = new FileDialog();
		dialog.onSelect.add(onSelect);
		dialog.onCancel.add(onCancel);
		dialog.browse(type, filter, defaultPath, title);
	}

	private static function extensionFromMime(mime:String):String {
		return switch mime {
			case 'video/mp4': 'mp4';
			case 'application/pdf': 'pdf';
			case 'image/jpeg': 'jpg';
			case 'image/png': 'png';
			case _: '';
		};
	}
	#elseif android
	private static final _jni_initialize:Dynamic->Void = JNI.createStaticMethod(
		'org.haxe.extension.FileSaveExtension', 'initialize', '(Lorg/haxe/lime/HaxeObject;)V'
	);

	private static final _jni_saveFile:String->String->String->Bool->Void = JNI.createStaticMethod(
		'org.haxe.extension.FileSaveExtension', 'saveFile', '(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Z)V'
	);

	private static var _initialized:Bool = false;

	private static var _saveCallback:Null<(Bool)->Void> = null;

	public static inline function requestSavePath(
		suggestedName:String, mimeType:String, onSelect:(path:String)->Void, onCancel:()->Void
	):Void onCancel();

	/** Not supported on Android — the platform picker is used through saveFile instead. */
	public static inline function requestOpenPath(
		extensions:String, defaultPath:String, title:String, onSelect:(path:String)->Void, onCancel:()->Void
	):Void onCancel();

	public static inline function releasePath():Void {}

	/**
	 * Show file picker, move or copy source file to user-chosen location.
	 * File must already exist at sourcePath.
	 * By default moves the file (source is deleted). Pass asCopy=true to keep the source.
	 */
	public static function saveFile(
		sourcePath:String, suggestedName:String, mimeType:String, callback:(success:Bool)->Void, asCopy:Bool = false
	):Void {
		_ensureInit();
		if (_saveCallback != null) _saveCallback(false);
		_saveCallback = callback;
		_jni_saveFile(sourcePath, suggestedName, mimeType, asCopy);
	}

	private static function _ensureInit():Void {
		if (_initialized) return;
		_jni_initialize(new AndroidHandler());
		_initialized = true;
	}
	#end

}

#if android
@:access(extension.filesave.FileSave)
@:nullSafety(Strict) private final class AndroidHandler {

	public function new() {}

	public function onSaveResult(success:Dynamic):Void {
		final cb:Null<(Bool)->Void> = FileSave._saveCallback;
		FileSave._saveCallback = null;
		if (cb != null) cb(cast success);
	}

}
#end
