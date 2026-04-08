import StoreKit
import UIKit

final class ReviewManager {
    static let shared = ReviewManager()
    private let defaults = UserDefaults.standard
    private let lastVersionKey = "ReviewManager_lastVersionPrompted"
    private let playTimeKey = "ReviewManager_totalPlayTime"
    private init() {}

    func addPlayTime(_ seconds: Double) {
        let total = defaults.double(forKey: playTimeKey) + seconds
        defaults.set(total, forKey: playTimeKey)
        guard total >= 1200 else { return }
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        guard defaults.string(forKey: lastVersionKey) != currentVersion else { return }
        defaults.set(currentVersion, forKey: lastVersionKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            else { return }
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
