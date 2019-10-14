//
//  AppDelegate.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-07-19.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
import FirebaseAuth

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        FirebaseApp.configure()
        return true
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let link = userActivity.webpageURL?.absoluteString {
            return handleEmailLinkSignIn(withLink: link)
        }
        return false
    }
    
    func handleEmailLinkSignIn(withLink link: String) -> Bool {
        if Auth.auth().isSignIn(withEmailLink: link) {
            if let authVC = window?.rootViewController as? AuthViewController {
                authVC.prepareViewForSignIn()
                if authVC.presentedViewController == nil {
                    authVC.signInWithLink(link)
                } else {
                    authVC.dismiss(animated: true) {
                        authVC.signInWithLink(link)
                    }
                }
                return true
            }
        }
        return false
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification banners when app is in foreground
        completionHandler([.alert])
    }

}

