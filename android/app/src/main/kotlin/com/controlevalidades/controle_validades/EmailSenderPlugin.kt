package com.controlevalidades.controle_validades

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.text.Html
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Abre um seletor (chooser) de apps de e-mail com corpo HTML.
class EmailSenderPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "email_sender")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sendEmail" -> {
                val subject = call.argument<String>("subject") ?: ""
                val htmlBody = call.argument<String>("htmlBody") ?: ""
                val richBody = call.argument<String>("richBody") ?: htmlBody
                val sent = sendEmail(subject, htmlBody, richBody)
                result.success(sent)
            }
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun sendEmail(subject: String, htmlBody: String, richBody: String): Boolean {
        val intent = Intent(Intent.ACTION_SENDTO).apply {
            data = Uri.parse("mailto:")
            putExtra(Intent.EXTRA_SUBJECT, subject)
            // O corpo visivel usa o HTML "rich" (negrito + <br>), que o Gmail
            // renderiza. Tabelas HTML nao sao suportadas pelo Html.fromHtml.
            val spanned = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                Html.fromHtml(richBody, Html.FROM_HTML_MODE_LEGACY)
            } else {
                Html.fromHtml(richBody)
            }
            putExtra(Intent.EXTRA_TEXT, spanned)
            putExtra(Intent.EXTRA_HTML_TEXT, htmlBody)
        }

        val chooser = Intent.createChooser(intent, "Enviar e-mail")

        return try {
            val act = activity
            if (act != null) {
                act.startActivity(chooser)
            } else {
                val ctx = applicationContext ?: return false
                chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                ctx.startActivity(chooser)
            }
            true
        } catch (_: Exception) {
            false
        }
    }
}
