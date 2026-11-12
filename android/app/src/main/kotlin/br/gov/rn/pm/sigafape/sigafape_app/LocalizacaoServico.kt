package br.gov.rn.pm.sigafape.sigafape_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Localização em segundo plano (decisão de 2026-11-12: sempre que o policial estiver logado no app).
 * Serviço em primeiro plano com aviso fixo na barra do Android. A cada minuto pergunta ao servidor
 * (GET /api/v1/posicao) se deve enviar: envia no intervalo de Configurações ou na hora, quando o Painel 190 pede.
 * Se o sistema desligar a localização (intervalo 0) ou a sessão expirar, o serviço para.
 */
class LocalizacaoServico : Service() {
    private lateinit var fio: HandlerThread
    private lateinit var handler: Handler
    private var ultimoEnvio = 0L
    private var ultimaHora: String? = null
    private var intervaloMin = 5

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        fio = HandlerThread("sigafape-localizacao").apply { start() }
        handler = Handler(fio.looper)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            ServiceCompat.startForeground(
                this, AVISO_ID, aviso(),
                if (Build.VERSION.SDK_INT >= 29) ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION else 0
            )
        } catch (e: Exception) {
            // Android não deixou (ex.: sem permissão de localização): tenta de novo quando o app abrir.
            stopSelf()
            return START_NOT_STICKY
        }
        handler.removeCallbacksAndMessages(null)
        handler.post(tique)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        fio.quitSafely()
        super.onDestroy()
    }

    private val tique = object : Runnable {
        override fun run() {
            try {
                if (!conferir()) {
                    stopSelf()
                    return
                }
            } catch (e: Exception) {
                // Sem rede agora: tenta no próximo minuto.
            }
            handler.postDelayed(this, 60_000L)
        }
    }

    /** Falso quando é para parar (sessão expirada ou localização desligada no sistema). */
    private fun conferir(): Boolean {
        val token = Cofre.lerSegredo(this, "token") ?: return false
        val estado = Rede.pedirEmAlgum(this, "GET", "posicao", token) ?: return true
        if (estado.optInt("_status") == 401) return false
        if (!estado.optBoolean("ativo", true) && !estado.optBoolean("pedido")) return false
        intervaloMin = estado.optInt("intervalo_minutos", 5).coerceAtLeast(1)
        val vencido = System.currentTimeMillis() - ultimoEnvio >= intervaloMin * 60_000L - 5_000L
        if (!estado.optBoolean("pedido") && !vencido) return true
        val l = posicao() ?: return true
        val corpo = JSONObject().put("latitude", l.latitude).put("longitude", l.longitude).put("precisao", l.accuracy.toDouble())
        val r = Rede.pedirEmAlgum(this, "POST", "posicao", token, corpo) ?: return true
        if (r.optInt("_status") == 401) return false
        ultimoEnvio = System.currentTimeMillis()
        ultimaHora = SimpleDateFormat("HH:mm", Locale("pt", "BR")).format(Date())
        getSystemService(NotificationManager::class.java)?.notify(AVISO_ID, aviso())
        return true
    }

    private fun permitido(): Boolean =
        checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    /** Posição recente (até 1 minuto) ou nova, esperando até 30 segundos pelo GPS/rede. */
    @Suppress("MissingPermission", "DEPRECATION")
    private fun posicao(): Location? {
        if (!permitido()) return null
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val provedores = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER).filter {
            try { lm.isProviderEnabled(it) } catch (e: Exception) { false }
        }
        if (provedores.isEmpty()) return null
        var melhor: Location? = provedores.mapNotNull { try { lm.getLastKnownLocation(it) } catch (e: Exception) { null } }
            .filter { System.currentTimeMillis() - it.time < 60_000L }
            .minByOrNull { it.accuracy }
        if (melhor != null && melhor!!.accuracy <= 50f) return melhor
        val pronto = CountDownLatch(1)
        val ouvinte = object : LocationListener {
            override fun onLocationChanged(l: Location) {
                if (melhor == null || l.accuracy < melhor!!.accuracy) melhor = l
                if (l.accuracy <= 50f) pronto.countDown()
            }
            override fun onStatusChanged(p: String?, s: Int, e: Bundle?) {}
            override fun onProviderEnabled(p: String) {}
            override fun onProviderDisabled(p: String) {}
        }
        for (p in provedores) {
            try { lm.requestLocationUpdates(p, 1000L, 0f, ouvinte, Looper.getMainLooper()) } catch (e: Exception) {}
        }
        pronto.await(30, TimeUnit.SECONDS)
        try { lm.removeUpdates(ouvinte) } catch (e: Exception) {}
        return melhor
    }

    private fun aviso(): Notification {
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(
                NotificationChannel(CANAL, "Localização em serviço", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Aviso fixo enquanto o app envia a sua posição ao SIGAFAPE"
                }
            )
        }
        val abrir = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val texto = "Enviando sua posição ao SIGAFAPE a cada $intervaloMin min" + (ultimaHora?.let { " · última às $it" } ?: "")
        return NotificationCompat.Builder(this, CANAL)
            .setSmallIcon(R.drawable.ic_local)
            .setContentTitle("Localização ligada")
            .setContentText(texto)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(abrir)
            .build()
    }

    companion object {
        private const val CANAL = "localizacao"
        private const val AVISO_ID = 4192

        /**
         * Com o app aberto ([primeiroPlano]) usa startService e o serviço passa a primeiro plano sozinho: se o Android
         * não deixar, o serviço só para (com startForegroundService o Android fecharia o app). Fora do app (celular
         * religado) só no Android até 13, que permite localização iniciada pelo BOOT; no 14+ volta quando o app abrir.
         */
        fun ligar(ctx: Context, primeiroPlano: Boolean = true) {
            if (Cofre.lerSegredo(ctx, "token") == null) return
            val permitido = ctx.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                ctx.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
            if (!permitido) return
            val i = Intent(ctx, LocalizacaoServico::class.java)
            try {
                if (primeiroPlano || Build.VERSION.SDK_INT < 26) ctx.startService(i)
                else if (Build.VERSION.SDK_INT < 34) ctx.startForegroundService(i)
            } catch (e: Exception) {
                // Android não deixou iniciar agora: o app tenta de novo ao abrir.
            }
        }

        fun desligar(ctx: Context) {
            ctx.stopService(Intent(ctx, LocalizacaoServico::class.java))
        }
    }
}

/** Celular ligado de novo ou app atualizado: volta a enviar a posição (se o policial continua logado). */
class ReiniciarLocalizacao : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            LocalizacaoServico.ligar(ctx, primeiroPlano = false)
        }
    }
}
