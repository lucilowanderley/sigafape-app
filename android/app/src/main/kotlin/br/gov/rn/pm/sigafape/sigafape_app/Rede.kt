package br.gov.rn.pm.sigafape.sigafape_app

import android.content.Context
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManagerFactory
import javax.net.ssl.X509TrustManager

/** Chamadas à API feitas pelo Android em segundo plano (avisos e localização), com a CA própria da rede interna. */
object Rede {
    /** Devolve o JSON da resposta; {"_status": 401} se a sessão expirou; null em outro erro. */
    fun pedir(ctx: Context, metodo: String, url: String, token: String, corpo: JSONObject? = null): JSONObject? {
        val con = URL(url).openConnection() as HttpURLConnection
        if (con is HttpsURLConnection) contexto(ctx)?.let { con.sslSocketFactory = it.socketFactory }
        con.connectTimeout = 15000
        con.readTimeout = 20000
        con.requestMethod = metodo
        con.setRequestProperty("Accept", "application/json")
        con.setRequestProperty("Authorization", "Bearer $token")
        if (corpo != null) {
            con.doOutput = true
            con.setRequestProperty("Content-Type", "application/json")
            con.outputStream.use { it.write(corpo.toString().toByteArray(Charsets.UTF_8)) }
        }
        return try {
            val codigo = con.responseCode
            if (codigo == 401) return JSONObject().put("_status", 401)
            if (codigo !in 200..299) return null
            JSONObject(con.inputStream.bufferedReader().use { it.readText() })
        } finally {
            con.disconnect()
        }
    }

    /** Tenta os endereços salvos (o em uso primeiro) até um responder. */
    fun pedirEmAlgum(ctx: Context, metodo: String, caminho: String, token: String, corpo: JSONObject? = null): JSONObject? {
        for (base in ConferirNovidades.enderecos(ctx)) {
            val r = try { pedir(ctx, metodo, "$base/api/v1/$caminho", token, corpo) } catch (e: Exception) { null }
            if (r != null) return r
        }
        return null
    }

    private var ssl: SSLContext? = null
    private var semCa = false

    /** Confia nas CAs do Android e também na CA própria da rede interna (assets/certs/ca.pem), se existir. */
    private fun contexto(ctx: Context): SSLContext? {
        if (semCa) return null
        ssl?.let { return it }
        return try {
            val pem = ctx.assets.open("flutter_assets/assets/certs/ca.pem").use { it.readBytes() }
            if (pem.size < 100) { semCa = true; return null }
            val ks = KeyStore.getInstance(KeyStore.getDefaultType()).apply { load(null) }
            CertificateFactory.getInstance("X.509").generateCertificates(ByteArrayInputStream(pem)).forEachIndexed { i, c -> ks.setCertificateEntry("ca$i", c) }
            val sistema = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm()).apply { init(null as KeyStore?) }
                .trustManagers.filterIsInstance<X509TrustManager>().first()
            val propria = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm()).apply { init(ks) }
                .trustManagers.filterIsInstance<X509TrustManager>().first()
            val ambos = object : X509TrustManager {
                override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) = sistema.checkClientTrusted(chain, authType)
                override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {
                    try { sistema.checkServerTrusted(chain, authType) } catch (e: Exception) { propria.checkServerTrusted(chain, authType) }
                }
                override fun getAcceptedIssuers(): Array<X509Certificate> = sistema.acceptedIssuers + propria.acceptedIssuers
            }
            SSLContext.getInstance("TLS").apply { init(null, arrayOf(ambos), null) }.also { ssl = it }
        } catch (e: Exception) {
            semCa = true
            null
        }
    }
}
