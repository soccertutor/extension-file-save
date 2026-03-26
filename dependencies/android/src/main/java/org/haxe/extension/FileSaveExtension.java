package org.haxe.extension;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import org.haxe.extension.Extension;
import org.haxe.lime.HaxeObject;

public class FileSaveExtension extends Extension {

    private static final int REQUEST_CODE = 0x4653;
    private static HaxeObject callback;
    private static String pendingSourcePath;
    private static boolean pendingAsCopy;

    public static void initialize(HaxeObject cb) {
        callback = cb;
    }

    public static void saveFile(
        String sourcePath,
        String suggestedName,
        String mimeType,
        boolean asCopy
    ) {
        pendingSourcePath = sourcePath;
        pendingAsCopy = asCopy;

        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType(
            mimeType != null && !mimeType.isEmpty() ? mimeType : "*/*"
        );
        intent.putExtra(Intent.EXTRA_TITLE, suggestedName);

        mainActivity.startActivityForResult(intent, REQUEST_CODE);
    }

    @Override
    public boolean onActivityResult(
        int requestCode,
        int resultCode,
        Intent data
    ) {
        if (requestCode != REQUEST_CODE) return true;

        boolean success = false;
        if (
            resultCode == Activity.RESULT_OK &&
            data != null &&
            data.getData() != null
        ) {
            try {
                copyFile(pendingSourcePath, data.getData());
                if (!pendingAsCopy) new File(pendingSourcePath).delete();
                success = true;
            } catch (Exception e) {
                Log.e("FileSaveExtension", "copyFile failed", e);
            }
        }
        pendingSourcePath = null;
        fireCallback("onSaveResult", new Object[] { success });

        return false;
    }

    private static void copyFile(String srcPath, Uri destUri)
        throws IOException {
        try (
            InputStream in = new FileInputStream(srcPath);
            OutputStream out = mainActivity
                .getContentResolver()
                .openOutputStream(destUri)
        ) {
            if (out == null) throw new IOException(
                "openOutputStream returned null"
            );
            final byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = in.read(buffer)) != -1) {
                out.write(buffer, 0, bytesRead);
            }
            out.flush();
        }
    }

    private static void fireCallback(
        final String name,
        final Object[] payload
    ) {
        if (Extension.mainView == null || callback == null) return;
        if (Extension.mainView instanceof android.opengl.GLSurfaceView) {
            ((android.opengl.GLSurfaceView) Extension.mainView).queueEvent(
                new Runnable() {
                    @Override
                    public void run() {
                        callback.call(name, payload);
                    }
                }
            );
        } else {
            Extension.mainActivity.runOnUiThread(
                new Runnable() {
                    @Override
                    public void run() {
                        callback.call(name, payload);
                    }
                }
            );
        }
    }
}
