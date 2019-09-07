//
//  ProfileViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-16.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase

class ProfileViewController: UIViewController {
    
    private lazy var user = Auth.auth().currentUser
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupLocationLostPushNotificationsSwitch()
    }
    
    private func setupLocationLostPushNotificationsSwitch() {
        guard let uid = user?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument() { [weak self] (document, error) in
            if let error = error {
                print("Error fetching 'locationLostPushNotificationsEnabled' setting: ", error)
            } else if let document = document {
                self?.locationLostPushNotificationsSwitch.isOn = document.get("locationLostPushNotificationsEnabled") as? Bool == true ? true : false
            }
        }
    }
    
    // MARK: - Sign out
    
    @IBOutlet weak var signOutButton: UIButton! {
        didSet {
            signOutButton.layer.cornerRadius = 10
        }
    }
    
    @IBAction func signOutPressed(_ sender: UIButton) {
        guard let uid = user?.uid else { return }
        
        // Unregister for notifications
        let db = Firestore.firestore()
        db.collection("users").document(uid).updateData(["notificationToken": NSNull()]) { [weak self] error in
            if let error = error {
                print("Error removing notification token from user: \(error)")
            }
            self?.signOut()
        }
    }
    
    private func signOut() {
        do {
            try Auth.auth().signOut()
        }
        catch let error as NSError {
            if let message = error.userInfo[NSLocalizedFailureReasonErrorKey] {
                print("Error signing out: \(message)")
            }
        }
    }
    
    // MARK: - Notifications
    
    @IBOutlet weak var locationLostPushNotificationsSwitch: UISwitch!
    
    private func setLocationLostPushNotificationsSetting(to isEnabled: Bool) {
        guard let uid = user?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(uid).updateData(["locationLostPushNotificationsEnabled": isEnabled]) { error in
            if let error = error {
                print("Error setting 'locationLostPushNotificationsEnabled' setting: ", error)
            }
        }
    }
    
    @IBAction func notificationsSwitchPressed(_ sender: UISwitch) {
        switch sender.isOn {
        case true:
            UNUserNotificationCenter.current().getNotificationSettings() { [weak self] settings in
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self?.setLocationLostPushNotificationsSetting(to: true)
                case .denied:
                    DispatchQueue.main.async {
                        self?.locationLostPushNotificationsSwitch.isOn = false
                        self?.presentNotificationAuthDisabledAlert()
                    }
                case .notDetermined:
                    DispatchQueue.main.async {
                        self?.presentNotificationAuthRequest()
                    }
                @unknown default:
                    fatalError("Unexpected notification authorization status")
                }
            }
        case false:
            setLocationLostPushNotificationsSetting(to: false)
        }
    }

    private func presentNotificationAuthRequest() {
        guard let uid = user?.uid else { return }
        
        let authOptions: UNAuthorizationOptions = [.alert, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { [weak self] (granted, error) in
            if let error = error {
                print("Error requesting notifications auth: ", error)
                return
            } else if granted {
                self?.setLocationLostPushNotificationsSetting(to: true)
                
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
                let db = Firestore.firestore()
                db.collection("users").document(uid).updateData(["locationLostPushNotificationsEnabled": true]) { error in
                    if let error = error {
                        print("Error setting 'locationLostPushNotificationsEnabled' setting to enabled: ", error)
                    }
                }
            } else {
                self?.locationLostPushNotificationsSwitch.isOn = false
            }
            UserDefaults.standard.set(true, forKey: "notificationAuthRequestShown")
        }
    }
    
    private func presentNotificationAuthDisabledAlert() {
        let title = NSLocalizedString("alert-title-notification-auth-off", comment: "Alert title when notification auth is off")
        let message = NSLocalizedString("alert-message-notification-auth-off", comment: "Alert message when notification auth is off")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okActionTitle = NSLocalizedString("alert-action-title-OK", comment: "Title of alert action OK")
        let okAction = UIAlertAction(title: okActionTitle, style: .default)
        let settingsActionTitle = NSLocalizedString("alert-action-title-settings", comment: "Title of alert action for going to 'Settings'")
        let settingsAction = UIAlertAction(title: settingsActionTitle, style: .default, handler: {action in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        })
        alert.addAction(settingsAction)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
}
