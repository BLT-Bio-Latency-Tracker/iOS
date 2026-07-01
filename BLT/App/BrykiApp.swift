//
//  BrykiApp.swift
//  Bryki
//
//  Created by 신찬솔 on 4/27/26.
//

import FirebaseCore
import SwiftUI

@main
struct BrykiApp: App {
    init() {
        FreshInstallSessionReset.clearStaleSessionIfNeeded()
        NetworkClient.shared.baseURL = URL(string: "https://api.bryki.site")
        NetworkClient.shared.accessTokenProvider = {
            AuthSessionStore.shared.accessToken
        }
        NetworkClient.shared.accessTokenRefreshHandler = {
            await AuthSessionStore.shared.refreshAccessToken()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    FirebaseBootstrap.configureIfNeeded()
                }
        }
    }
}

private enum FreshInstallSessionReset {
    private static let installMarkerKey = "bryki.install.marker.v1"

    static func clearStaleSessionIfNeeded(
        userDefaults: UserDefaults = .standard,
        authSessionStore: AuthSessionStore = .shared,
        localProfileStore: LocalProfileStore = LocalProfileStore()
    ) {
        guard userDefaults.object(forKey: installMarkerKey) == nil else { return }

        authSessionStore.clear()
        localProfileStore.clear()
        userDefaults.set(true, forKey: installMarkerKey)
    }
}

private enum FirebaseBootstrap {
    @MainActor
    static func configureIfNeeded() {
        #if DEBUG
        return
        #else
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
        #endif
    }
}
