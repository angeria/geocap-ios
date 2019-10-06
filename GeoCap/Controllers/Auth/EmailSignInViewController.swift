//
//  EmailSignInViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-10-03.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation

import UIKit
import Firebase
import os.log

class EmailSignInViewController: UIViewController {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        emailTextField.becomeFirstResponder()
    }
    
    // MARK: - Email
    
    @IBOutlet weak var emailTextField: UITextField! {
        didSet {
            emailTextField.delegate = self
        }
    }
    
    @IBOutlet weak var emailLabel: UILabel!
    
    private func checkIfEmailIsValidAndExists() {
        Auth.auth().fetchSignInMethods(forEmail: emailTextField.text!) { [weak self] signInMethods, error in
            if let error = error as NSError? {
                self?.handleError(error)
                return
            }
            
            self?.emailLabel.isHidden = true
            self?.emailTextField.isEnabled = false
            self?.passwordTextField.isHidden = false
            self?.passwordTextField.becomeFirstResponder()
            
            if signInMethods != nil, signInMethods!.contains("password") {
                self?.passwordTextField.returnKeyType = .done
            } else {
                self?.usernameTextField.isHidden = false
            }
        }
    }
    
    // MARK: - Password
    
    @IBOutlet weak var passwordTextField: UITextField! {
        didSet {
            passwordTextField.delegate = self
        }
    }
    
    @IBOutlet weak var passwordLabel: UILabel!
    
    private func passwordTextFieldDidEndEditing() {
        if usernameTextField.isHidden {
            signIn()
        } else {
            usernameTextField.becomeFirstResponder()
        }
    }
    
    // MARK: - Username
    
    @IBOutlet weak var usernameTextField: UITextField! {
        didSet {
            usernameTextField.delegate = self
        }
    }
    
    @IBOutlet weak var usernameLabel: UILabel!
    
    private func usernameTextFieldDidEndEditing() {
        let username = usernameTextField.text!
        if username.count < 2 || username.count > 24 {
            usernameLabel.isHidden = false
            usernameLabel.text = "Username must be between 2 to 24 characters"
            return
        }
        
        usernameLabel.isHidden = true
        
        createUser()
    }
    
    // MARK: - Sign-in and user creation
    
    private func signIn() {
        Auth.auth().signIn(withEmail: emailTextField.text!, password: passwordTextField.text!) { [weak self] user, error in
            if let error = error as NSError? {
                self?.handleError(error)
                return
            }
            
            self?.passwordLabel.isHidden = true
            self?.passwordTextField.resignFirstResponder()
            self?.navigationController?.popToRootViewController(animated: true)
        }
    }
    
    private func createUser() {
        Auth.auth().createUser(withEmail: emailTextField.text!, password: passwordTextField.text!) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error as NSError? {
                self.handleError(error)
                return
            }
            
            self.usernameTextField.resignFirstResponder()
            
            let changeRequest = authResult!.user.createProfileChangeRequest()
            changeRequest.displayName = self.usernameTextField.text!
            changeRequest.commitChanges { error in
                if let error = error as NSError? {
                    os_log("%{public}@", log: OSLog.Auth, type: .error, error)
                    Crashlytics.sharedInstance().recordError(error)
                    return
                }

                self.writeUserToDb(uid: authResult!.user.uid)
            }
        }
    }
    
    private func writeUserToDb(uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).setData([
            "username": usernameTextField.text!,
            "capturedLocations": [],
            "capturedLocationsCount": 0
        ]) { [weak self] error in
            if let error = error as NSError? {
                os_log("%{public}@", log: OSLog.Auth, type: .error, error)
                Crashlytics.sharedInstance().recordError(error)
                return
            }

            db.collection("users").document(uid).collection("private").document("data").setData([
                "latestEventId": ""
            ]) { [weak self] error in
                if let error = error as NSError? {
                    os_log("%{public}@", log: OSLog.Auth, type: .error, error)
                    Crashlytics.sharedInstance().recordError(error)
                    return
                }
                
                self?.navigationController?.popToRootViewController(animated: true)
            }
        }
    }
    
    // MARK: - Error handling
    
    private func handleError(_ error: NSError) {
        if let errorCode = AuthErrorCode(rawValue: error.code) {
            switch errorCode {
            case .wrongPassword:
                passwordLabel.isHidden = false
                passwordLabel.text = "Wrong password"
            case .weakPassword:
                passwordLabel.isHidden = false
                passwordLabel.text = "Password must be at least six characters"
            case .invalidEmail:
                emailLabel.isHidden = false
                emailLabel.text = "Invalid email"
            default:
                // TODO: Log / extend
                break
            }
        }
    }
    
}

extension EmailSignInViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard textField.text != nil else { return false }
        textField.text = textField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch textField {
        case emailTextField:
            checkIfEmailIsValidAndExists()
        case passwordTextField:
            passwordTextFieldDidEndEditing()
        case usernameTextField:
            usernameTextFieldDidEndEditing()
        default:
            fatalError("Unexpected text field")
        }
        
        return true
    }
    
}
