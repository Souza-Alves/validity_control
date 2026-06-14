package com.controlevalidades.controle_validades

import android.content.ContentValues
import android.content.Context
import android.graphics.BitmapFactory
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class CameraImageSaverPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "camera_image_saver")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "saveImageToCamera" -> {
                val imageBytes = call.argument<ByteArray>("imageBytes")
                val quality = call.argument<Int>("quality") ?: 100
                val name = call.argument<String>("name")
                val uri = saveImageToCamera(imageBytes, quality, name)
                result.success(uri)
            }
            else -> result.notImplemented()
        }
    }

    private fun saveImageToCamera(imageBytes: ByteArray?, quality: Int, name: String?): String? {
        if (imageBytes == null || imageBytes.isEmpty()) {
            return null
        }

        val context = applicationContext ?: return null
        val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size) ?: return null

        return try {
            val fileName = name ?: "controle_validades_${System.currentTimeMillis()}"
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, "DCIM/Camera")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                } else {
                    put(MediaStore.MediaColumns.DATA, File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM), "Camera/$fileName.jpg").absolutePath)
                }
            }

            val uri = context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            if (uri != null) {
                context.contentResolver.openOutputStream(uri)?.use { output ->
                    bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, quality.coerceIn(0, 100), output)
                    output.flush()
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    values.clear()
                    values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    context.contentResolver.update(uri, values, null, null)
                }

                MediaScannerConnection.scanFile(context, arrayOf(uri.toString()), arrayOf("image/jpeg"), null)
                uri.toString()
            } else {
                null
            }
        } catch (_: IOException) {
            null
        } finally {
            bitmap.recycle()
        }
    }
}
