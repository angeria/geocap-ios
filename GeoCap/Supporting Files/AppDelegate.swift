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
import SCSDKLoginKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        FirebaseApp.configure()
        
        if CommandLine.arguments.contains("--uitesting") {
            configureAppForTesting()
        }
        
        return true
    }
    
    private func configureAppForTesting() {
        try? Auth.auth().signOut()
        
        let defaultsName = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: defaultsName)
        
        UIView.setAnimationsEnabled(false)
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let link = userActivity.webpageURL?.absoluteString {
            return handleEmailLinkSignIn(withLink: link)
        }
        return false
    }
    
    func handleEmailLinkSignIn(withLink link: String) -> Bool {
        if Auth.auth().isSignIn(withEmailLink: link) {
            if let navVC = window?.rootViewController as? UINavigationController, let authVC = navVC.viewControllers[0] as? AuthViewController {
                authVC.prepareViewForSignIn()
                if navVC.visibleViewController is AuthViewController {
                    authVC.signInWithLink(link)
                } else {
                    navVC.popToRootViewController(animated: true)
                    authVC.signInWithLink(link)
                }
                return true
            }
        }
        return false
    }
    
    // Snap Kit integration
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return SCSDKLoginClient.application(app, open: url, options: options)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification banners when app is in foreground
        completionHandler([.alert])
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

}

