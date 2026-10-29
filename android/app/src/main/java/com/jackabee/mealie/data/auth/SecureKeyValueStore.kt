package com.jackabee.mealie.data.auth

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Only auth secrets are redirected; ordinary settings remain in preferences. */
class SecureKeyValueStore(
    private val preferences: KeyValueStore,
    private val secrets: SecretStore,
) : KeyValueStore by preferences {
    private val protectedKeys = setOf("mealie_access_token", "mealie_password")

    init { protectedKeys.forEach { getString(it) } }

    override fun getString(key: String): String? {
        if (key !in protectedKeys) return preferences.getString(key)
        if (preferences.getBoolean("revoked_$key")) {
            // Logout cannot resurrect a token if the keystore was unavailable.
            runCatching { secrets.write(key, null) }
            return null
        }
        return try {
            val current = secrets.read(key)
            if (current != null) {
                preferences.remove(key)
                current
            } else {
                preferences.getString(key)?.also { legacy ->
                    secrets.write(key, legacy) // commit before removing plaintext
                    preferences.remove(key)
                }
            }
        } catch (_: Exception) {
            // Do not use plaintext if encryption/decryption fails. Keep it for retry.
            null
        }
    }

    override fun putString(key: String, value: String?) {
        if (key !in protectedKeys) return preferences.putString(key, value)
        if (value == null) {
            preferences.putBooleanDurably("revoked_$key", true)
            preferences.remove(key)
            runCatching { secrets.write(key, null) }
            return
        }
        secrets.write(key, value)
        preferences.remove(key)
        preferences.remove("revoked_$key")
    }

    override fun remove(key: String) {
        if (key in protectedKeys) putString(key, null) else preferences.remove(key)
    }

    override fun contains(key: String): Boolean =
        if (key in protectedKeys) getString(key) != null else preferences.contains(key)
}

interface SecretStore {
    fun read(key: String): String?
    fun write(key: String, value: String?)
}

/** AES-GCM key never leaves AndroidKeyStore; ciphertext is excluded from backups. */
class AndroidKeystoreSecretStore(context: Context) : SecretStore {
    private val prefs = context.getSharedPreferences("mealie_secrets", Context.MODE_PRIVATE)
    private val keyAlias = "com.jackabee.mealie.credentials.v1"

    @Synchronized
    private fun encryptionKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(keyAlias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(keyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build())
        }.generateKey()
    }

    override fun read(key: String): String? {
        val encoded = prefs.getString(key, null) ?: return null
        val pieces = encoded.split(":", limit = 2)
        require(pieces.size == 2) { "Invalid credential envelope" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, encryptionKey(),
            GCMParameterSpec(128, Base64.decode(pieces[0], Base64.NO_WRAP)))
        cipher.updateAAD(key.toByteArray(Charsets.UTF_8))
        return String(cipher.doFinal(Base64.decode(pieces[1], Base64.NO_WRAP)), Charsets.UTF_8)
    }

    override fun write(key: String, value: String?) {
        val edit = prefs.edit()
        if (value == null) edit.remove(key)
        else {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, encryptionKey())
            cipher.updateAAD(key.toByteArray(Charsets.UTF_8))
            val ciphertext = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
            edit.putString(key, Base64.encodeToString(cipher.iv, Base64.NO_WRAP) + ":" +
                Base64.encodeToString(ciphertext, Base64.NO_WRAP))
        }
        check(edit.commit()) { "Unable to persist encrypted credentials" }
    }
}
