package com.apuwaqay.apu_waqay

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.apuwaqay/sms"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendDirectSMS") {
                val phone = call.argument<String>("phone")
                val msg = call.argument<String>("msg")

                if (phone != null && msg != null) {
                    sendSMS(phone, msg, result)
                } else {
                    result.error("INVALID_ARGS", "Número o mensaje nulo", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun sendSMS(phone: String, msg: String, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Permiso SEND_SMS no concedido", null)
            return
        }

        try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                this.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            val uniqueId = UUID.randomUUID().toString()
            val sentAction = "SMS_SENT_$uniqueId"

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val sentIntent = PendingIntent.getBroadcast(this, 0, Intent(sentAction), flags)

            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    try {
                        context?.unregisterReceiver(this)
                    } catch (e: Exception) {
                        // Ignorar si ya fue desregistrado
                    }

                    when (resultCode) {
                        Activity.RESULT_OK -> result.success(true)
                        SmsManager.RESULT_ERROR_GENERIC_FAILURE -> result.error("GENERIC_FAILURE", "Falla genérica de red", null)
                        SmsManager.RESULT_ERROR_NO_SERVICE -> result.error("NO_SERVICE", "Sin señal/servicio", null)
                        SmsManager.RESULT_ERROR_NULL_PDU -> result.error("NULL_PDU", "PDU nulo", null)
                        SmsManager.RESULT_ERROR_RADIO_OFF -> result.error("RADIO_OFF", "Modo avión / Radio apagado", null)
                        else -> result.error("UNKNOWN_ERROR", "Error desconocido: $resultCode", null)
                    }
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, IntentFilter(sentAction), Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(receiver, IntentFilter(sentAction))
            }

            // Uso de Multipart para garantizar que enlaces largos de GPS no fallen silenciosamente
            val parts = smsManager.divideMessage(msg)
            if (parts.size > 1) {
                val sentIntents = ArrayList<PendingIntent>()
                for (i in parts.indices) {
                    // Solo evaluamos el intent de la última parte para confirmar el envío total
                    if (i == parts.size - 1) {
                        sentIntents.add(sentIntent)
                    } else {
                        val dummyIntent = PendingIntent.getBroadcast(this, i + 1, Intent(sentAction + "_dummy"), flags)
                        sentIntents.add(dummyIntent)
                    }
                }
                smsManager.sendMultipartTextMessage(phone, null, parts, sentIntents, null)
            } else {
                smsManager.sendTextMessage(phone, null, msg, sentIntent, null)
            }

        } catch (e: Exception) {
            result.error("EXCEPTION", e.message, null)
        }
    }
}