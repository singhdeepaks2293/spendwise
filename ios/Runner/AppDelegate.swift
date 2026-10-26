import Flutter
import GoogleSignIn
import UIKit
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      self,
      factoryId: "transactionFeedNative",
      nativeAdFactory: TransactionFeedNativeAdFactory()
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}

/// Native card rendered inside the Flutter transaction feed.
///
/// Every AdMob asset view is registered on `GADNativeAdView` before
/// `setNativeAd` so impressions and click tracking work. Flutter passes
/// `darkMode` through `customOptions` to match the app theme.
final class TransactionFeedNativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(
    _ nativeAd: GADNativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> GADNativeAdView? {
    let darkMode = customOptions?["darkMode"] as? Bool ?? false
    let background = darkMode
      ? UIColor(red: 30 / 255, green: 41 / 255, blue: 59 / 255, alpha: 1)
      : UIColor.white
    let foreground = darkMode
      ? UIColor(red: 241 / 255, green: 245 / 255, blue: 249 / 255, alpha: 1)
      : UIColor(red: 15 / 255, green: 23 / 255, blue: 42 / 255, alpha: 1)
    let muted = darkMode
      ? UIColor(red: 148 / 255, green: 163 / 255, blue: 184 / 255, alpha: 1)
      : UIColor(red: 100 / 255, green: 116 / 255, blue: 139 / 255, alpha: 1)
    let accent = UIColor(red: 15 / 255, green: 118 / 255, blue: 110 / 255, alpha: 1)

    let adView = GADNativeAdView()
    adView.backgroundColor = .clear

    let container = UIView()
    container.translatesAutoresizingMaskIntoConstraints = false
    container.backgroundColor = background
    adView.addSubview(container)

    let iconView = UIImageView()
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.contentMode = .scaleAspectFit
    iconView.layer.cornerRadius = 10
    iconView.clipsToBounds = true

    let headline = UILabel()
    headline.font = .systemFont(ofSize: 15, weight: .bold)
    headline.textColor = foreground
    headline.numberOfLines = 1

    let advertiser = UILabel()
    advertiser.font = .systemFont(ofSize: 11)
    advertiser.textColor = muted
    advertiser.numberOfLines = 1

    let attribution = UILabel()
    attribution.text = "Ad"
    attribution.font = .systemFont(ofSize: 10, weight: .bold)
    attribution.textColor = muted
    attribution.textAlignment = .center
    attribution.backgroundColor = UIColor.black.withAlphaComponent(0.06)
    attribution.layer.cornerRadius = 5
    attribution.clipsToBounds = true

    let titleStack = UIStackView(arrangedSubviews: [headline, advertiser])
    titleStack.axis = .vertical
    titleStack.spacing = 1
    titleStack.translatesAutoresizingMaskIntoConstraints = false

    let header = UIStackView(arrangedSubviews: [iconView, titleStack, attribution])
    header.axis = .horizontal
    header.alignment = .center
    header.spacing = 10
    header.translatesAutoresizingMaskIntoConstraints = false

    let body = UILabel()
    body.font = .systemFont(ofSize: 12)
    body.textColor = muted
    body.numberOfLines = 2
    body.translatesAutoresizingMaskIntoConstraints = false

    let mediaView = GADMediaView()
    mediaView.translatesAutoresizingMaskIntoConstraints = false

    let price = UILabel()
    price.font = .systemFont(ofSize: 12, weight: .bold)
    price.textColor = foreground

    let store = UILabel()
    store.font = .systemFont(ofSize: 11)
    store.textColor = muted

    let callToAction = UIButton(type: .system)
    callToAction.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
    callToAction.setTitleColor(.white, for: .normal)
    callToAction.backgroundColor = accent
    callToAction.layer.cornerRadius = 10
    callToAction.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
    callToAction.translatesAutoresizingMaskIntoConstraints = false

    let footer = UIStackView(arrangedSubviews: [price, store, UIView(), callToAction])
    footer.axis = .horizontal
    footer.alignment = .center
    footer.spacing = 8
    footer.translatesAutoresizingMaskIntoConstraints = false

    let stack = UIStackView(arrangedSubviews: [header, body, mediaView, footer])
    stack.axis = .vertical
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(stack)

    NSLayoutConstraint.activate([
      container.topAnchor.constraint(equalTo: adView.topAnchor),
      container.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      container.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      container.bottomAnchor.constraint(equalTo: adView.bottomAnchor),

      stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
      stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),

      iconView.widthAnchor.constraint(equalToConstant: 40),
      iconView.heightAnchor.constraint(equalToConstant: 40),
      attribution.widthAnchor.constraint(equalToConstant: 28),
      attribution.heightAnchor.constraint(equalToConstant: 20),
      mediaView.heightAnchor.constraint(equalToConstant: 140),
      callToAction.heightAnchor.constraint(equalToConstant: 38),
    ])

    headline.text = nativeAd.headline
    body.text = nativeAd.body
    advertiser.text = nativeAd.advertiser
    price.text = nativeAd.price
    store.text = nativeAd.store
    iconView.image = nativeAd.icon?.image

    if nativeAd.body == nil { body.isHidden = true }
    if nativeAd.advertiser == nil { advertiser.isHidden = true }
    if nativeAd.price == nil { price.isHidden = true }
    if nativeAd.store == nil { store.isHidden = true }
    if nativeAd.icon == nil { iconView.isHidden = true }

    if let action = nativeAd.callToAction {
      callToAction.setTitle(action, for: .normal)
    } else {
      callToAction.isHidden = true
    }

    adView.iconView = iconView
    adView.headlineView = headline
    adView.bodyView = body
    adView.advertiserView = advertiser
    adView.priceView = price
    adView.storeView = store
    adView.mediaView = mediaView
    adView.callToActionView = callToAction
    adView.setNativeAd(nativeAd)

    return adView
  }
}
