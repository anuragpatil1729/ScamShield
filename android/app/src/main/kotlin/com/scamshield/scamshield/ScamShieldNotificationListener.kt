package com.scamshield.scamshield

import android.app.Notification
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class ScamShieldNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "ScamShieldNotifListener"
        var instance: ScamShieldNotificationListener? = null

        private val MESSAGING_PACKAGES = setOf(
            "com.google.android.apps.messaging",
            "com.android.mms",
            "com.samsung.android.messaging",
            "com.whatsapp",
            "com.whatsapp.w4b",
            "org.telegram.messenger",
            "com.facebook.orca",
            "org.thoughtcrime.securesms"
        )
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        Log.i(TAG, "ScamShield NotificationListener connected successfully")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        if (instance == this) {
            instance = null
        }
        Log.i(TAG, "ScamShield NotificationListener disconnected")
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) {
            instance = null
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val pkgName = sbn.packageName ?: return

        // Skip our own notifications
        if (pkgName == packageName) return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: Bundle()

        // Check if message category or messaging app
        val isMessageCategory = notification.category == Notification.CATEGORY_MESSAGE
        val isMessagingApp = MESSAGING_PACKAGES.contains(pkgName)

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()

        if (title.isNullOrBlank() && text.isNullOrBlank()) return

        // If not explicit messaging app and not message category, check if looks like a message
        if (!isMessagingApp && !isMessageCategory) {
            // Check if extras have conversation title or person
            val hasConversation = extras.containsKey(Notification.EXTRA_CONVERSATION_TITLE) ||
                    extras.containsKey(Notification.EXTRA_MESSAGING_PERSON)
            if (!hasConversation) return
        }

        val sender = title?.trim() ?: "Unknown"
        val body = text?.trim() ?: ""

        val payload = mapOf(
            "source" to "notification",
            "packageName" to pkgName,
            "sender" to sender,
            "body" to body,
            "timestamp" to sbn.postTime,
            "notificationKey" to sbn.key
        )

        Log.d(TAG, "Captured notification from $pkgName ($sender): $body")
        MainActivity.sendIncomingMessageEvent(payload)
    }

    fun dismissNotificationByKey(key: String): Boolean {
        return try {
            cancelNotification(key)
            Log.i(TAG, "Dismissed spam notification key: $key")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to dismiss notification $key: ${e.message}")
            false
        }
    }
}
