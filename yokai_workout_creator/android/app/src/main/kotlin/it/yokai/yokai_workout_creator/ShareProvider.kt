package it.yokai.yokai_workout_creator

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File
import java.io.FileNotFoundException

/** Read-only provider. Only a specific shared cache image can be granted. */
class ShareProvider : ContentProvider() {
    override fun onCreate() = true
    private fun resolve(uri: Uri): File {
        val ctx = context ?: throw FileNotFoundException()
        if (uri.authority != "${ctx.packageName}.shared" || uri.pathSegments.size != 1) throw FileNotFoundException()
        val name = uri.lastPathSegment ?: throw FileNotFoundException()
        if (!Regex("^YOKAI_[0-9]+\\.(png|jpg)$").matches(name)) throw FileNotFoundException()
        val base = File(ctx.cacheDir, "shared").canonicalFile
        val file = File(base, name).canonicalFile
        if (file.parentFile != base || !file.isFile) throw FileNotFoundException()
        return file
    }
    override fun getType(uri: Uri): String = if (resolve(uri).extension == "jpg") "image/jpeg" else "image/png"
    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("Read only")
        return ParcelFileDescriptor.open(resolve(uri), ParcelFileDescriptor.MODE_READ_ONLY)
    }
    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor {
        val file = resolve(uri)
        val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val cursor = MatrixCursor(columns)
        cursor.addRow(columns.map { when (it) {
            OpenableColumns.DISPLAY_NAME -> file.name
            OpenableColumns.SIZE -> file.length()
            else -> null
        } }.toTypedArray())
        return cursor
    }
    override fun insert(uri: Uri, values: ContentValues?): Uri? = throw UnsupportedOperationException()
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = throw UnsupportedOperationException()
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = throw UnsupportedOperationException()
}
