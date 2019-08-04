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

    var authListener: AuthStateDidChangeListenerHandle?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let authViewController = self.authUI.authViewController()
        self.present(authViewController, animated: true)
        
        // The closure might fire twice during initialization if an user is logged in
        // First time with user as nil and second time with a user
        // Thus the need for authListenerIsInitalized to prevent incorrect segueing
        authListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            
            print("fired")
            
            if user != nil {
                self.performSegue(withIdentifier: "Show Map", sender: nil)
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if authListener != nil {
            Auth.auth().removeStateDidChangeListener(authListener!)
        }
        
        try? authUI.signOut()
    }
    
    lazy var authUI: FUIAuth = {
        let authUI = FUIAuth.defaultAuthUI()!
        authUI.delegate = self
        authUI.providers = [FUIEmailAuth()]
        return authUI
    }()
    
    func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
        switch error {
        case .none:
            if let user = authDataResult?.user {
                storeUser(user)
            }
        case .some(let error):
            handleSignInError(error)
        }
    }
    
    private func handleSignInError(_ error: Error) {
        let error = error as NSError
        let errorCode = FUIAuthErrorCode(rawValue: UInt(error.code))
        
        switch errorCode {
        case .some where errorCode == .userCancelledSignIn:
            break
        case .some where errorCode == .providerError:
            print("Login error from provider: \(error.userInfo[FUIAuthErrorUserInfoProviderIDKey]!)")
            fallthrough
        default:
            print("Login error description: \(error.localizedDescription)")
            if error.userInfo[NSUnderlyingErrorKey] != nil {
                print("Underlying login error: \(error.userInfo[NSUnderlyingErrorKey]!)")
            }
            presentLoginErrorAlert()
        }
    }
    
    private func presentLoginErrorAlert() {
        let title = "Sign In Failed"
        let message = "Something went wrong when signing in, please try again"
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
    
    private func storeUser(_ user: User) {
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).setData([
            // TODO: Only unique names should be allowed. Maybe remove default to empty string?
            "name": user.displayName ?? "",
        ]) { err in
            // TODO: Handle errors
            if let err = err {
                print("Error adding document: \(err)")
            } else {
                print("Document added with ID: \(user.uid)")
            }
        }
    }
    
}
