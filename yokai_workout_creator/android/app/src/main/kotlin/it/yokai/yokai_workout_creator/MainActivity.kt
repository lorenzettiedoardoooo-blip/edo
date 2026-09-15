package it.yokai.yokai_workout_creator

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.AtomicFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private var logoResult: MethodChannel.Result? = null
    private var pendingSave: Pair<MethodCall, MethodChannel.Result>? = null
    private val logoRequest = 9001
    private val storageRequest = 9002
    private fun documents(): File = File(filesDir, "workouts").apply { mkdirs() }
    private fun fileFor(id: String): File {
        require(Regex("^\\d+-\\d+$").matches(id)) { "ID workout non valido" }
        return File(documents(), "$id.json")
    }
    private fun async(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            try {
                val response = work()
                runOnUiThread { result.success(response) }
            } catch (e: Exception) {
                runOnUiThread { result.error("YOKAI_IO", e.message ?: "Operazione non riuscita", null) }
            }
        }
    }
    private fun atomicWrite(file: File, data: ByteArray) {
        file.parentFile?.mkdirs()
        val atomic = AtomicFile(file)
        val stream = atomic.startWrite()
        try { stream.write(data); atomic.finishWrite(stream) }
        catch (e: Exception) { atomic.failWrite(stream); throw e }
    }
    private fun atomicRead(file: File): String = AtomicFile(file).openRead().use { it.readBytes().toString(Charsets.UTF_8) }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "it.yokai.workout/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readWorkouts" -> async(result) {
                        val files = documents().listFiles() ?: throw IllegalStateException("Archivio non accessibile")
                        files.map { it.name.removeSuffix(".bak") }
                            .filter { it.endsWith(".json") }.distinct().sorted()
                            .map { atomicRead(File(documents(), it)) }
                    }
                    "writeWorkout" -> async(result) {
                        val file = fileFor(requireNotNull(call.argument<String>("id")))
                        atomicWrite(file, requireNotNull(call.argument<String>("json")).toByteArray(Charsets.UTF_8)); null
                    }
                    "deleteWorkout" -> async(result) {
                        val file = fileFor(requireNotNull(call.argument<String>("id")))
                        AtomicFile(file).delete()
                        check(!file.exists() && !File(file.path + ".bak").exists()) { "Impossibile eliminare il workout" }
                        null
                    }
                    "readSettings" -> async(result) {
                        val f = File(filesDir, "settings.json")
                        if (f.exists() || File(f.path + ".bak").exists()) atomicRead(f) else null
                    }
                    "writeSettings" -> async(result) {
                        atomicWrite(File(filesDir, "settings.json"), requireNotNull(call.argument<String>("json")).toByteArray(Charsets.UTF_8)); null
                    }
                    "pickLogo" -> pickLogo(result)
                    "encodeJpg" -> async(result) {
                        val bytes = requireNotNull(call.argument<ByteArray>("bytes"))
                        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                            ?: throw IllegalArgumentException("Immagine non valida")
                        try { ByteArrayOutputStream().use { output ->
                            check(bitmap.compress(Bitmap.CompressFormat.JPEG, 95, output)); output.toByteArray()
                        } } finally { bitmap.recycle() }
                    }
                    "saveImage" -> {
                        if (Build.VERSION.SDK_INT < 29 && checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                            if (pendingSave != null) result.error("BUSY", "Salvataggio già in corso", null)
                            else {
                                pendingSave = Pair(call, result)
                                requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), storageRequest)
                            }
                        } else async(result) { saveImage(call); true }
                    }
                    "shareImage" -> shareImage(call, result)
                    else -> result.notImplemented()
                }
            }
    }
    private fun pickLogo(result: MethodChannel.Result) {
        if (logoResult != null) { result.error("BUSY", "Selezione logo già aperta", null); return }
        logoResult = result
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "image/*"
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivityForResult(intent, logoRequest)
        } catch (e: Exception) { logoResult = null; result.error("PICK_LOGO", e.message, null) }
    }
    @Deprecated("Activity result compatibility for FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != logoRequest) return
        val result = logoResult ?: return
        logoResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return }
        async(result) {
            // Decode bounds first: avoid allocating a full-resolution camera image.
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            contentResolver.openInputStream(uri).use { stream ->
                requireNotNull(stream) { "Logo non accessibile" }
                BitmapFactory.decodeStream(stream, null, bounds)
            }
            require(bounds.outWidth > 0 && bounds.outHeight > 0) { "Scegli un’immagine PNG, JPG o WebP" }
            var sample = 1
            while (bounds.outWidth / sample > 1600 || bounds.outHeight / sample > 1600) sample *= 2
            val options = BitmapFactory.Options().apply { inSampleSize = sample }
            val bitmap = contentResolver.openInputStream(uri).use { stream ->
                requireNotNull(stream)
                BitmapFactory.decodeStream(stream, null, options)
            } ?: throw IllegalArgumentException("Logo non decodificabile")
            try { ByteArrayOutputStream().use { output ->
                check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)); output.toByteArray()
            } } finally { bitmap.recycle() }
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != storageRequest) return
        val request = pendingSave ?: return
        pendingSave = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            async(request.second) { saveImage(request.first); true }
        } else request.second.error("PERMISSION", "Permesso galleria negato. Puoi usare SHARE o riprovare SAVE IMAGE.", null)
    }
    private fun imageArguments(call: MethodCall): Triple<ByteArray, String, String> {
        val bytes = requireNotNull(call.argument<ByteArray>("bytes"))
        val format = call.argument<String>("format")
        require(format == "png" || format == "jpg")
        val name = requireNotNull(call.argument<String>("name"))
        require(Regex("^YOKAI_[0-9]+\\.(png|jpg)$").matches(name))
        return Triple(bytes, name, if (format == "jpg") "image/jpeg" else "image/png")
    }
    private fun saveImage(call: MethodCall) {
        val (bytes, name, mime) = imageArguments(call)
        if (Build.VERSION.SDK_INT >= 29) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                put(MediaStore.Images.Media.MIME_TYPE, mime)
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/YOKAI")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Impossibile creare il file in galleria")
            try {
                contentResolver.openOutputStream(uri).use { stream ->
                    requireNotNull(stream) { "Galleria non scrivibile" }; stream.write(bytes)
                }
                values.clear(); values.put(MediaStore.Images.Media.IS_PENDING, 0)
                check(contentResolver.update(uri, values, null, null) > 0)
            } catch (e: Exception) { contentResolver.delete(uri, null, null); throw e }
        } else {
            @Suppress("DEPRECATION")
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "YOKAI")
            check(dir.exists() || dir.mkdirs()) { "Galleria non accessibile" }
            val file = File(dir, name)
            atomicWrite(file, bytes)
            MediaScannerConnection.scanFile(this, arrayOf(file.absolutePath), arrayOf(mime), null)
        }
    }
    private fun shareImage(call: MethodCall, result: MethodChannel.Result) {
        worker.execute {
            try {
                val (bytes, name, mime) = imageArguments(call)
                val folder = File(cacheDir, "shared").apply { mkdirs() }
                // Keep exports long enough for receiving apps to open their streams.
                folder.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 7 * 24 * 60 * 60 * 1000L }
                    ?.forEach { it.delete() }
                val file = File(folder, name)
                file.writeBytes(bytes)
                val uri = Uri.Builder().scheme("content").authority("$packageName.shared").appendPath(name).build()
                runOnUiThread {
                    try {
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = mime; putExtra(Intent.EXTRA_STREAM, uri)
                            clipData = ClipData.newRawUri("YOKAI workout", uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(intent, "Condividi workout YOKAI"))
                        result.success(null)
                    } catch (e: Exception) { result.error("SHARE", e.message, null) }
                }
            } catch (e: Exception) { runOnUiThread { result.error("SHARE", e.message, null) } }
        }
    }
    override fun onDestroy() {
        logoResult?.error("CANCELLED", "Selezione interrotta", null); logoResult = null
        pendingSave?.second?.error("CANCELLED", "Salvataggio interrotto", null); pendingSave = null
        worker.shutdown()
        super.onDestroy()
    }
}
