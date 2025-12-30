//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by 王璇 on 2025/12/23.
//

import SwiftUI
import GoogleSignIn

@main
struct EarthLordApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    print("📲 收到 URL 回调: \(url)")
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
