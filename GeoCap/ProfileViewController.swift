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
        
        do {
            try Auth.auth().signOut()
            performSegue(withIdentifier: "Show Auth", sender: nil)
        }
        catch let error as NSError {
            if let message = error.userInfo[NSLocalizedFailureReasonErrorKey] {
                print("Error signing out: \(message)")
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

}
