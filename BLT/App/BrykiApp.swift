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
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
