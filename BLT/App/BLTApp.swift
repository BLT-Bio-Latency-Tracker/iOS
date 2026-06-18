//
//  BLTApp.swift
//  BLT
//
//  Created by 신찬솔 on 4/27/26.
//

import FirebaseCore
import SwiftUI

@main
struct BLTApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
