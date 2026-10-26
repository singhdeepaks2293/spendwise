package com.spendwise.app

import android.content.Context
import android.graphics.Color
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

/**
 * Renders the in-feed native ad card.
 *
 * AdMob requires every asset view to be registered on the [NativeAdView] before
 * [NativeAdView.setNativeAd]; missing registrations suppress impressions.
 * `customOptions["darkMode"]` lets Flutter keep the card consistent with the
 * active theme.
 */
class TransactionFeedNativeAdFactory(
    private val context: Context,
) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>,
    ): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_transaction, null) as NativeAdView

        val darkMode = customOptions["darkMode"] == true
        val background = if (darkMode) Color.parseColor("#1E293B") else Color.WHITE
        val foreground = if (darkMode) Color.parseColor("#F1F5F9") else Color.parseColor("#0F172A")
        val muted = if (darkMode) Color.parseColor("#94A3B8") else Color.parseColor("#64748B")
        val accent = Color.parseColor("#0F766E")

        val content = adView.findViewById<View>(R.id.native_ad_content)
        val icon = adView.findViewById<ImageView>(R.id.ad_icon)
        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        val body = adView.findViewById<TextView>(R.id.ad_body)
        val advertiser = adView.findViewById<TextView>(R.id.ad_advertiser)
        val price = adView.findViewById<TextView>(R.id.ad_price)
        val store = adView.findViewById<TextView>(R.id.ad_store)
        val media = adView.findViewById<MediaView>(R.id.ad_media)
        val callToAction = adView.findViewById<Button>(R.id.ad_call_to_action)
        val attribution = adView.findViewById<TextView>(R.id.ad_attribution)

        content.setBackgroundColor(background)
        headline.setTextColor(foreground)
        body.setTextColor(muted)
        advertiser.setTextColor(muted)
        price.setTextColor(foreground)
        store.setTextColor(muted)
        attribution.setTextColor(muted)
        callToAction.setTextColor(Color.WHITE)
        callToAction.setBackgroundColor(accent)

        adView.headlineView = headline
        adView.bodyView = body
        adView.advertiserView = advertiser
        adView.priceView = price
        adView.storeView = store
        adView.mediaView = media
        adView.callToActionView = callToAction

        headline.text = nativeAd.headline
        body.text = nativeAd.body
        advertiser.text = nativeAd.advertiser
        price.text = nativeAd.price
        store.text = nativeAd.store

        val iconDrawable = nativeAd.icon?.drawable
        if (iconDrawable != null) {
            icon.setImageDrawable(iconDrawable)
            icon.visibility = View.VISIBLE
            adView.iconView = icon
        } else {
            icon.visibility = View.GONE
        }

        if (nativeAd.body.isNullOrBlank()) body.visibility = View.GONE
        if (nativeAd.advertiser.isNullOrBlank()) advertiser.visibility = View.GONE
        if (nativeAd.price.isNullOrBlank()) price.visibility = View.GONE
        if (nativeAd.store.isNullOrBlank()) store.visibility = View.GONE

        val action = nativeAd.callToAction
        if (action.isNullOrBlank()) {
            callToAction.visibility = View.GONE
        } else {
            callToAction.text = action
            callToAction.visibility = View.VISIBLE
        }

        adView.setNativeAd(nativeAd)
        return adView
    }
}
