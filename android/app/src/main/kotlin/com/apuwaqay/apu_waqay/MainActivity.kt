// android/app/src/main/kotlin/com/apuwaqay/apu_waqay/MainActivity.kt
package com.apuwaqay.apu_waqay // Reemplaza si tu namespace en build.gradle es diferente

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
            result.error("PERMISSION_DENIED", "Permiso SEND_SMS denegado por el sistema", null)
            return
        }

        try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                this.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            // Identificador único para evitar colisiones entre múltiples SMS
            val uniqueId = UUID.randomUUID().toString()
            val sentAction = "SMS_SENT_$uniqueId"

            // FLAG_IMMUTABLE es obligatorio en Android 12+ (SDK 31+)
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }

            val sentIntent = PendingIntent.getBroadcast(this, 0, Intent(sentAction), flags)

            // Registro dinámico del BroadcastReceiver para capturar la respuesta real de la antena
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    try {
                        context?.unregisterReceiver(this)
                    } catch (e: Exception) {
                        // Evita crash si ya se desregistró
                    }

                    when (resultCode) {
                        Activity.RESULT_OK -> result.success(true) // 100% confirmado por operadora
                        SmsManager.RESULT_ERROR_GENERIC_FAILURE -> result.error("GENERIC_FAILURE", "Falla genérica de red/operadora", null)
                        SmsManager.RESULT_ERROR_NO_SERVICE -> result.error("NO_SERVICE", "Sin señal o servicio", null)
                        SmsManager.RESULT_ERROR_NULL_PDU -> result.error("NULL_PDU", "Error de PDU", null)
                        SmsManager.RESULT_ERROR_RADIO_OFF -> result.error("RADIO_OFF", "Modo avión activo", null)
                        else -> result.error("UNKNOWN_ERROR", "Bloqueado por OEM o error desconocido: $resultCode", null)
                    }
                }
            }

            // Android 13/14 (SDK 33+) exige especificar si el receiver es exportado
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, IntentFilter(sentAction), Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(receiver, IntentFilter(sentAction))
            }

            // Manejo estricto de Multipart.
            // Los links de Google Maps hacen que el SMS supere los 160 caracteres.
            // Si se usa sendTextMessage en lugar de sendMultipartTextMessage, falla silenciosamente en Huawei/Honor.
            val parts = smsManager.divideMessage(msg)
            if (parts.size > 1) {
                val sentIntents = ArrayList<PendingIntent>()
                for (i in parts.indices) {
                    // Solo el último fragmento confirma el envío completo
                    if (i == parts.size - 1) {
                        sentIntents.add(sentIntent)
                    } else {
                        val dummyIntent = PendingIntent.getBroadcast(this, uniqueId.hashCode() + i, Intent(sentAction + "_dummy_$i"), flags)
                        sentIntents.add(dummyIntent)
                    }
                }
                smsManager.sendMultipartTextMessage(phone, null, parts, sentIntents, null)
            } else {
                smsManager.sendTextMessage(phone, null, msg, sentIntent, null)
            }

        } catch (e: Exception) {
            result.error("EXCEPTION", e.localizedMessage, null)
        }
    }
}