package br.gov.rn.pm.sigafape.sigafape_app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import android.net.Uri
import java.io.ByteArrayOutputStream

/** Fotos da ocorrência: reduz para no máximo 1600 px no lado maior, JPEG 80%, já girada (o envio fica leve no 4G). */
object Fotos {
    private const val LADO = 1600

    fun reduzir(ctx: Context, uri: Uri): ByteArray? = try {
        val limites = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, limites) }
        var amostra = 1
        while (limites.outWidth / (amostra * 2) >= LADO || limites.outHeight / (amostra * 2) >= LADO) amostra *= 2
        val bmp = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = amostra }) }
        if (bmp == null) null else {
            val giro = try {
                ctx.contentResolver.openInputStream(uri)?.use {
                    when (ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                        ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                        ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                        ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                        else -> 0f
                    }
                } ?: 0f
            } catch (e: Exception) { 0f }
            val escala = minOf(1f, LADO.toFloat() / maxOf(bmp.width, bmp.height))
            val m = Matrix().apply { postScale(escala, escala); postRotate(giro) }
            val saida = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
            ByteArrayOutputStream().use { out ->
                saida.compress(Bitmap.CompressFormat.JPEG, 80, out)
                out.toByteArray()
            }
        }
    } catch (e: Exception) {
        null
    }
}
