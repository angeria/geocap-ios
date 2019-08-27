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

    @IBAction func signOutPressed(_ sender: UIButton) {
        let db = Firestore.firestore()
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Unregister for notifications
        db.collection("users").document(userId).updateData(["notificationToken": ""]) { [weak self] error in
            if let error = error {
                print("Error removing notification token from user: \(error)")
            } else {
                UserDefaults.standard.set("", forKey: "notificationToken")
                
                do {
                    try Auth.auth().signOut()
                    self?.performSegue(withIdentifier: "Show Auth", sender: nil)
                }
                catch let error as NSError {
                    if let message = error.userInfo[NSLocalizedFailureReasonErrorKey] {
                        print("Error signing out: \(message)")
                    }
                }
            }
        }
    }

}
