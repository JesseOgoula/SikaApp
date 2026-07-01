package com.sikaapp.sika_app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * Service Android natif qui intercepte les notifications de toutes les applications.
 *
 * Ce service nécessite que l'utilisateur l'active manuellement dans :
 * Paramètres → Notifications → Accès aux notifications → SIKA
 *
 * Comportement selon l'état de l'app :
 * - App ouverte (Flutter actif) : transmet via MethodChannel à Flutter
 * - App fermée (Flutter inactif) : stocke dans SharedPreferences + notification locale
 */
class SikaNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "SIKA_NOTIF_SVC"

        /** Liste des packages d'apps financières gabonaises connues */
        private val FINANCIAL_PACKAGES = setOf(
            // Airtel Money
            "com.airtel.africa.selfcare",
            "com.airtel.money",
            "com.airtel.moneyga",
            // Moov Money / Flooz
            "com.moov.money",
            "com.moov.africa",
            "ci.moov.flooz",
            // UBA
            "com.uba.vericash",
            "com.uba.mobile",
            // Ecobank
            "com.ecobank.mobile",
            "com.ecobank.ecobankmobile",
            // Bambou EMF
            "com.bambou.emf",
        )

        /** Mots-clés dans le texte qui indiquent un message financier */
        private val FINANCIAL_KEYWORDS = listOf(
            "fcfa", "xaf", "solde", "reçu", "recu", "envoyé", "envoye",
            "débit", "debit", "crédit", "credit", "retrait", "dépôt",
            "depot", "paiement", "transfert", "airtel", "moov", "uba",
            "ecobank", "bambou", "flooz",
        )

        /** Référence au channel Flutter pour envoyer les données */
        var flutterChannel: io.flutter.plugin.common.MethodChannel? = null
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""

        // Ignorer les notifications vides
        if (text.isBlank()) return

        // Filtre 1 : Package connu
        val isKnownPackage = FINANCIAL_PACKAGES.any {
            packageName.contains(it, ignoreCase = true)
        }

        // Filtre 2 : Contenu financier (mots-clés)
        val fullText = "$title $text".lowercase()
        val hasFinancialKeyword = FINANCIAL_KEYWORDS.any { fullText.contains(it) }

        if (!isKnownPackage && !hasFinancialKeyword) return

        val channel = flutterChannel
        if (channel != null) {
            // ── App ouverte : transmettre à Flutter via MethodChannel ──
            val data = mapOf(
                "packageName" to packageName,
                "title" to title,
                "text" to text,
            )
            try {
                channel.invokeMethod("onNotificationReceived", data)
                Log.d(TAG, "Notification forwarded to Flutter: $packageName")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to forward to Flutter, falling back to SharedPreferences: ${e.message}")
                storeAndNotify(packageName, title, text)
            }
        } else {
            // ── App fermée : stocker en SharedPreferences + notification locale ──
            Log.d(TAG, "Flutter not active — storing notification in background store")
            storeAndNotify(packageName, title, text)
        }
    }

    /**
     * Parse la notification financière et stocke dans SharedPreferences,
     * puis affiche une notification locale.
     */
    private fun storeAndNotify(packageName: String, title: String, text: String) {
        // Utiliser le sender = packageName pour la détection d'opérateur
        val sender = packageName
        val body = "$title $text"

        // Vérifier si l'expéditeur ou le corps correspond à un opérateur connu
        val isKnown = SikaSmsReceiver.isKnownSender(sender) || SikaSmsReceiver.hasFinancialContent(body)
        if (!isKnown) return

        val parsed = SikaSmsReceiver.parseSms(sender, body)
        if (parsed == null) {
            Log.d(TAG, "Notification from $packageName — no pattern matched")
            return
        }

        SikaSmsReceiver.storePendingTransaction(applicationContext, parsed, body)
        SikaSmsReceiver.showLocalNotification(applicationContext, parsed)
        Log.d(TAG, "BG notification stored: ${parsed.operatorLabel} ${parsed.type} ${parsed.amount} FCFA")
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Pas d'action nécessaire quand une notification est retirée
    }
}

