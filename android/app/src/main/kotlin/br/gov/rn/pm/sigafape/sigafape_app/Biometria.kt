package br.gov.rn.pm.sigafape.sigafape_app

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec

/**
 * Digital/rosto (opção A, 2026-11-14). Par de chaves EC P-256 no chip de segurança (AndroidKeyStore) que só
 * assina depois da digital/rosto "forte". A chave pública vai para o servidor; a senha nunca fica no aparelho.
 * Usa o BiometricPrompt do próprio Android (9.0+), sem biblioteca extra.
 */
object Biometria {
    private const val ALIAS = "sigafape_biometria"

    /** "ok", "sem_cadastro" (sem digital cadastrada), "sem_sensor" ou "antigo" (Android antes do 9). */
    @Suppress("DEPRECATION")
    fun situacao(ctx: Context): String {
        if (Build.VERSION.SDK_INT < 28) return "antigo"
        if (Build.VERSION.SDK_INT >= 30) {
            val bm = ctx.getSystemService(BiometricManager::class.java) ?: return "sem_sensor"
            return when (bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)) {
                BiometricManager.BIOMETRIC_SUCCESS -> "ok"
                BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "sem_cadastro"
                else -> "sem_sensor"
            }
        }
        if (Build.VERSION.SDK_INT == 29) {
            val bm = ctx.getSystemService(BiometricManager::class.java) ?: return "sem_sensor"
            return when (bm.canAuthenticate()) {
                BiometricManager.BIOMETRIC_SUCCESS -> "ok"
                BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "sem_cadastro"
                else -> "sem_sensor"
            }
        }
        val fm = ctx.getSystemService(android.hardware.fingerprint.FingerprintManager::class.java)
        if (fm == null || !ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT) || !fm.isHardwareDetected) return "sem_sensor"
        return if (fm.hasEnrolledFingerprints()) "ok" else "sem_cadastro"
    }

    /** Cria (ou recria) a chave e devolve a pública em base64 (X.509). */
    fun criarChave(): String {
        if (Build.VERSION.SDK_INT < 28) throw IllegalStateException("Digital disponível a partir do Android 9.")
        apagar()
        val b = KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_SIGN)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
        if (Build.VERSION.SDK_INT >= 30) b.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
        val kpg = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
        kpg.initialize(b.build())
        return Base64.encodeToString(kpg.generateKeyPair().public.encoded, Base64.NO_WRAP)
    }

    fun apagar() {
        try {
            val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            if (ks.containsAlias(ALIAS)) ks.deleteEntry(ALIAS)
        } catch (e: Exception) {}
    }

    /**
     * Mostra a janela do Android (digital/rosto) e assina [texto]. [pronto] recebe (assinatura em base64, null)
     * ou (null, código): "cancelado", "sem_chave", "invalidada" (digital nova cadastrada no celular) ou a mensagem do Android.
     */
    fun assinar(activity: Activity, texto: String, titulo: String, subtitulo: String, pronto: (String?, String?) -> Unit) {
        if (Build.VERSION.SDK_INT < 28) return pronto(null, "antigo")
        var respondeu = false
        val responder = { a: String?, e: String? -> if (!respondeu) { respondeu = true; pronto(a, e) } }
        val assinatura = try {
            val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            val chave = ks.getKey(ALIAS, null) as? PrivateKey ?: return responder(null, "sem_chave")
            Signature.getInstance("SHA256withECDSA").apply { initSign(chave) }
        } catch (e: KeyPermanentlyInvalidatedException) {
            return responder(null, "invalidada")
        } catch (e: Exception) {
            return responder(null, e.message ?: "erro")
        }
        val executor = activity.mainExecutor
        val janela = BiometricPrompt.Builder(activity)
            .setTitle(titulo)
            .setSubtitle(subtitulo)
            .setNegativeButton("Usar senha", executor) { _, _ -> responder(null, "cancelado") }
        if (Build.VERSION.SDK_INT >= 29) janela.setConfirmationRequired(false)
        janela.build().authenticate(BiometricPrompt.CryptoObject(assinatura), CancellationSignal(), executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    try {
                        val s = result.cryptoObject.signature
                        s.update(texto.toByteArray(Charsets.UTF_8))
                        responder(Base64.encodeToString(s.sign(), Base64.NO_WRAP), null)
                    } catch (e: Exception) {
                        responder(null, e.message ?: "erro")
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    val cancelou = errorCode == BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED ||
                        errorCode == BiometricPrompt.BIOMETRIC_ERROR_CANCELED
                    responder(null, if (cancelou) "cancelado" else errString.toString())
                }
            })
    }
}
