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
    
    private lazy var db = Firestore.firestore()
    private lazy var user = Auth.auth().currentUser
    
    // MARK: - Sign out
    
    @IBOutlet weak var signOutButton: UIButton! {
        didSet {
            signOutButton.layer.cornerRadius = 10
        }
    }
    
    @IBAction func signOutPressed(_ sender: UIButton) {
        guard let uid = user?.uid else { return }
        
        UserDefaults.standard.set("", forKey: "notificationToken")
        
        // Unregister for notifications
        db.collection("users").document(uid).updateData(["notificationToken": ""]) { error in
            if let error = error {
                print("Error removing notification token from user: \(error)")
            }
        }
        
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
    
    @IBOutlet weak var notificationsSwitch: UISwitch! {
        didSet {
            guard let uid = user?.uid else { return }
            
            db.collection("users").document(uid).getDocument() { [weak self] (document, error) in
                if let error = error {
                    print("Error fetching user notification settings: ", error)
                } else if let document = document {
                    if document.get("locationCapturedPushNotificationsEnabled") as? Bool == true {
                        self?.notificationsSwitch.isOn = true
                    }
                }
            }
        }
    }
    
    private func setNotificationSettings(to isEnabled: Bool) {
        guard let uid = user?.uid else { return }
        
        notificationsSwitch.isOn = isEnabled
        
        db.collection("users").document(uid).updateData(["locationCapturedPushNotificationsEnabled": isEnabled]) { error in
            if let error = error {
                print("Error setting location captured push notification setting: \(error)")
            }
        }
    }
    
    @IBAction func notificationsSwitchPressed(_ sender: UISwitch) {
        switch sender.isOn {
        case true:
            setNotificationSettings(to: true)
        case false:
            setNotificationSettings(to: false)
        }
    }

}
