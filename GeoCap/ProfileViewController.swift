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
    
    @IBOutlet weak var signOutButton: UIButton! {
        didSet {
            signOutButton.layer.cornerRadius = 10
        }
    }
    
    @IBAction func signOutPressed(_ sender: UIButton) {
        let db = Firestore.firestore()
        
        // Unregister for notifications
        if let userId = Auth.auth().currentUser?.uid {
            db.collection("users").document(userId).updateData(["notificationToken": ""]) { error in
                if let error = error {
                    print("Error removing notification token from user: \(error)")
                }
                UserDefaults.standard.set("", forKey: "notificationToken")
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

}
