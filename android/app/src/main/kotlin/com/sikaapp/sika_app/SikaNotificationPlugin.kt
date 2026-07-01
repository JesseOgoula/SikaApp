package com.sikaapp.sika_app

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsMessage
import android.util.Log
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONArray

/**
 * Plugin Flutter qui fait le pont entre le code natif Android et Flutter.
 *
 * Expose les MethodChannels :
 * - `sika/notification_listener` : Contrôle du NotificationListenerService
 * - `sika/sms` : Réception des SMS via BroadcastReceiver
 *
 * Fonctionnalités :
 * - Vérifier si le NotificationListenerService est activé
 * - Ouvrir les paramètres pour l'activer
 * - Intercepter les SMS entrants
 * - Vérifier / demander les permissions SMS
 */
class SikaNotificationPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var notifChannel: MethodChannel
    private lateinit var smsChannel: MethodChannel
    private var context: Context? = null
    private var activity: android.app.Activity? = null
    private var smsReceiver: BroadcastReceiver? = null
    private var pendingPermissionResult: Result? = null

    companion object {
        private const val SMS_PERMISSION_REQUEST_CODE = 1001
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        // Channel pour le NotificationListenerService
        notifChannel = MethodChannel(
            binding.binaryMessenger, 
            "sika/notification_listener"
        )
        notifChannel.setMethodCallHandler(this)

        // Passer la référence du channel au service natif
        SikaNotificationListenerService.flutterChannel = notifChannel

        // Channel pour les SMS
        smsChannel = MethodChannel(binding.binaryMessenger, "sika/sms")
        smsChannel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        notifChannel.setMethodCallHandler(null)
        smsChannel.setMethodCallHandler(null)
        unregisterSmsReceiver()
        SikaNotificationListenerService.flutterChannel = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // ── Notification Listener ──
            "isListenerEnabled" -> {
                result.success(isNotificationListenerEnabled())
            }
            "openListenerSettings" -> {
                openNotificationListenerSettings()
                result.success(true)
            }

            // ── SMS ──
            "hasSmsPermission" -> {
                result.success(hasSmsPermission())
            }
            "requestSmsPermission" -> {
                requestSmsPermission(result)
            }
            "startSmsListening" -> {
                registerSmsReceiver()
                result.success(true)
            }

            // ── Background transactions (détectées app fermée) ──
            "getPendingBackgroundTransactions" -> {
                result.success(getPendingBackgroundTransactions())
            }
            "clearBackgroundTransactions" -> {
                clearBackgroundTransactions()
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    // ── Notification Listener Methods ──

    private fun isNotificationListenerEnabled(): Boolean {
        val ctx = context ?: return false
        val componentName = ComponentName(ctx, SikaNotificationListenerService::class.java)
        val enabledListeners = Settings.Secure.getString(
            ctx.contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        return enabledListeners.contains(componentName.flattenToString())
    }

    private fun openNotificationListenerSettings() {
        val ctx = context ?: return
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(intent)
    }

    // ── SMS Methods ──

    private fun hasSmsPermission(): Boolean {
        val ctx = context ?: return false
        return ContextCompat.checkSelfPermission(
            ctx, Manifest.permission.RECEIVE_SMS
        ) == PackageManager.PERMISSION_GRANTED &&
        ContextCompat.checkSelfPermission(
            ctx, Manifest.permission.READ_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermission(result: Result) {
        val act = activity
        if (act == null) {
            result.success(false)
            return
        }

        if (hasSmsPermission()) {
            result.success(true)
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            act,
            arrayOf(
                Manifest.permission.RECEIVE_SMS,
                Manifest.permission.READ_SMS
            ),
            SMS_PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
            if (granted) registerSmsReceiver()
            return true
        }
        return false
    }

    private fun registerSmsReceiver() {
        if (smsReceiver != null) return
        val ctx = context ?: return

        Log.d("SIKA_SMS", "Registering SMS BroadcastReceiver...")

        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                Log.d("SIKA_SMS", "BroadcastReceiver.onReceive called! action=${intent?.action}")
                if (intent?.action != "android.provider.Telephony.SMS_RECEIVED") return

                val bundle = intent.extras ?: return
                val pdus = bundle.get("pdus") as? Array<*> ?: return
                val format = bundle.getString("format") ?: return

                for (pdu in pdus) {
                    val smsMessage = SmsMessage.createFromPdu(
                        pdu as ByteArray, format
                    )
                    val sender = smsMessage.displayOriginatingAddress ?: ""
                    val body = smsMessage.displayMessageBody ?: ""

                    Log.d("SIKA_SMS", "SMS from: '$sender', body length: ${body.length}")
                    Log.d("SIKA_SMS", "SMS body preview: ${body.take(100)}")

                    if (body.isNotBlank()) {
                        val data = mapOf(
                            "sender" to sender,
                            "body" to body,
                        )
                        try {
                            smsChannel.invokeMethod("onSmsReceived", data)
                            Log.d("SIKA_SMS", "Successfully sent SMS to Flutter channel")
                        } catch (e: Exception) {
                            Log.e("SIKA_SMS", "Failed to send SMS to Flutter: ${e.message}")
                        }
                    }
                }
            }
        }

        val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
        filter.priority = IntentFilter.SYSTEM_HIGH_PRIORITY
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.registerReceiver(smsReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            ctx.registerReceiver(smsReceiver, filter)
        }
        Log.d("SIKA_SMS", "SMS BroadcastReceiver registered successfully")
    }

    private fun unregisterSmsReceiver() {
        smsReceiver?.let {
            try {
                context?.unregisterReceiver(it)
            } catch (_: Exception) {}
        }
        smsReceiver = null
    }

    // ── ActivityAware ──

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ── Background transactions ──

    /**
     * Récupère les transactions détectées en arrière-plan (app fermée).
     * Retourne une liste de Maps prête à être consommée par Flutter.
     */
    private fun getPendingBackgroundTransactions(): List<Map<String, Any?>> {
        val ctx = context ?: return emptyList()
        val prefs = ctx.getSharedPreferences(SikaSmsReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(SikaSmsReceiver.PREFS_KEY, "[]") ?: "[]"
        return try {
            val arr = JSONArray(raw)
            val result = mutableListOf<Map<String, Any?>>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val map = mutableMapOf<String, Any?>()
                obj.keys().forEach { key -> map[key] = if (obj.isNull(key)) null else obj.get(key) }
                result.add(map)
            }
            Log.d(SikaSmsReceiver.TAG, "getPendingBackgroundTransactions: ${result.size} items")
            result
        } catch (e: Exception) {
            Log.e(SikaSmsReceiver.TAG, "Failed to read background transactions: ${e.message}")
            emptyList()
        }
    }

    /**
     * Supprime toutes les transactions en arrière-plan du SharedPreferences.
     * Appelé par Flutter après les avoir importées.
     */
    private fun clearBackgroundTransactions() {
        val ctx = context ?: return
        val prefs = ctx.getSharedPreferences(SikaSmsReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(SikaSmsReceiver.PREFS_KEY).apply()
        Log.d(SikaSmsReceiver.TAG, "Background transactions cleared")
    }
}

