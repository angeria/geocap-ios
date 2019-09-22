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
import os.log

class AuthViewController: UIViewController {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if Auth.auth().currentUser == nil {
            present(authUI.authViewController(), animated: true)
        }
    }
    
    lazy var authUI: FUIAuth = {
        let authUI = FUIAuth.defaultAuthUI()!
        authUI.delegate = self
        authUI.shouldHideCancelButton = true
        authUI.providers = [FUIFacebookAuth(), FUIGoogleAuth(), FUIEmailAuth()]
        return authUI
    }()
    
    private func storeNewUser(_ user: User) {
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).setData([
            "username": user.displayName!,
            "capturedLocations": [],
            "capturedLocationsCount": 0,
            "locationLostNotificationsEnabled": false
        ])
        { [weak self] error in
            if let error = error {
                fatalError(String(describing: error))
            } else {
                self?.performSegue(withIdentifier: "unwindSegueAuthToMap", sender: self)
            }
        }
    }

}

extension AuthViewController: FUIAuthDelegate {
    
    func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
        switch error {
        case .none:
            let user = authDataResult!.user
            
            Crashlytics.sharedInstance().setUserIdentifier(user.uid)
            
            guard user.displayName != nil, user.displayName != "" else {
                fatalError("'user.displayName' is nil or empty string")
            }
            
            Crashlytics.sharedInstance().setUserName(user.displayName)
            
            if authDataResult!.additionalUserInfo?.isNewUser == true {
                storeNewUser(user)
            } else {
                performSegue(withIdentifier: "unwindSegueAuthToMap", sender: self)
            }
        case .some(let error as NSError):
            os_log("%{public}@", log: OSLog.Auth, type: .error, error)
            Crashlytics.sharedInstance().recordError(error)
        }
    }

}
