//
//  AppDelegate.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-07-19.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
//import FirebaseAuth
import SCSDKLoginKit
import os.log
import CoreLocation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        FirebaseApp.configure()

        if CommandLine.arguments.contains("--uitesting") {
            configureAppForTesting()
        }

        // Launched from push notification
        if let options = launchOptions,
            let userInfo = options[UIApplication.LaunchOptionsKey.remoteNotification] as? [AnyHashable: Any] {
                handleRemoteNotification(userInfo: userInfo)
        }

        return true
    }

    private func configureAppForTesting() {
        try? Auth.auth().signOut()

        let defaultsName = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: defaultsName)

        UIView.setAnimationsEnabled(false)
    }

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let link = userActivity.webpageURL?.absoluteString {
            return handleEmailLinkSignIn(withLink: link)
        }
        return false
    }

    func handleEmailLinkSignIn(withLink link: String) -> Bool {
        if Auth.auth().isSignIn(withEmailLink: link) {
            if let navVC = window?.rootViewController as? UINavigationController,
                let authVC = navVC.viewControllers[0] as? AuthViewController {
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
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return SCSDKLoginClient.application(app, open: url, options: options)
    }

    // MARK: Notifications

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions)
        -> Void) {
        // Show notification banners when app is in foreground
        completionHandler([.alert])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        guard response.notification.request.content.categoryIdentifier == "location_lost" else { return }

        let userInfo = response.notification.request.content.userInfo
        handleRemoteNotification(userInfo: userInfo)

        completionHandler()
    }

    private func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        guard let aps = userInfo["aps"] as? [AnyHashable: Any] else { return }

        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            if let navVC = self?.window?.rootViewController as? UINavigationController {
                if let tabBarVC = navVC.visibleViewController as? UITabBarController {
                    tabBarVC.view.isUserInteractionEnabled = false
                    if let mapNavVC = tabBarVC.viewControllers?[1] as? UINavigationController {
                        if let mapVC = mapNavVC.visibleViewController as? MapViewController {
                            guard let locationName = aps["locationName"] as? String,
                                let locationId = aps["locationId"] as? String,
                                let type = aps["type"] as? String,
                                let country = aps["country"] as? String,
                                let county = aps["county"] as? String,
                                let city = aps["city"] as? String
                                else { return }

                            guard let coordinatesArray = aps["coordinates"] as? [AnyHashable: Any],
                                let lat = coordinatesArray["_latitude"] as? CLLocationDegrees,
                                let lng = coordinatesArray["_longitude"] as? CLLocationDegrees else { return }
                            let coordinates = CLLocationCoordinate2D(latitude: lat,
                                                                     longitude: lng)

                            mapVC.defendLocation(locationName: locationName, locationId: locationId,
                                                 coordinates: coordinates, country: country, county: county,
                                                 city: city, type: type)
                        }
                    }
                }
            }
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

}
