package com.sikaapp.sika_app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.FlutterInjector

/**
 * Service Android natif qui intercepte les notifications de toutes les applications.
 *
 * Ce service nécessite que l'utilisateur l'active manuellement dans :
 * Paramètres → Notifications → Accès aux notifications → SIKA
 *
 * Une fois activé, il reçoit toutes les notifications et filtre celles
 * des opérateurs financiers gabonais (Airtel, Moov, UBA, Ecobank, etc.)
 * pour les transmettre à Flutter via un MethodChannel.
 */
class SikaNotificationListenerService : NotificationListenerService() {

    companion object {
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
            // Bambou EMF (à confirmer)
            "com.bambou.emf",
        )

        /** Mots-clés dans le texte qui indiquent un message financier */
        private val FINANCIAL_KEYWORDS = listOf(
            "fcfa", "xaf", "solde", "reçu", "envoyé", "débit", "crédit",
            "retrait", "dépôt", "paiement", "transfert", "airtel",
            "moov", "uba", "ecobank", "bambou", "flooz",
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
        val hasFinancialKeyword = FINANCIAL_KEYWORDS.any { 
            fullText.contains(it) 
        }

        if (!isKnownPackage && !hasFinancialKeyword) return

        // Transmettre à Flutter via le MethodChannel
        val data = mapOf(
            "packageName" to packageName,
            "title" to title,
            "text" to text,
        )

        try {
            flutterChannel?.invokeMethod("onNotificationReceived", data)
        } catch (e: Exception) {
            // Ignore — Flutter peut ne pas être prêt
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Pas d'action nécessaire quand une notification est retirée
    }
}
