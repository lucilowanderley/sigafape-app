package br.gov.rn.pm.sigafape.sigafape_app

import android.app.Application
import android.content.Context
import androidx.work.Configuration
import java.io.File

/**
 * Aplicativo: WorkManager inicia só quando usado (não na abertura) e, se o app fechar por erro,
 * o motivo fica guardado em ultimo-erro.txt para o app mostrar na próxima abertura (Eu › Sobre).
 */
class App : Application(), Configuration.Provider {
    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder().build()

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        val anterior = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { fio, erro ->
            try {
                File(base.filesDir, ARQUIVO).writeText(
                    "${java.util.Date()} · versão ${try { base.packageManager.getPackageInfo(base.packageName, 0).versionName } catch (e: Exception) { "?" }}\n" +
                        android.util.Log.getStackTraceString(erro).take(6000)
                )
            } catch (e: Exception) {
            }
            anterior?.uncaughtException(fio, erro)
        }
    }

    companion object {
        const val ARQUIVO = "ultimo-erro.txt"

        /** Último erro que fechou o app (e apaga). */
        fun ultimoErro(ctx: Context): String? {
            val f = File(ctx.filesDir, ARQUIVO)
            if (!f.exists()) return null
            return try { f.readText().also { f.delete() } } catch (e: Exception) { null }
        }
    }
}
