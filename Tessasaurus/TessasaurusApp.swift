//
//  TessasaurusApp.swift
//  Tessasaurus
//
//  Created by Thanh Huynh on 1/28/26.
//

import SwiftUI
import FirebaseCore

@main
struct TessasaurusApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if !hasCompletedOnboarding {
                    OnboardingView()
                }
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

extension Notification.Name {
    static let onboardingWillDismiss = Notification.Name("onboardingWillDismiss")
}
