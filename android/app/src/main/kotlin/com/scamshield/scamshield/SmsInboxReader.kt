package com.scamshield.scamshield

import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.provider.Telephony
import android.util.Log

object SmsInboxReader {
    private const val TAG = "SmsInboxReader"

    fun readInboxMessages(context: Context, limit: Int = 100): List<Map<String, Any>> {
        val messageList = mutableListOf<Map<String, Any>>()
        val contentResolver = context.contentResolver
        val uri: Uri = Telephony.Sms.CONTENT_URI

        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE,
            Telephony.Sms.READ
        )

        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(
                uri,
                projection,
                null,
                null,
                "${Telephony.Sms.DATE} DESC LIMIT $limit"
            )

            cursor?.let {
                val idIdx = it.getColumnIndex(Telephony.Sms._ID)
                val addressIdx = it.getColumnIndex(Telephony.Sms.ADDRESS)
                val bodyIdx = it.getColumnIndex(Telephony.Sms.BODY)
                val dateIdx = it.getColumnIndex(Telephony.Sms.DATE)
                val typeIdx = it.getColumnIndex(Telephony.Sms.TYPE)
                val readIdx = it.getColumnIndex(Telephony.Sms.READ)

                while (it.moveToNext()) {
                    val id = if (idIdx >= 0) it.getString(idIdx) ?: "" else ""
                    val address = if (addressIdx >= 0) it.getString(addressIdx) ?: "Unknown" else "Unknown"
                    val body = if (bodyIdx >= 0) it.getString(bodyIdx) ?: "" else ""
                    val date = if (dateIdx >= 0) it.getLong(dateIdx) else System.currentTimeMillis()
                    val type = if (typeIdx >= 0) it.getInt(typeIdx) else Telephony.Sms.MESSAGE_TYPE_INBOX
                    val isRead = if (readIdx >= 0) it.getInt(readIdx) == 1 else true

                    val isOutgoing = type == Telephony.Sms.MESSAGE_TYPE_SENT || type == Telephony.Sms.MESSAGE_TYPE_OUTBOX

                    val msgMap = mapOf(
                        "id" to id,
                        "address" to address,
                        "body" to body,
                        "date" to date,
                        "isOutgoing" to isOutgoing,
                        "isRead" to isRead
                    )
                    messageList.add(msgMap)
                }
            }
            Log.i(TAG, "Successfully read ${messageList.size} messages from SMS provider")
        } catch (e: Exception) {
            Log.e(TAG, "Error querying SMS content provider: ${e.message}", e)
        } finally {
            cursor?.close()
        }

        return messageList
    }
}
