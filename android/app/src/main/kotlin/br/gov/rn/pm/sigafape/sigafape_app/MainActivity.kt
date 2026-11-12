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
import android.net.Uri
import android.provider.MediaStore
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Funções nativas usadas pelo app (canal "sigafape/nativo"), sem plugins de terceiros,
 * para o app rodar a partir do Android 6.0 (API 23):
 * preferências, token guardado com chave do Android Keystore (Cofre), nome do aparelho, abertura de anexos,
 * localização (GPS) para o pedido de apoio e a abertura de ocorrência, e avisos na barra do Android.
 */
class MainActivity : FlutterActivity() {
    /** Tela pedida ao tocar num aviso da barra do Android (ex.: "alertas"); o app lê uma vez. */
    private var abrirPedido: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        abrirPedido = intent?.getStringExtra(Avisos.EXTRA_ABRIR)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra(Avisos.EXTRA_ABRIR)?.let { abrirPedido = it }
    }

    /** Leitor de QR do Google Play Services (a tela da câmera é do Google; o app não pede permissão de câmera). */
    private fun lerQr(result: MethodChannel.Result) {
        val opcoes = GmsBarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_QR_CODE).build()
        try {
            GmsBarcodeScanning.getClient(this, opcoes).startScan()
                .addOnSuccessListener { result.success(it.rawValue) }
                .addOnCanceledListener { result.success(null) }
                .addOnFailureListener { result.error("sem_leitor", it.message, null) }
        } catch (e: Exception) {
            result.error("sem_leitor", e.message, null)
        }
    }

    // ---------- Fotos da ocorrência (câmera ou galeria, sem plugins) ----------

    private var pedidoFoto: MethodChannel.Result? = null
    private var arquivoFoto: File? = null
    private var maximoFotos = 6

    private fun tirarFoto(result: MethodChannel.Result) {
        pedidoFoto?.success(null)
        val pasta = File(cacheDir, "fotos").apply { mkdirs() }
        val arquivo = File(pasta, "foto-${System.currentTimeMillis()}.jpg")
        val uri = FileProvider.getUriForFile(this, "$packageName.arquivos", arquivo)
        val i = Intent(MediaStore.ACTION_IMAGE_CAPTURE).putExtra(MediaStore.EXTRA_OUTPUT, uri)
            .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        try {
            pedidoFoto = result
            arquivoFoto = arquivo
            @Suppress("DEPRECATION")
            startActivityForResult(i, PEDIDO_CAMERA)
        } catch (e: Exception) {
            pedidoFoto = null
            result.error("sem_camera", e.message, null)
        }
    }

    private fun escolherFotos(result: MethodChannel.Result, maximo: Int) {
        pedidoFoto?.success(null)
        maximoFotos = maximo.coerceIn(1, 6)
        val i = Intent(Intent.ACTION_GET_CONTENT).setType("image/*").addCategory(Intent.CATEGORY_OPENABLE)
            .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, maximo > 1)
        try {
            pedidoFoto = result
            @Suppress("DEPRECATION")
            startActivityForResult(Intent.createChooser(i, "Escolher fotos"), PEDIDO_GALERIA)
        } catch (e: Exception) {
            pedidoFoto = null
            result.error("sem_galeria", e.message, null)
        }
    }

    @Deprecated("Usado sem AndroidX Activity Result para manter o app sem dependências extras")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PEDIDO_CAMERA && requestCode != PEDIDO_GALERIA) return
        val r = pedidoFoto ?: return
        pedidoFoto = null
        if (resultCode != RESULT_OK) return r.success(null)
        Thread {
            val fotos = mutableListOf<ByteArray>()
            if (requestCode == PEDIDO_CAMERA) {
                arquivoFoto?.let { a -> Fotos.reduzir(this, Uri.fromFile(a))?.let { fotos.add(it) }; a.delete() }
            } else {
                val uris = mutableListOf<Uri>()
                data?.clipData?.let { cd -> for (k in 0 until cd.itemCount) uris.add(cd.getItemAt(k).uri) }
                if (uris.isEmpty()) data?.data?.let { uris.add(it) }
                for (u in uris.take(maximoFotos)) Fotos.reduzir(this, u)?.let { fotos.add(it) }
            }
            runOnUiThread { r.success(fotos) }
        }.start()
    }

    private var pedidoServico: MethodChannel.Result? = null

    /**
     * Liga o envio da posição em segundo plano: pede a permissão de localização (se faltar) e, uma vez só,
     * a opção "Permitir o tempo todo" (Android 10+), para o envio voltar sozinho depois de reiniciar o celular.
     */
    private fun ligarLocalizacao(result: MethodChannel.Result) {
        if (temPermissao()) {
            LocalizacaoServico.ligar(this)
            pedirTempoTodo()
            return result.success(true)
        }
        pedidoServico?.success(false)
        pedidoServico = result
        requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), PEDIDO_SERVICO)
    }

    private fun pedirTempoTodo() {
        if (Build.VERSION.SDK_INT < 29 || Cofre.ler(this, "pediu_tempo_todo") == "1") return
        if (checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED) return
        Cofre.gravar(this, "pediu_tempo_todo", "1")
        requestPermissions(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), PEDIDO_TEMPO_TODO)
    }

    private var pedidoAvisos: MethodChannel.Result? = null

    /** Android 13+: pede a permissão de mostrar avisos. Devolve true se puder avisar. */
    private fun permitirAvisos(result: MethodChannel.Result) {
        Avisos.criarCanais(this)
        if (Avisos.permitido(this)) return result.success(true)
        pedidoAvisos?.success(false)
        pedidoAvisos = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PEDIDO_AVISOS)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sigafape/nativo").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "ler" -> result.success(Cofre.ler(this, call.argument<String>("chave")!!))
                    "gravar" -> {
                        Cofre.gravar(this, call.argument<String>("chave")!!, call.argument<String>("valor"))
                        result.success(null)
                    }
                    "lerSegredo" -> result.success(Cofre.lerSegredo(this, call.argument<String>("chave")!!))
                    "gravarSegredo" -> {
                        Cofre.gravarSegredo(this, call.argument<String>("chave")!!, call.argument<String>("valor"))
                        result.success(null)
                    }
                    // Avisos na barra do Android e conferência em segundo plano (item 1 de 2026-11-12)
                    "avisar" -> {
                        Avisos.mostrar(this, call.argument<String>("chave")!!, call.argument<String>("titulo") ?: "SIGAFAPE", call.argument<String>("texto") ?: "", call.argument<String>("prioridade"))
                        result.success(null)
                    }
                    "permitirAvisos" -> permitirAvisos(result)
                    "agendarConferencia" -> {
                        ConferirNovidades.agendar(this)
                        result.success(null)
                    }
                    "cancelarConferencia" -> {
                        ConferirNovidades.cancelar(this)
                        result.success(null)
                    }
                    "lerQr" -> lerQr(result)
                    "tirarFoto" -> tirarFoto(result)
                    "escolherFotos" -> escolherFotos(result, call.argument<Int>("maximo") ?: 6)
                    "ligarLocalizacao" -> ligarLocalizacao(result)
                    "desligarLocalizacao" -> {
                        LocalizacaoServico.desligar(this)
                        result.success(null)
                    }
                    "abrirPedido" -> {
                        result.success(abrirPedido)
                        abrirPedido = null
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
        if (requestCode == PEDIDO_SERVICO) {
            val r = pedidoServico
            pedidoServico = null
            if (temPermissao()) {
                LocalizacaoServico.ligar(this)
                pedirTempoTodo()
            }
            r?.success(temPermissao())
            return
        }
        if (requestCode == PEDIDO_TEMPO_TODO) return
        if (requestCode == PEDIDO_AVISOS) {
            pedidoAvisos?.success(Avisos.permitido(this))
            pedidoAvisos = null
            return
        }
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
        private const val PEDIDO_LOCAL = 4190
        private const val PEDIDO_AVISOS = 4191
        private const val PEDIDO_SERVICO = 4193
        private const val PEDIDO_TEMPO_TODO = 4194
        private const val PEDIDO_CAMERA = 4195
        private const val PEDIDO_GALERIA = 4196
    }
}
