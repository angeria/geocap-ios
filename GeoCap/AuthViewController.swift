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

class AuthViewController: UIViewController {

    private var authListener: AuthStateDidChangeListenerHandle?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Sometimes the closure fires two times in a row  when a user is signed in
        // First time with user as nil and second time with a user object
        // To prevent segues colliding, currentUser is checked again synchronously
        authListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            if let user = user {
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
        authUI.providers = [FUIFacebookAuth(), FUIGoogleAuth(), FUIEmailAuth()]
        return authUI
    }()
    
    private func storeNewUser(_ user: User) {
        let db = Firestore.firestore()
        
        guard let username = user.displayName else {
            print("Login error: user.diplayName == nil")
            presentLoginErrorAlert()
            return
        }
        
        db.collection("users").document(user.uid).setData([
            "uid": user.uid,
            "username": username,
            "capturedLocations": [],
            "capturedLocationsCount": 0,
            "latestEventId": ""
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
        let title = NSLocalizedString("alert-action-title-sign-in-failed", comment: "Title of alert when sign-in failed")
        let message = NSLocalizedString("alert-action-message-sign-in-failed", comment: "Message of alert when sign-in failed")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okActionTitle = NSLocalizedString("alert-action-title-OK", comment: "Title of alert action OK")
        let okAction = UIAlertAction(title: okActionTitle, style: .default) { [weak self] action in
            self?.present(self!.authUI.authViewController(), animated: true)
        }
        alert.addAction(okAction)
        present(alert, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let tabVC = segue.destination as? UITabBarController {
            let mapIndex = 1
            tabVC.selectedIndex = mapIndex
            if let navVC = tabVC.viewControllers?[mapIndex] as? UINavigationController {
                if let mapVC = navVC.visibleViewController as? MapViewController {
                    if let user = sender as? User {
                        mapVC.user = user
                    }
                }
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
