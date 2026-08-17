package ro.contacteduplicate.app

import android.Manifest
import android.content.pm.PackageManager
import android.provider.ContactsContract
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private companion object {
        const val CONTACTS_CHANNEL = "ro.contacteduplicate.app/contacts"
        const val MAX_BATCH_CONTACTS = 100
        const val MAX_OPERATION_TOKEN_LENGTH = 96
        const val MAX_CONTACT_ID_LENGTH = 20
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CONTACTS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getContactCapabilities" -> handleGetContactCapabilities(call, result)
                "preflightContacts" -> handlePreflightContacts(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleGetContactCapabilities(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (!hasReadPermission()) {
            result.error("contacts_read_permission_denied", "Read permission required", null)
            return
        }
        val contactId = parseContactId(call.argument<Any?>("contactId"))
        if (contactId == null) {
            result.error("contact_id_invalid", "Invalid contact id", null)
            return
        }
        try {
            result.success(readCapabilities(contactId).toFlutterMap())
        } catch (_: SecurityException) {
            result.error("contacts_read_permission_denied", "Read permission required", null)
        } catch (_: Exception) {
            result.error("contact_capabilities_failed", "Contact metadata unavailable", null)
        }
    }

    private fun handlePreflightContacts(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (!hasReadPermission()) {
            result.error("contacts_read_permission_denied", "Read permission required", null)
            return
        }
        val requiresWrite = call.argument<Boolean>("requiresWrite") ?: false
        if (requiresWrite && !hasWritePermission()) {
            result.error("contacts_write_permission_denied", "Write permission required", null)
            return
        }
        val operationToken = call.argument<String>("operationToken")?.trim().orEmpty()
        if (!isValidOperationToken(operationToken)) {
            result.error("operation_token_invalid", "Invalid operation token", null)
            return
        }
        val rawIds = call.argument<List<Any?>>("contactIds")
        if (rawIds == null || rawIds.isEmpty() || rawIds.size > MAX_BATCH_CONTACTS) {
            result.error("contact_batch_invalid", "Invalid contact batch", null)
            return
        }
        val parsed = ArrayList<Long>(rawIds.size)
        val seen = HashSet<Long>()
        for (rawId in rawIds) {
            val id = parseContactId(rawId)
            if (id == null || !seen.add(id)) {
                result.error("contact_batch_invalid", "Invalid contact batch", null)
                return
            }
            parsed.add(id)
        }
        try {
            val records = parsed.map { readCapabilities(it) }
            result.success(
                mapOf(
                    "operationToken" to operationToken,
                    "count" to records.size,
                    "contacts" to records.map { it.toPreflightMap() },
                    "batchFingerprint" to batchFingerprint(records),
                ),
            )
        } catch (_: SecurityException) {
            result.error("contacts_read_permission_denied", "Read permission required", null)
        } catch (_: Exception) {
            result.error("contact_preflight_failed", "Contact preflight unavailable", null)
        }
    }

    private fun readCapabilities(contactId: Long): ContactCapabilityRecord {
        if (contactId >= ContactsContract.Profile.MIN_ID) {
            return ContactCapabilityRecord(
                contactId = contactId,
                found = true,
                isProfile = true,
                rawContactCount = 0,
                update = "readOnly",
                delete = "readOnly",
                hasMixedCapabilities = false,
                metadataFingerprint = fingerprint("profile:$contactId"),
            )
        }

        val projection = arrayOf(
            ContactsContract.RawContacts._ID,
            ContactsContract.RawContacts.RAW_CONTACT_IS_READ_ONLY,
        )
        val selection =
            "${ContactsContract.RawContacts.CONTACT_ID}=? AND " +
                "${ContactsContract.RawContacts.DELETED}=0"
        val rows = mutableListOf<Pair<Long, Boolean>>()
        contentResolver.query(
            ContactsContract.RawContacts.CONTENT_URI,
            projection,
            selection,
            arrayOf(contactId.toString()),
            "${ContactsContract.RawContacts._ID} ASC",
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(ContactsContract.RawContacts._ID)
            val readOnlyIndex =
                cursor.getColumnIndexOrThrow(ContactsContract.RawContacts.RAW_CONTACT_IS_READ_ONLY)
            while (cursor.moveToNext()) {
                rows.add(cursor.getLong(idIndex) to (cursor.getInt(readOnlyIndex) != 0))
                if (rows.size > MAX_BATCH_CONTACTS) break
            }
        }

        if (rows.isEmpty()) {
            return ContactCapabilityRecord(
                contactId = contactId,
                found = false,
                isProfile = false,
                rawContactCount = 0,
                update = "unknown",
                delete = "unknown",
                hasMixedCapabilities = false,
                metadataFingerprint = fingerprint("missing:$contactId"),
            )
        }

        val hasWritable = rows.any { !it.second }
        val hasReadOnly = rows.any { it.second }
        val mixed = hasWritable && hasReadOnly
        val capability = when {
            mixed -> "unknown"
            hasWritable -> "writable"
            hasReadOnly -> "readOnly"
            else -> "unknown"
        }
        val fingerprintInput = buildString {
            append(contactId)
            append('|')
            rows.forEach { (rawId, readOnly) ->
                append(rawId)
                append(':')
                append(if (readOnly) 'R' else 'W')
                append('|')
            }
        }
        return ContactCapabilityRecord(
            contactId = contactId,
            found = true,
            isProfile = false,
            rawContactCount = rows.size,
            update = capability,
            delete = capability,
            hasMixedCapabilities = mixed,
            metadataFingerprint = fingerprint(fingerprintInput),
        )
    }

    private fun parseContactId(rawValue: Any?): Long? {
        val text = when (rawValue) {
            is String -> rawValue.trim()
            is Int -> rawValue.toString()
            is Long -> rawValue.toString()
            else -> return null
        }
        if (text.isEmpty() || text.length > MAX_CONTACT_ID_LENGTH || !text.all(Char::isDigit)) {
            return null
        }
        val id = text.toLongOrNull() ?: return null
        return id.takeIf { it > 0 }
    }

    private fun isValidOperationToken(value: String): Boolean {
        if (value.length !in 8..MAX_OPERATION_TOKEN_LENGTH) return false
        return value.matches(Regex("^[a-z][a-z0-9_-]+$"))
    }

    private fun hasReadPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    private fun hasWritePermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    private fun batchFingerprint(records: List<ContactCapabilityRecord>): String {
        val input = records.joinToString("|") {
            "${it.contactId}:${it.metadataFingerprint}:${it.update}:${it.delete}"
        }
        return fingerprint(input)
    }

    private fun fingerprint(value: String): String {
        val bytes = MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }

    private data class ContactCapabilityRecord(
        val contactId: Long,
        val found: Boolean,
        val isProfile: Boolean,
        val rawContactCount: Int,
        val update: String,
        val delete: String,
        val hasMixedCapabilities: Boolean,
        val metadataFingerprint: String,
    ) {
        fun toFlutterMap(): Map<String, Any> = mapOf(
            "found" to found,
            "isProfile" to isProfile,
            "rawContactCount" to rawContactCount,
            "update" to update,
            "delete" to delete,
            "hasMixedCapabilities" to hasMixedCapabilities,
            "metadataFingerprint" to metadataFingerprint,
        )

        fun toPreflightMap(): Map<String, Any> = toFlutterMap()
    }
}
