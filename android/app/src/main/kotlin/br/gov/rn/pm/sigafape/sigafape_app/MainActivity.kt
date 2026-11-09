package br.gov.rn.pm.sigafape.sigafape_app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Funções nativas usadas pelo app (canal "sigafape/nativo"), sem plugins de terceiros,
 * para o app rodar a partir do Android 6.0 (API 23):
 * preferências, token guardado com chave do Android Keystore, nome do aparelho, abertura de anexos
 * e localização (GPS) para o pedido de apoio e a abertura de ocorrência.
 */
class MainActivity : FlutterActivity() {
    private val prefs by lazy { getSharedPreferences("sigafape", Context.MODE_PRIVATE) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sigafape/nativo").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "ler" -> result.success(prefs.getString("p_" + call.argument<String>("chave"), null))
                    "gravar" -> {
                        val chave = "p_" + call.argument<String>("chave")
                        val valor = call.argument<String>("valor")
                        prefs.edit().apply { if (valor == null) remove(chave) else putString(chave, valor) }.apply()
                        result.success(null)
                    }
                    "lerSegredo" -> result.success(prefs.getString("s_" + call.argument<String>("chave"), null)?.let { decifrar(it) })
                    "gravarSegredo" -> {
                        val chave = "s_" + call.argument<String>("chave")
                        val valor = call.argument<String>("valor")
                        prefs.edit().apply { if (valor == null) remove(chave) else putString(chave, cifrar(valor)) }.apply()
                        result.success(null)
                    }
                    "aparelho" -> result.success("${Build.MANUFACTURER.replaceFirstChar { it.uppercase() }} ${Build.MODEL} · Android ${Build.VERSION.RELEASE}")
                    "abrirArquivo" -> result.success(abrirArquivo(call.argument<String>("nome")!!, call.argument<ByteArray>("bytes")!!, call.argument<String>("tipo")))
                    "localizacao" -> localizacao(result)
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("nativo", e.message, null)
            }
        }
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

    private fun abrirArquivo(nome: String, bytes: ByteArray, tipo: String?): Boolean {
        val pasta = File(cacheDir, "anexos").apply { mkdirs() }
        val arquivo = File(pasta, nome.replace(Regex("[\\\\/:*?\"<>|]"), "_"))
        arquivo.writeBytes(bytes)
        val uri = FileProvider.getUriForFile(this, "$packageName.arquivos", arquivo)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, tipo ?: contentResolver.getType(uri) ?: "*/*")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            startActivity(Intent.createChooser(intent, nome).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: Exception) {
            false
        }
    }

    // ---------- Localização ----------

    private var pedidoLocal: MethodChannel.Result? = null

    private fun temPermissao(): Boolean =
        checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    /** Pede a permissão (se preciso) e devolve {latitude, longitude, precisao} ou um erro: sem_permissao, gps_desligado, sem_sinal. */
    private fun localizacao(result: MethodChannel.Result) {
        if (temPermissao()) return buscarLocal(result)
        pedidoLocal?.error("cancelado", "Outro pedido de localização começou.", null)
        pedidoLocal = result
        requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), PEDIDO_LOCAL)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PEDIDO_LOCAL) return
        val r = pedidoLocal ?: return
        pedidoLocal = null
        if (temPermissao()) buscarLocal(r) else r.error("sem_permissao", "Permissão de localização negada.", null)
    }

    @Suppress("DEPRECATION", "MissingPermission")
    private fun buscarLocal(result: MethodChannel.Result) {
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val provedores = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER).filter {
            try { lm.isProviderEnabled(it) } catch (e: Exception) { false }
        }
        if (provedores.isEmpty()) return result.error("gps_desligado", "Localização do celular desligada.", null)

        val handler = Handler(Looper.getMainLooper())
        var respondido = false
        var melhor: Location? = provedores.mapNotNull { try { lm.getLastKnownLocation(it) } catch (e: Exception) { null } }
            .filter { System.currentTimeMillis() - it.time < 2 * 60 * 1000 }
            .minByOrNull { it.accuracy }
        lateinit var ouvinte: LocationListener
        fun responder() {
            if (respondido) return
            respondido = true
            try { lm.removeUpdates(ouvinte) } catch (e: Exception) {}
            val l = melhor
            if (l == null) result.error("sem_sinal", "Não foi possível obter a localização.", null)
            else result.success(mapOf("latitude" to l.latitude, "longitude" to l.longitude, "precisao" to l.accuracy.toDouble()))
        }
        ouvinte = object : LocationListener {
            override fun onLocationChanged(l: Location) {
                if (melhor == null || l.accuracy < melhor!!.accuracy) melhor = l
                // Precisão boa (até 30 m): responde já; senão espera melhorar até o limite de tempo
                if (l.accuracy <= 30f) handler.post { responder() }
            }
            override fun onStatusChanged(p: String?, s: Int, e: Bundle?) {}
            override fun onProviderEnabled(p: String) {}
            override fun onProviderDisabled(p: String) {}
        }
        for (p in provedores) {
            try { lm.requestLocationUpdates(p, 1000L, 0f, ouvinte, Looper.getMainLooper()) } catch (e: Exception) {}
        }
        handler.postDelayed({ responder() }, 15000)
    }

    companion object {
        private const val ALIAS = "sigafape_token"
        private const val PEDIDO_LOCAL = 4190
    }
}
