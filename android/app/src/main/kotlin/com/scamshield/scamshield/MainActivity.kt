package com.scamshield.scamshield

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.provider.Telephony
import android.telephony.SmsManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "ScamShieldMainActivity"
        private const val METHOD_CHANNEL = "com.scamshield/device_messages"
        private const val EVENT_CHANNEL = "com.scamshield/incoming_messages"
        private const val SMS_PERMISSION_REQUEST_CODE = 2001

        private var eventSink: EventChannel.EventSink? = null
        private val pendingEvents = mutableListOf<Map<String, Any>>()

        fun sendIncomingMessageEvent(payload: Map<String, Any>) {
            val sink = eventSink
            if (sink != null) {
                sink.success(payload)
            } else {
                synchronized(pendingEvents) {
                    if (pendingEvents.size < 50) {
                        pendingEvents.add(payload)
                    }
                }
            }
        }
    }

    private var permissionResultCallback: ((Boolean) -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel for Realtime Incoming Messages (SMS + Notification listener)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    synchronized(pendingEvents) {
                        for (pending in pendingEvents) {
                            events?.success(pending)
                        }
                        pendingEvents.clear()
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        // MethodChannel for SMS queries, dispatch, permissions, and dismissing spam notifications
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasSmsPermission" -> {
                        val hasRead = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_SMS
                        ) == PackageManager.PERMISSION_GRANTED
                        val hasReceive = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.RECEIVE_SMS
                        ) == PackageManager.PERMISSION_GRANTED
                        val hasSend = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.SEND_SMS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(hasRead && hasReceive && hasSend)
                    }

                    "requestSmsPermission" -> {
                        val permissionsToRequest = mutableListOf<String>()
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
                            permissionsToRequest.add(Manifest.permission.READ_SMS)
                        }
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) != PackageManager.PERMISSION_GRANTED) {
                            permissionsToRequest.add(Manifest.permission.RECEIVE_SMS)
                        }
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                            permissionsToRequest.add(Manifest.permission.SEND_SMS)
                        }

                        if (permissionsToRequest.isEmpty()) {
                            result.success(true)
                        } else {
                            permissionResultCallback = { granted ->
                                result.success(granted)
                            }
                            ActivityCompat.requestPermissions(
                                this,
                                permissionsToRequest.toTypedArray(),
                                SMS_PERMISSION_REQUEST_CODE
                            )
                        }
                    }

                    "readSmsInbox" -> {
                        val limit = call.argument<Int>("limit") ?: 100
                        val messages = SmsInboxReader.readInboxMessages(this, limit)
                        result.success(messages)
                    }

                    "sendSms" -> {
                        val recipient = call.argument<String>("recipient") ?: ""
                        val message = call.argument<String>("message") ?: ""

                        if (recipient.isBlank() || message.isBlank()) {
                            result.error("INVALID_ARGS", "Recipient and message cannot be empty", null)
                            return@setMethodCallHandler
                        }

                        val hasSend = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.SEND_SMS
                        ) == PackageManager.PERMISSION_GRANTED

                        if (!hasSend) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.SEND_SMS),
                                SMS_PERMISSION_REQUEST_CODE
                            )
                            result.error("PERMISSION_DENIED", "SEND_SMS permission not granted", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                getSystemService(SmsManager::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                SmsManager.getDefault()
                            }

                            val parts = smsManager.divideMessage(message)
                            if (parts.size > 1) {
                                smsManager.sendMultipartTextMessage(recipient, null, parts, null, null)
                            } else {
                                smsManager.sendTextMessage(recipient, null, message, null, null)
                            }

                            // Write sent message to Telephony.Sms.Sent content provider
                            try {
                                val values = ContentValues().apply {
                                    put(Telephony.Sms.ADDRESS, recipient)
                                    put(Telephony.Sms.BODY, message)
                                    put(Telephony.Sms.DATE, System.currentTimeMillis())
                                    put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
                                }
                                contentResolver.insert(Telephony.Sms.Sent.CONTENT_URI, values)
                            } catch (e: Exception) {
                                Log.w(TAG, "Note: writing to Sent SMS provider: ${e.message}")
                            }

                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error sending SMS: ${e.message}", e)
                            result.error("SEND_FAILED", e.message, null)
                        }
                    }

                    "hasNotificationAccess" -> {
                        val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(this)
                        val hasAccess = enabledPackages.contains(packageName)
                        result.success(hasAccess)
                    }

                    "requestNotificationAccess" -> {
                        try {
                            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            } else {
                                Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                            }
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INTENT_ERROR", e.message, null)
                        }
                    }

                    "dismissNotification" -> {
                        val key = call.argument<String>("notificationKey")
                        if (key != null && key.isNotEmpty()) {
                            val listener = ScamShieldNotificationListener.instance
                            if (listener != null) {
                                val dismissed = listener.dismissNotificationByKey(key)
                                result.success(dismissed)
                            } else {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            permissionResultCallback?.invoke(allGranted)
            permissionResultCallback = null
        }
    }
}
