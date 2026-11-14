package br.gov.rn.pm.sigafape.sigafape_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/** Avisos na barra do Android (notificações e avisos do sino do SIGAFAPE). */
object Avisos {
    const val CANAL = "alertas"
    const val CANAL_URGENTE = "alertas_urgentes"
    const val EXTRA_ABRIR = "sigafape_abrir"

    fun criarCanais(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
        nm.createNotificationChannel(
            NotificationChannel(CANAL, "Notificações e avisos", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Notificações da Central de Alertas e avisos do sino"
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(CANAL_URGENTE, "Notificações urgentes", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Atenção, urgente e urgentíssima: pedem ciência assinada"
                enableVibration(true)
            }
        )
    }

    fun permitido(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < 33 || ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    /** Mostra um aviso. [chave] fixa (ex.: "alerta-12") evita aviso repetido do mesmo item. */
    @Suppress("MissingPermission")
    fun mostrar(ctx: Context, chave: String, titulo: String, texto: String, prioridade: String?, abrirEm: String = "alertas") {
        if (!permitido(ctx)) return
        criarCanais(ctx)
        val urgente = prioridade == "urgente" || prioridade == "urgentissima" || prioridade == "atencao"
        val abrir = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_ABRIR, abrirEm)
        }
        val pi = PendingIntent.getActivity(ctx, chave.hashCode(), abrir, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(ctx, if (urgente) CANAL_URGENTE else CANAL)
            .setSmallIcon(R.drawable.ic_aviso)
            .setContentTitle(titulo)
            .setContentText(texto)
            .setStyle(NotificationCompat.BigTextStyle().bigText(texto))
            .setPriority(if (urgente) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .build()
        try {
            NotificationManagerCompat.from(ctx).notify(chave.hashCode(), n)
        } catch (e: SecurityException) {
            // Permissão retirada pelo policial nas configurações do Android.
        }
    }
}
