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

    var authListener: AuthStateDidChangeListenerHandle?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        authListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            if let _ = user {
                self?.performSegue(withIdentifier: "Show Map", sender: nil)
            } else {
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
    
    // MARK: - Authorization
    
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
                saveUser(user)
            }
        case .some(let error):
            handleSignInError(error)
        }
    }
    
    private func handleSignInError(_ error: Error) {
        let error = error as NSError
        let errorCode = FUIAuthErrorCode(rawValue: UInt(error.code))
        
        // TODO: Handle errors
        switch errorCode {
        case .some where errorCode == .userCancelledSignIn:
            print("User cancelled sign-in")
        case .some where errorCode == .providerError:
            print("Login error from provider: \(error.userInfo[FUIAuthErrorUserInfoProviderIDKey]!)")
            fallthrough
        default:
            print("Login error description: \(error.localizedDescription)")
            if error.userInfo[NSUnderlyingErrorKey] != nil {
                print("Underlying login error: \(error.userInfo[NSUnderlyingErrorKey]!)")
            }
        }
    }
    
    private func saveUser(_ user: User) {
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
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }

}
