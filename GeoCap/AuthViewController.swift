//
//  AuthViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-07-20.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
import FirebaseUI

class AuthViewController: UIViewController, FUIAuthDelegate {
    
    private lazy var db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if loginSuccessful {
            performSegue(withIdentifier: "Show Map", sender: nil)
        } else {
            let authViewController = authUI.authViewController()
            present(authViewController, animated: false)
        }
        
    }

    // MARK: - AuthUI
    
    lazy var authUI: FUIAuth = {
        let authUI = FUIAuth.defaultAuthUI()!
        authUI.delegate = self
        authUI.providers = [FUIAnonymousAuth(), FUIEmailAuth()]
        return authUI
    }()
    
    private var loginSuccessful = false
    
    func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
        if let authDataResult = authDataResult, error == nil {
            loginSuccessful = true
            
            let user = authDataResult.user
            
            db.collection("users").document(user.uid).setData([
                "name": user.displayName!,
            ]) { err in
                if let err = err {
                    print("Error adding document: \(err)")
                } else {
                    print("Document added with ID: \(user.uid)")
                }
            }
        }
        
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }

}
