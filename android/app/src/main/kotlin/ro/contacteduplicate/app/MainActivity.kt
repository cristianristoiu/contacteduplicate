package ro.contacteduplicate.app

import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CONTACTS_CHANNEL = "ro.contacteduplicate.app/contacts"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CONTACTS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getContactCapabilities" -> {
                    val contactId = call.argument<String>("contactId")?.trim().orEmpty()
                    if (contactId.isEmpty() || contactId.toLongOrNull() == null) {
                        result.error("invalid_contact_id", "Identificatorul contactului este invalid.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(readContactCapabilities(contactId))
                    } catch (_: SecurityException) {
                        result.error("contacts_permission_denied", "Accesul la contacte nu este disponibil.", null)
                    } catch (_: Exception) {
                        result.error("contacts_capabilities_failed", "Capabilitatile contactului nu au putut fi citite.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readContactCapabilities(contactId: String): Map<String, Any?> {
        val projection = arrayOf(
            ContactsContract.RawContacts._ID,
            ContactsContract.RawContacts.ACCOUNT_NAME,
            ContactsContract.RawContacts.ACCOUNT_TYPE,
            ContactsContract.RawContacts.DATA_SET,
            ContactsContract.RawContacts.RAW_CONTACT_IS_READ_ONLY,
        )
        val selection = "${ContactsContract.RawContacts.CONTACT_ID} = ? AND ${ContactsContract.RawContacts.DELETED} = 0"
        val rawContactIds = mutableListOf<String>()
        val accountNames = linkedSetOf<String>()
        val accountTypes = linkedSetOf<String>()
        val dataSets = linkedSetOf<String>()
        var found = false
        var hasWritableRawContact = false
        var hasReadOnlyRawContact = false

        contentResolver.query(
            ContactsContract.RawContacts.CONTENT_URI,
            projection,
            selection,
            arrayOf(contactId),
            null,
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(ContactsContract.RawContacts._ID)
            val accountNameIndex = cursor.getColumnIndexOrThrow(ContactsContract.RawContacts.ACCOUNT_NAME)
            val accountTypeIndex = cursor.getColumnIndexOrThrow(ContactsContract.RawContacts.ACCOUNT_TYPE)
            val dataSetIndex = cursor.getColumnIndexOrThrow(ContactsContract.RawContacts.DATA_SET)
            val readOnlyIndex = cursor.getColumnIndexOrThrow(ContactsContract.RawContacts.RAW_CONTACT_IS_READ_ONLY)
            while (cursor.moveToNext()) {
                found = true
                rawContactIds.add(cursor.getLong(idIndex).toString())
                cursor.getString(accountNameIndex)?.trim()?.takeIf { it.isNotEmpty() }?.let(accountNames::add)
                cursor.getString(accountTypeIndex)?.trim()?.takeIf { it.isNotEmpty() }?.let(accountTypes::add)
                cursor.getString(dataSetIndex)?.trim()?.takeIf { it.isNotEmpty() }?.let(dataSets::add)
                val readOnly = cursor.getInt(readOnlyIndex) == 1
                if (readOnly) {
                    hasReadOnlyRawContact = true
                } else {
                    hasWritableRawContact = true
                }
            }
        }

        val capability = when {
            !found -> "unknown"
            hasWritableRawContact -> "writable"
            hasReadOnlyRawContact -> "readOnly"
            else -> "unknown"
        }
        return mapOf(
            "found" to found,
            "update" to capability,
            "delete" to capability,
            "hasMixedCapabilities" to (hasWritableRawContact && hasReadOnlyRawContact),
            "rawContactIds" to rawContactIds,
            "accountNames" to accountNames.toList(),
            "accountTypes" to accountTypes.toList(),
            "dataSets" to dataSets.toList(),
        )
    }
}
