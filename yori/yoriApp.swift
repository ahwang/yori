//
//  yoriApp.swift
//  yori
//
//  Created by Andrew Hwang on 11/1/25.
//

import SwiftUI
//import GoogleSignIn
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    // Configure Firebase Messaging for phone auth
    Auth.auth().settings?.isAppVerificationDisabledForTesting = false

    // Request notification permissions
    UNUserNotificationCenter.current().delegate = self
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { _, _ in }
    )

    application.registerForRemoteNotifications()

    return true
  }

  // Handle APNs token registration
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error.localizedDescription)")
  }

  // Handle incoming remote notifications (required for Firebase phone auth)
  func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                   fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }
    // Handle other remote notifications here if needed
    completionHandler(.noData)
  }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
      completionHandler([[.banner, .list, .sound]])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    completionHandler()
  }
}

@main
struct yoriApp: App {

//    init() {
//        // Configure Google Sign-In
//        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
//           let plist = NSDictionary(contentsOfFile: path),
//           let clientId = plist["CLIENT_ID"] as? String {
//            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
//        }
//    }
    
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate


    var body: some Scene {
        WindowGroup {
            AppCoordinator()
//                .onOpenURL { url in
//                    GIDSignIn.sharedInstance.handle(url)
//                }
        }
    }
}
