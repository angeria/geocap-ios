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
            "uid": user.uid,
            // FIXME: Remove force unwrap
            "username": user.displayName!,
            "capturedLocations": [],
            "capturedLocationsCount": 0,
            "latestEventId": "",
            "notificationToken": "",
            "locationLostNotificationsEnabled": false
        ]) { [weak self] error in
            if let error = error {
                print("Error adding user: \(error)")
                self?.presentLoginErrorAlert()
            } else {
                self?.performSegue(withIdentifier: "unwindSegueAuthToMap", sender: self)
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
}

extension AuthViewController: FUIAuthDelegate {
    
    func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
        switch error {
        case .none:
            guard let user = authDataResult?.user else { presentLoginErrorAlert(); return }
            guard user.displayName != nil, user.displayName != "" else {
                print("Login error: 'user.displayName' is nil or an empty string")
                presentLoginErrorAlert()
                return
            }
            
            if authDataResult?.additionalUserInfo?.isNewUser == true {
                storeNewUser(user)
            } else {
                performSegue(withIdentifier: "unwindSegueAuthToMap", sender: self)
            }
        case .some(let error):
            handleSignInError(error)
        }
    }

}
