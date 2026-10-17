package com.scamshield.scamshield

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ScamShieldSmsReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent == null || context == null) return

        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            try {
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                if (messages.isNullOrEmpty()) return

                val sender = messages[0].displayOriginatingAddress ?: "Unknown"
                val bodyBuilder = StringBuilder()
                var timestamp = System.currentTimeMillis()

                for (msg in messages) {
                    bodyBuilder.append(msg.displayMessageBody ?: "")
                    timestamp = msg.timestampMillis
                }

                val fullBody = bodyBuilder.toString()
                Log.i(TAG, "Incoming SMS from $sender: $fullBody")

                val payload = mapOf(
                    "source" to "sms",
                    "packageName" to "telephony",
                    "sender" to sender,
                    "body" to fullBody,
                    "timestamp" to timestamp,
                    "notificationKey" to ""
                )

                MainActivity.sendIncomingMessageEvent(payload)
            } catch (e: Exception) {
                Log.e(TAG, "Error processing incoming SMS: ${e.message}", e)
            }
        }
    }
}
