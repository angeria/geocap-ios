//
//  ProfileViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-16.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
import FirebaseAuth
import os.log
import SCSDKLoginKit
import SCSDKBitmojiKit

class ProfileViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSnapchatLoginButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupLocationLostNotificationsSwitch()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        settingsListener?.remove()
    }
    
    // MARK: - Sign out
    
    @IBOutlet weak var signOutButton: UIButton! {
        didSet {
            signOutButton.layer.cornerRadius = GeoCapConstants.defaultCornerRadius
        }
    }
    
    @IBAction func signOutPressed(_ sender: UIButton) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Unregister for notifications
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid).collection("private").document("data")
        ref.updateData(["notificationToken": FieldValue.delete()]) { [weak self] error in
            if let error = error {
                os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                Crashlytics.sharedInstance().recordError(error)
                return
            }
            self?.signOut()
        }
    }
    
    private func signOut() {
        do {
            // Removing listeners here also to not get "Missing or insufficient permissions" error after signing out
            let navVC = tabBarController!.viewControllers![1] as! UINavigationController
            let mapVC = navVC.viewControllers[0] as! MapViewController
            mapVC.teardown()
            
            settingsListener?.remove()
            
            try Auth.auth().signOut()
        }
        catch let error as NSError {
            os_log("%{public}@", log: OSLog.Profile, type: .debug, error)
            Crashlytics.sharedInstance().recordError(error)
        }
    }
    
    // MARK: - Notifications
    
    @IBOutlet weak var locationLostNotificationsSwitch: UISwitch!
    
    // Using a listener to use offline caching which gives a more responsive feeling compared to normal requests
    // I'm uncertain if this causes undue performance and/or network impact; keeping it for now
    private var settingsListener: ListenerRegistration?
    private func setupLocationLostNotificationsSwitch() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid).collection("private").document("data")
        settingsListener = ref.addSnapshotListener { [weak self] documentSnapshot, error in
                guard let document = documentSnapshot else {
                    os_log("%{public}@", log: OSLog.Profile, type: .debug, error! as NSError)
                    Crashlytics.sharedInstance().recordError(error!)
                    return
                }
            
                DispatchQueue.main.async {
                    self?.locationLostNotificationsSwitch.isOn = document.get("locationLostNotificationsEnabled") as? Bool == true ? true : false
                }
        }
    }
    
    @IBAction func notificationsSwitchPressed(_ sender: UISwitch) {
        switch sender.isOn {
        case true:
            UNUserNotificationCenter.current().getNotificationSettings() { [weak self] settings in
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self?.setLocationLostNotificationsSetting(to: true)
                case .denied:
                    DispatchQueue.main.async {
                        self?.locationLostNotificationsSwitch.isOn = false
                        self?.presentNotificationAuthDisabledAlert()
                    }
                case .notDetermined:
                    self?.presentNotificationAuthRequest()
                @unknown default:
                    fatalError("Unexpected notification authorization status")
                }
            }
        case false:
            setLocationLostNotificationsSetting(to: false)
        }
    }
    
    private func setLocationLostNotificationsSetting(to isEnabled: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid).collection("private").document("data")
        ref.updateData(["locationLostNotificationsEnabled": isEnabled]) { error in
            if let error = error {
                os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                Crashlytics.sharedInstance().recordError(error)
            }
        }
    }

    private func presentNotificationAuthRequest() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let authOptions: UNAuthorizationOptions = [.alert, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { [weak self] (granted, error) in
            if let error = error {
                os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                Crashlytics.sharedInstance().recordError(error)
                DispatchQueue.main.async {
                    self?.locationLostNotificationsSwitch.isOn = false
                }
                return
            } else if granted {
                self?.setLocationLostNotificationsSetting(to: true)
                
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                                
                let db = Firestore.firestore()
                let ref = db.collection("users").document(uid).collection("private").document("data")
                ref.updateData(["locationLostNotificationsEnabled": true]) { error in
                    if let error = error {
                        os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                        Crashlytics.sharedInstance().recordError(error)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.locationLostNotificationsSwitch.isOn = false
                }
            }
            UserDefaults.standard.set(true, forKey: GeoCapConstants.UserDefaultsKeys.notificationAuthRequestShown)
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
    
    // MARK: - Sound setting
    
    @IBOutlet weak var soundSettingSwitch: UISwitch! {
        didSet {
            soundSettingSwitch.isOn = UserDefaults.standard.bool(forKey: GeoCapConstants.UserDefaultsKeys.soundsAreEnabled)
        }
    }
    
    
    @IBAction func soundSettingSwitch(_ sender: UISwitch) {
        switch sender.isOn {
        case true:
            UserDefaults.standard.set(true, forKey: GeoCapConstants.UserDefaultsKeys.soundsAreEnabled)
        case false:
            UserDefaults.standard.set(false, forKey: GeoCapConstants.UserDefaultsKeys.soundsAreEnabled)
        }
    }
    
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let usernameVC = segue.destination as? ChooseUsernameViewController {
            usernameVC.isUsernameChange = true
        }
    }
    
    // MARK: - Snapchat
    
    private func setupSnapchatLoginButton() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if let loginButton = SCSDKLoginButton(completion: { (success, error) in
            if let error = error as NSError? {
                os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                return
            }
            
            SCSDKBitmojiClient.fetchAvatarURL { (avatarURL, error) in
                if let error = error as NSError? {
                    os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                    return
                }
                
                let url = URL(string: avatarURL!)!
                URLSession.shared.dataTask(with: url) { (bitmojiData, response, error) in
                    if let error = error as NSError? {
                        os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                        return
                    }
                    
                    
                    let ref = Storage.storage().reference(withPath: "snapchat_bitmojis/\(uid)/snapchat_bitmoji.png")
                    let metadata = StorageMetadata()
                    metadata.contentType = "image/png"
                    let _ = ref.putData(bitmojiData!, metadata: metadata) { (metadata, error) in
                        if let error = error as NSError? {
                            os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                            return
                        }
                        
                        print("Successfully uploaded bitmoji to storage")
                    }
                }.resume()
            }
        }) {
            loginButton.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(loginButton)
            NSLayoutConstraint.activate([
                loginButton.topAnchor.constraint(equalTo: signOutButton.bottomAnchor, constant: 40),
                loginButton.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
                loginButton.widthAnchor.constraint(equalToConstant: 230),
                loginButton.heightAnchor.constraint(equalToConstant: 60),
            ])
        }
    }

}
