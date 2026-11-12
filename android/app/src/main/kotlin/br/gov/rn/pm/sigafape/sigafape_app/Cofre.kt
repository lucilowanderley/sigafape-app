package br.gov.rn.pm.sigafape.sigafape_app

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Preferências do app e token do aparelho cifrado com chave do Android Keystore.
 * Usado pela tela (MainActivity) e pela conferência em segundo plano (ConferirNovidades).
 */
object Cofre {
    private const val ALIAS = "sigafape_token"

    fun prefs(ctx: Context): SharedPreferences = ctx.getSharedPreferences("sigafape", Context.MODE_PRIVATE)

    fun ler(ctx: Context, chave: String): String? = prefs(ctx).getString("p_$chave", null)

    fun gravar(ctx: Context, chave: String, valor: String?) {
        prefs(ctx).edit().apply { if (valor == null) remove("p_$chave") else putString("p_$chave", valor) }.apply()
    }

    fun lerSegredo(ctx: Context, chave: String): String? = prefs(ctx).getString("s_$chave", null)?.let { decifrar(it) }

    fun gravarSegredo(ctx: Context, chave: String, valor: String?) {
        prefs(ctx).edit().apply { if (valor == null) remove("s_$chave") else putString("s_$chave", cifrar(valor)) }.apply()
    }

    private fun chave(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getEntry(ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build()
        )
        return gen.generateKey()
    }

    private fun cifrar(texto: String): String {
        val c = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, chave()) }
        val dados = c.doFinal(texto.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(c.iv, Base64.NO_WRAP) + ":" + Base64.encodeToString(dados, Base64.NO_WRAP)
    }

    /** Devolve null se não der para decifrar (ex.: chave apagada após restaurar backup): o app pede login de novo. */
    private fun decifrar(guardado: String): String? = try {
        val (iv, dados) = guardado.split(":").map { Base64.decode(it, Base64.NO_WRAP) }
        val c = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.DECRYPT_MODE, chave(), GCMParameterSpec(128, iv)) }
        String(c.doFinal(dados), Charsets.UTF_8)
    } catch (e: Exception) {
        null
    }
}
