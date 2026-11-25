package com.uemsihtv.hdexpress

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileInputStream

/**
 * Saves images/videos into the device gallery via MediaStore.
 * Does not require READ_MEDIA_IMAGES / READ_MEDIA_VIDEO (Android 10+).
 */
object GalleryMediaStore {
  private const val album = "HD Express Camera"

  fun saveImage(context: Context, bytes: ByteArray, filename: String): String {
    val name = filename.ifBlank { "UEMSI_${System.currentTimeMillis()}.jpg" }
    val mime = mimeForImage(name)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val values = ContentValues().apply {
        put(MediaStore.Images.Media.DISPLAY_NAME, name)
        put(MediaStore.Images.Media.MIME_TYPE, mime)
        put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/$album")
        put(MediaStore.Images.Media.IS_PENDING, 1)
      }
      val resolver = context.contentResolver
      val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        ?: throw IllegalStateException("Could not create gallery item")
      try {
        resolver.openOutputStream(uri)?.use { it.write(bytes) }
          ?: throw IllegalStateException("Could not write photo")
        values.clear()
        values.put(MediaStore.Images.Media.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return uri.toString()
      } catch (e: Exception) {
        resolver.delete(uri, null, null)
        throw e
      }
    }

    val dir = File(
      Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
      album,
    )
    if (!dir.exists() && !dir.mkdirs()) {
      throw IllegalStateException("Could not create Pictures/$album")
    }
    val outFile = uniqueFile(dir, name)
    outFile.outputStream().use { it.write(bytes) }
    MediaScannerConnection.scanFile(context, arrayOf(outFile.absolutePath), arrayOf(mime), null)
    return outFile.absolutePath
  }

  fun saveVideo(context: Context, path: String, title: String): String {
    val src = File(path)
    if (!src.exists() || src.length() == 0L) {
      throw IllegalStateException("Recording file missing or empty")
    }
    val name = when {
      title.endsWith(".mp4", ignoreCase = true) -> title
      title.isNotBlank() -> "$title.mp4"
      else -> "UEMSI_${System.currentTimeMillis()}.mp4"
    }
    val mime = "video/mp4"

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val values = ContentValues().apply {
        put(MediaStore.Video.Media.DISPLAY_NAME, name)
        put(MediaStore.Video.Media.MIME_TYPE, mime)
        put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MOVIES}/$album")
        put(MediaStore.Video.Media.IS_PENDING, 1)
      }
      val resolver = context.contentResolver
      val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
        ?: throw IllegalStateException("Could not create gallery video")
      try {
        resolver.openOutputStream(uri)?.use { out ->
          FileInputStream(src).use { input -> input.copyTo(out) }
        } ?: throw IllegalStateException("Could not write video")
        values.clear()
        values.put(MediaStore.Video.Media.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return uri.toString()
      } catch (e: Exception) {
        resolver.delete(uri, null, null)
        throw e
      }
    }

    val dir = File(
      Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES),
      album,
    )
    if (!dir.exists() && !dir.mkdirs()) {
      throw IllegalStateException("Could not create Movies/$album")
    }
    val outFile = uniqueFile(dir, name)
    FileInputStream(src).use { input ->
      outFile.outputStream().use { output -> input.copyTo(output) }
    }
    MediaScannerConnection.scanFile(context, arrayOf(outFile.absolutePath), arrayOf(mime), null)
    return outFile.absolutePath
  }

  private fun mimeForImage(filename: String): String {
    val lower = filename.lowercase()
    return when {
      lower.endsWith(".png") -> "image/png"
      lower.endsWith(".webp") -> "image/webp"
      else -> "image/jpeg"
    }
  }

  private fun uniqueFile(dir: File, name: String): File {
    val dest = File(dir, name)
    if (!dest.exists()) return dest
    val dot = name.lastIndexOf('.')
    val stem = if (dot > 0) name.substring(0, dot) else name
    val ext = if (dot > 0) name.substring(dot) else ""
    var i = 2
    while (true) {
      val candidate = File(dir, "${stem}_$i$ext")
      if (!candidate.exists()) return candidate
      i++
    }
  }
}
