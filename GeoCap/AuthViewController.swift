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

// TODO: Customize sign up screen

class AuthViewController: UIViewController {

    private var authListener: AuthStateDidChangeListenerHandle?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Sometimes the closure fires two times in a row  when a user is signed in
        // First time with user as nil and second time with a user object
        // To prevent segues colliding, currentUser is checked again synchronously
        authListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            if user != nil {
                self?.performSegue(withIdentifier: "Show Map", sender: user)
            } else if auth.currentUser == nil {
                if let authViewController = self?.authUI.authViewController() {
                    self!.present(authViewController, animated: true)
                }
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if authListener != nil {
            Auth.auth().removeStateDidChangeListener(authListener!)
        }
    }
    
    lazy var authUI: FUIAuth = {
        let authUI = FUIAuth.defaultAuthUI()!
        authUI.delegate = self
        authUI.shouldHideCancelButton = true
        authUI.providers = [FUIEmailAuth()]
        return authUI
    }()
    
    // TODO: Make display name mandatory
    private func storeNewUser(_ user: User) {
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).setData([
            "username": user.displayName!,
        ]) { error in
            if let error = error {
                print("Error adding user: \(error)")
            } else {
                print("User added with ID: \(user.uid)")
            }
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let mapVC = segue.destination.contents as? MapViewController {
            if let user = sender as? User {
                mapVC.user = user
            }
        }
    }
    
}

extension AuthViewController: FUIAuthDelegate {
    
    func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
        switch error {
        case .none:
            if let user = authDataResult?.user, authDataResult?.additionalUserInfo?.isNewUser == true {
                storeNewUser(user)
            }
        case .some(let error):
            handleSignInError(error)
        }
    }
    
}
