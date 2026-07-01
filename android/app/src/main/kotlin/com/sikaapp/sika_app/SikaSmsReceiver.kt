package com.sikaapp.sika_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.SmsMessage
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.abs

/**
 * BroadcastReceiver statique pour l'interception des SMS financiers.
 *
 * Déclaré dans le manifest → réveillé par Android même app fermée.
 * Flow : SMS reçu → parsing Kotlin → SharedPreferences → notification locale.
 * Au démarrage de l'app, Flutter importe ces transactions via MethodChannel.
 */
class SikaSmsReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "SIKA_SMS_BG"
        const val PREFS_NAME = "sika_background_pending"
        const val PREFS_KEY = "pending_transactions"
        private const val NOTIF_CHANNEL_ID = "sika_bg_detection"
        private const val NOTIF_CHANNEL_NAME = "Détection automatique"

        private val KNOWN_SENDERS = listOf(
            "airtel", "airtelga", "airtelmoney",
            "24783566639", "077617569", "77617569", "24177617569",
            "moov", "moovga", "flooz",
            "uba",
            "ecobank",
            "bambou",
        )

        private val FINANCIAL_KEYWORDS = listOf(
            "fcfa", "xaf", "solde", "reçu", "recu", "envoyé", "envoye",
            "débit", "debit", "crédit", "credit", "retrait", "dépôt",
            "depot", "paiement", "transfert",
        )

        data class ParsedSms(
            val operatorKey: String,
            val operatorLabel: String,
            val type: String,
            val label: String,
            val amount: Int,
            val description: String,
            val category: String,
        )

        fun parseAmount(str: String): Int {
            if (str.isBlank()) return 0
            val clean = str.trim()
                .replace(Regex("""\s"""), "")
                .replace(Regex("""[.,](\d{3})""")) { it.groupValues[1] }
                .replace(",", ".")
            return clean.toDoubleOrNull()?.toInt() ?: 0
        }

        fun isKnownSender(sender: String): Boolean {
            val lower = sender.lowercase(Locale.ROOT)
            return KNOWN_SENDERS.any { lower.contains(it) }
        }

        fun hasFinancialContent(body: String): Boolean {
            val lower = body.lowercase(Locale.ROOT)
            return FINANCIAL_KEYWORDS.any { lower.contains(it) }
        }

        fun detectOperator(sender: String, body: String): String? {
            val full = "${sender.lowercase()} ${body.lowercase()}"
            return when {
                full.contains("airtel") || sender.contains("24783566639") ||
                sender.contains("077617569") || sender.contains("77617569") ||
                sender.contains("24177617569") -> "AIRTEL_MONEY"
                full.contains("moov") || full.contains("flooz") -> "MOOV_MONEY"
                Regex("""\buba\b""", RegexOption.IGNORE_CASE).containsMatchIn(full) -> "UBA_GABON"
                full.contains("ecobank") -> "ECOBANK_GABON"
                full.contains("bambou") -> "BAMBOU_EMF"
                else -> null
            }
        }

        fun parseSms(sender: String, body: String): ParsedSms? {
            val operatorKey = detectOperator(sender, body) ?: return null
            return when (operatorKey) {
                "AIRTEL_MONEY" -> parseAirtel(body, operatorKey)
                "MOOV_MONEY"  -> parseMoov(body, operatorKey)
                "UBA_GABON"   -> parseUba(body, operatorKey)
                "ECOBANK_GABON" -> parseEcobank(body, operatorKey)
                "BAMBOU_EMF"  -> parseBambou(body, operatorKey)
                else -> null
            }
        }

        private fun parseAirtel(body: String, opKey: String): ParsedSms? {
            val opLabel = "Airtel Money"
            // Réception
            listOf(
                Regex("""vous avez re[çc]u\s+(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+(?:de|du)\s+(.+?)(?:\s+le\s+|\s*Nouveau|\s*\.\s*|Solde|${'$'})""", RegexOption.IGNORE_CASE),
                Regex("""re[çc]u\s+(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+(?:du|de)\s+(.+?)(?:\.|Nouveau|Solde|${'$'})""", RegexOption.IGNORE_CASE),
                Regex("""(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+re[çc]u\s+(?:du|de)\s+(.+?)(?:\.|Solde|${'$'})""", RegexOption.IGNORE_CASE),
            ).forEach { regex ->
                regex.find(body)?.let { m ->
                    val amt = parseAmount(m.groupValues.getOrElse(1) { "" })
                    if (amt > 0) return ParsedSms(opKey, opLabel, "income", "Réception", amt,
                        "Reçu de ${m.groupValues.getOrElse(2) { "inconnu" }.trim()}", "cat-transferts")
                }
            }
            // Envoi
            Regex("""vous avez envoy[eé]\s+(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+(?:[àa]|au)\s+(.+?)(?:\s+le\s+|\s*frais|\s*\.\s*|Solde|${'$'})""", RegexOption.IGNORE_CASE)
                .find(body)?.let { m ->
                    val amt = parseAmount(m.groupValues.getOrElse(1) { "" })
                    if (amt > 0) return ParsedSms(opKey, opLabel, "expense", "Envoi", amt,
                        "Envoi à ${m.groupValues.getOrElse(2) { "inconnu" }.trim()}", "cat-transferts")
                }
            // Paiement
            Regex("""vous\s+avez\s+pay[eé]\s+(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+(?:[àa]|au)\s+(.+?)(?:\s+en\s+reference|\s+le\s+|\s*\.\s*|Solde|${'$'})""", RegexOption.IGNORE_CASE)
                .find(body)?.let { m ->
                    val amt = parseAmount(m.groupValues.getOrElse(1) { "" })
                    if (amt > 0) return ParsedSms(opKey, opLabel, "expense", "Paiement", amt,
                        "Paiement ${m.groupValues.getOrElse(2) { "" }.trim()}", "cat-autres")
                }
            // Retrait
            Regex("""retrait\s+(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)(?:\s+reussi)?(?:\s+vers\s+(.+?))?(?:\.|Solde|${'$'})""", RegexOption.IGNORE_CASE)
                .find(body)?.let { m ->
                    val amt = parseAmount(m.groupValues.getOrElse(1) { "" })
                    val dest = m.groupValues.getOrElse(2) { "" }.trim()
                    if (amt > 0) return ParsedSms(opKey, opLabel, "expense", "Retrait", amt,
                        if (dest.isNotBlank()) "Retrait vers $dest" else "Retrait Airtel Money", "cat-transferts")
                }
            // Dépôt
            Regex("""d[eé]p[oô]t\s+(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)""", RegexOption.IGNORE_CASE)
                .find(body)?.let { m ->
                    val amt = parseAmount(m.groupValues.getOrElse(1) { "" })
                    if (amt > 0) return ParsedSms(opKey, opLabel, "income", "Dépôt", amt,
                        "Dépôt Airtel Money", "cat-transferts")
                }
            // Crédit téléphonique
            Regex("""achat\s+(?:de\s+)?cr[eé]dit\s+(?:de\s+communication\s+)?(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)""", RegexOption.IGNORE_CASE)
                .find(body)?.let { m ->
                    val amt = parseAmount(m.groupValues.getOrElse(1) { "" })
                    if (amt > 0) return ParsedSms(opKey, opLabel, "expense", "Crédit tél.", amt,
                        "Achat crédit téléphonique", "cat-factures")
                }
            return null
        }

        private fun parseMoov(body: String, opKey: String): ParsedSms? {
            val opLabel = "Moov Money"
            listOf(
                Triple("income", Regex("""cr[eé]dit\s+(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+(?:re[çc]u\s+)?(?:de|par)\s+(.+?)(?:\.|Solde|${'$'})""", RegexOption.IGNORE_CASE), true),
                Triple("expense", Regex("""d[eé]bit\s+(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+(?:effectu[eé]\s+)?(?:pour|vers|[àa])\s+(.+?)(?:\.|Solde|${'$'})""", RegexOption.IGNORE_CASE), true),
                Triple("expense", Regex("""transfert\s+(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+vers\s+(.+?)(?:\.|Solde|${'$'})""", RegexOption.IGNORE_CASE), true),
                Triple("expense", Regex("""retrait\s+(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)""", RegexOption.IGNORE_CASE), false),
            ).forEach { (type, regex, hasContact) ->
                regex.find(body)?.let { m ->
                    val amt = parseAmount(m.groupValues.getOrElse(1) { "" })
                    if (amt <= 0) return@let
                    val contact = if (hasContact) m.groupValues.getOrElse(2) { "" }.trim() else ""
                    val desc = when {
                        type == "income" -> "Reçu de ${contact.ifBlank { "Moov Money" }}"
                        contact.isNotBlank() -> "Débit vers $contact"
                        else -> "Moov Money"
                    }
                    return ParsedSms(opKey, opLabel, type, type, amt, desc, "cat-transferts")
                }
            }
            return null
        }

        private fun parseUba(body: String, opKey: String): ParsedSms? {
            val opLabel = "UBA"
            listOf(
                Pair("income", Regex("""cr[eé]dit[ée]?\s+(?:de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|CFA|F)\s+(?:par|de|depuis)\s+(.+?)(?:\.|Solde|Ref|${'$'})""", RegexOption.IGNORE_CASE)),
                Pair("expense", Regex("""d[eé]bit[ée]?\s+(?:de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|CFA|F)\s+(?:pour|vers|[àa])\s+(.+?)(?:\.|Solde|Ref|${'$'})""", RegexOption.IGNORE_CASE)),
                Pair("expense", Regex("""retrait\s+(?:dab|guichet|atm)?\s*(?:de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|CFA|F)""", RegexOption.IGNORE_CASE)),
                Pair("expense", Regex("""(?:paiement|achat)\s+(?:carte|tpe)\s+(?:de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|CFA|F)\s+(?:chez\s+)?(.+?)(?:\.|Ref|${'$'})""", RegexOption.IGNORE_CASE)),
            ).forEach { (type, regex) ->
                regex.find(body)?.let { m ->
                    val amt = parseAmount(m.groupValues.getOrElse(1) { "" })
                    if (amt <= 0) return@let
                    val contact = m.groupValues.getOrElse(2) { "" }.trim()
                    val desc = if (type == "income") "Crédit ${contact.ifBlank { "UBA" }}"
                               else "Débit ${contact.ifBlank { "UBA" }}"
                    return ParsedSms(opKey, opLabel, type, type, amt, desc, "cat-transferts")
                }
            }
            return null
        }

        private fun parseEcobank(body: String, opKey: String): ParsedSms? {
            val opLabel = "Ecobank"
            listOf(
                Pair("income", Regex("""(?:credit|cr[eé]dit|received|re[çc]u)\s+(?:of\s+|de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|CFA|F|XOF)""", RegexOption.IGNORE_CASE)),
                Pair("expense", Regex("""(?:debit|d[eé]bit|payment|sent|envoy[eé])\s+(?:of\s+|de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|CFA|F|XOF)""", RegexOption.IGNORE_CASE)),
                Pair("expense", Regex("""ecobank\s+xpress\s+(?:cash\s+)?(?:de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|CFA)""", RegexOption.IGNORE_CASE)),
            ).forEach { (type, regex) ->
                regex.find(body)?.let { m ->
                    val amt = parseAmount(m.groupValues.getOrElse(1) { "" })
                    if (amt <= 0) return@let
                    val desc = if (type == "income") "Crédit Ecobank" else "Débit Ecobank"
                    return ParsedSms(opKey, opLabel, type, type, amt, desc, "cat-transferts")
                }
            }
            return null
        }

        private fun parseBambou(body: String, opKey: String): ParsedSms? {
            val opLabel = "Bambou EMF"
            listOf(
                Pair("income", Regex("""cr[eé]dit[ée]?\s+(?:de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|F)""", RegexOption.IGNORE_CASE)),
                Pair("expense", Regex("""d[eé]bit[ée]?\s+(?:de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|F)""", RegexOption.IGNORE_CASE)),
            ).forEach { (type, regex) ->
                regex.find(body)?.let { m ->
                    val amt = parseAmount(m.groupValues.getOrElse(1) { "" })
                    if (amt <= 0) return@let
                    val desc = if (type == "income") "Crédit Bambou EMF" else "Débit Bambou EMF"
                    return ParsedSms(opKey, opLabel, type, type, amt, desc, "cat-transferts")
                }
            }
            return null
        }

        fun generateId(parsed: ParsedSms, receivedAt: String): String {
            val src = "${parsed.operatorKey}-${parsed.amount}-${parsed.type}-$receivedAt"
            val digest = MessageDigest.getInstance("SHA-256").digest(src.toByteArray())
            return digest.joinToString("") { "%02x".format(it) }.substring(0, 16)
        }

        fun storePendingTransaction(context: Context, parsed: ParsedSms, body: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val now = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.ROOT).format(Date())
            val id = generateId(parsed, now)

            val obj = JSONObject().apply {
                put("id", id)
                put("source", "sms")
                put("operatorKey", parsed.operatorKey)
                put("operatorLabel", parsed.operatorLabel)
                put("operatorColor", "#999999")
                put("accountType", "mobile_money")
                put("patternLabel", parsed.label)
                put("type", parsed.type)
                put("amount", parsed.amount)
                put("description", parsed.description)
                put("suggestedCategory", parsed.category)
                put("date", now.split("T")[0])
                put("detectedBalance", JSONObject.NULL)
                put("rawMessage", body)
                put("parsedAt", now)
                put("receivedAt", now)
                put("externalId", JSONObject.NULL)
                put("status", "pending")
            }

            val existing = prefs.getString(PREFS_KEY, "[]")
            val arr = try { JSONArray(existing) } catch (_: Exception) { JSONArray() }

            // Déduplication : même opérateur + montant + type dans les 60 dernières secondes
            for (i in 0 until arr.length()) {
                val item = arr.getJSONObject(i)
                if (item.getString("operatorKey") == parsed.operatorKey &&
                    item.getInt("amount") == parsed.amount &&
                    item.getString("type") == parsed.type) {
                    val existingTime = try {
                        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.ROOT)
                            .parse(item.getString("receivedAt"))?.time ?: 0L
                    } catch (_: Exception) { 0L }
                    if (abs(Date().time - existingTime) < 60_000) {
                        Log.d(TAG, "Duplicate BG transaction, skipping")
                        return
                    }
                }
            }

            arr.put(obj)
            prefs.edit().putString(PREFS_KEY, arr.toString()).apply()
            Log.d(TAG, "Stored BG tx: ${parsed.operatorLabel} ${parsed.type} ${parsed.amount} FCFA")
        }

        fun showLocalNotification(context: Context, parsed: ParsedSms) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    NOTIF_CHANNEL_ID, NOTIF_CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifications quand une transaction est détectée automatiquement"
                }
                manager.createNotificationChannel(channel)
            }

            val sign = if (parsed.type == "income") "+" else "-"
            val formattedAmount = parsed.amount.toString()
                .reversed().chunked(3).joinToString(" ").reversed()

            val notif = NotificationCompat.Builder(context, NOTIF_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Transaction détectée — ${parsed.operatorLabel}")
                .setContentText("$sign $formattedAmount FCFA · ${parsed.description}")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .build()

            manager.notify((System.currentTimeMillis() % 10000).toInt(), notif)
            Log.d(TAG, "BG local notification shown")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "android.provider.Telephony.SMS_RECEIVED") return

        Log.d(TAG, "SikaSmsReceiver.onReceive (background mode)")

        val bundle = intent.extras ?: return
        val pdus = bundle.get("pdus") as? Array<*> ?: return
        val format = bundle.getString("format") ?: return

        for (pdu in pdus) {
            val smsMessage = SmsMessage.createFromPdu(pdu as ByteArray, format)
            val sender = smsMessage.displayOriginatingAddress ?: ""
            val body = smsMessage.displayMessageBody ?: ""

            Log.d(TAG, "BG SMS from: '$sender'")

            if (!isKnownSender(sender) && !hasFinancialContent(body)) {
                Log.d(TAG, "BG SMS ignored — not financial")
                continue
            }

            val parsed = parseSms(sender, body)
            if (parsed == null) {
                Log.d(TAG, "BG SMS from $sender — no pattern matched")
                continue
            }

            storePendingTransaction(context, parsed, body)
            showLocalNotification(context, parsed)
        }
    }
}
