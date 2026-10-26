package com.spendwise.app

/**
 * Conservative, allocation-light filters shared by live SMS and notifications.
 *
 * They are intentionally narrower than the Dart parser: a false negative here
 * only delays an alert until the next inbox backfill, while a false positive
 * would process a personal message.
 */
object FinancialMessageFilter {
    private val amount = Regex(
        "(?i)(?:₹|rs\\.?|inr)\\s*[\\d,]+(?:\\.\\d{1,2})?" +
            "|\\b[\\d,]+(?:\\.\\d{1,2})?\\s*(?:dr|cr)\\b",
    )

    private val transactionWords = Regex(
        "(?i)\\b(?:debited|credited|spent|paid|sent|received|withdrawn|" +
            "refund(?:ed)?|transaction|txn|payment|upi|neft|imps|rtgs|" +
            "a/c|account|card)\\b",
    )

    private val bankSender = Regex(
        "(?i)hdfc|icici|sbi|axis|kotak|idfc|federal|indusind|rbl|yesbank|" +
            "hsbc|amex|americanexpress|citibank|bob|baroda|canara|pnb|" +
            "unionbank|idbi|bandhan|au-?sfb|equitas|paytm|phonepe|cred|" +
            "slice|onecard|jupiter|fi\\.money",
    )

    private val senderId = Regex("^[A-Za-z]{2}-[A-Za-z0-9]{4,12}$|^[A-Z]{4,12}$")
    private val numericSender = Regex("^\\+?\\d{10,14}$")

    fun looksFinancial(body: String): Boolean {
        if (body.isBlank()) return false
        return amount.containsMatchIn(body) && transactionWords.containsMatchIn(body)
    }

    fun isBankSender(address: String, body: String): Boolean {
        val sender = address.trim()
        if (sender.isEmpty()) return false
        if (senderId.matches(sender) || bankSender.containsMatchIn(sender)) return true
        if (!numericSender.matches(sender)) return false
        // Numeric senders are only trusted for alerts that explicitly mention a
        // bank instrument.
        return Regex(
            "(?i)\\b(?:a/c|account|card|upi|vpa|bank|debited|credited|txn|transaction)\\b",
        ).containsMatchIn(body)
    }

    /** Packages whose notifications are never financial alerts we should read. */
    private val ignoredPackages = setOf(
        "android",
        "com.android.systemui",
        "com.android.settings",
        "com.google.android.gm",
        "com.google.android.apps.messaging",
        "com.whatsapp",
        "com.whatsapp.w4b",
        "org.telegram.messenger",
        "com.instagram.android",
        "com.facebook.katana",
        "com.facebook.orca",
        "com.twitter.android",
        "com.snapchat.android",
        "com.linkedin.android",
        "com.google.android.youtube",
        "com.android.vending",
    )

    fun isNotificationCandidate(packageName: String, body: String): Boolean {
        if (packageName.isBlank() || ignoredPackages.contains(packageName)) return false
        if (packageName == "com.spendwise.app") return false
        return looksFinancial(body)
    }
}
