package br.gov.rn.pm.sigafape.sigafape_app

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Conferência em segundo plano (app fechado): a cada 15 minutos, com internet, pergunta ao servidor
 * (GET /api/v1/novidades) se chegaram notificações ou avisos e mostra na barra do Android os que ainda
 * não foram avisados. Não usa Firebase: funciona só com o servidor do SIGAFAPE.
 */
class ConferirNovidades(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {

    override fun doWork(): Result {
        val ctx = applicationContext
        val token = Cofre.lerSegredo(ctx, "token") ?: return Result.success()
        for (base in enderecos(ctx)) {
            val json = try { Rede.pedir(ctx, "GET", "$base/api/v1/novidades", token) } catch (e: Exception) { null } ?: continue
            if (json.optInt("_status") == 401) return Result.success() // sessão expirada: o app pede login ao abrir
            avisarNovos(ctx, json)
            avisarVersaoNova(ctx, base, token)
            return Result.success()
        }
        return Result.success()
    }

    companion object {
        private const val NOME = "sigafape_conferir_novidades"

        fun agendar(ctx: Context) {
            val pedido = PeriodicWorkRequestBuilder<ConferirNovidades>(15, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(ctx).enqueueUniquePeriodicWork(NOME, ExistingPeriodicWorkPolicy.KEEP, pedido)
        }

        fun cancelar(ctx: Context) {
            WorkManager.getInstance(ctx).cancelUniqueWork(NOME)
        }

        /**
         * Versão nova do app (GET /api/v1/app/versao?atual=X): avisa uma vez por versão na barra do Android.
         * Tocar no aviso abre o app, que mostra a faixa dourada "Versão X disponível" no Início.
         */
        fun avisarVersaoNova(ctx: Context, base: String, token: String) {
            try {
                val atual = ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionName ?: return
                val r = Rede.pedir(ctx, "GET", "$base/api/v1/app/versao?atual=" + java.net.URLEncoder.encode(atual, "UTF-8"), token) ?: return
                if (!r.optBoolean("nova")) return
                val nova = r.optString("versao")
                if (nova.isBlank() || Cofre.ler(ctx, "aviso_versao") == nova) return
                Avisos.mostrar(ctx, "app-versao-$nova", "Nova versão do app: $nova", "Toque para ver o que mudou e atualizar.", null, "inicio")
                Cofre.gravar(ctx, "aviso_versao", nova)
            } catch (e: Exception) {}
        }

        /** Endereço em uso primeiro, depois os outros salvos em Eu → Servidores. */
        fun enderecos(ctx: Context): List<String> {
            val lista = mutableListOf<String>()
            Cofre.ler(ctx, "servidor")?.takeIf { it.isNotBlank() }?.let { lista.add(it) }
            try {
                val arr = JSONArray(Cofre.ler(ctx, "servidores") ?: "[]")
                for (i in 0 until arr.length()) {
                    val e = arr.getJSONObject(i).optString("endereco")
                    if (e.isNotBlank() && e !in lista) lista.add(e)
                }
            } catch (e: Exception) {}
            return lista
        }

        /**
         * Mostra os itens cuja chave ainda não está em "vistos" (a mesma lista que o app grava quando está aberto).
         * A lista guardada passa a ser só a dos itens ainda pendentes, para não crescer sem fim.
         */
        fun avisarNovos(ctx: Context, json: JSONObject) {
            val itens = json.optJSONArray("itens") ?: return
            val guardado = Cofre.ler(ctx, "vistos")
            val vistos = mutableSetOf<String>()
            try {
                val arr = JSONArray(guardado ?: "[]")
                for (i in 0 until arr.length()) vistos.add(arr.getString(i))
            } catch (e: Exception) {}
            val atuais = JSONArray()
            for (i in 0 until itens.length()) {
                val it = itens.getJSONObject(i)
                val chave = it.optString("chave")
                if (chave.isBlank()) continue
                atuais.put(chave)
                // Primeira conferência depois do login: só marca como visto (o número no sino já mostra).
                if (guardado != null && chave !in vistos) {
                    Avisos.mostrar(ctx, chave, it.optString("titulo", "SIGAFAPE"), it.optString("texto"), it.optString("prioridade"))
                }
            }
            Cofre.gravar(ctx, "vistos", atuais.toString())
        }
    }
}
