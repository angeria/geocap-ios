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

    // MARK: - Authorization
    
    lazy var authUI: FUIAuth = {
        let authUI = FUIAuth.defaultAuthUI()!
        authUI.delegate = self
        authUI.providers = [FUIEmailAuth()]
        return authUI
    }()
    
    private var loginSuccessful = false
    
    func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
        switch error {
        case .none:
            if let user = authDataResult?.user {
                saveUser(user)
            }
        case .some(let error):
            handleSignInError(error)
        }
    }
    
    private func handleSignInError(_ error: Error) {
        let error = error as NSError
        let errorCode = FUIAuthErrorCode(rawValue: UInt(error.code))
        
        // TODO: Show alerts
        switch errorCode {
        case .some where errorCode == .userCancelledSignIn:
            break
        case .some where errorCode == .providerError:
            print("Login error from provider: \(error.userInfo[FUIAuthErrorUserInfoProviderIDKey]!)")
        case errorCode where error.userInfo[NSUnderlyingErrorKey] != nil:
            print("Login error: \(error.userInfo[NSUnderlyingErrorKey]!)")
        default:
            print("Login error: \(error.localizedDescription)")
        }
    }
    
    private func saveUser(_ user: User) {
        let db = Firestore.firestore()
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
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }

}
