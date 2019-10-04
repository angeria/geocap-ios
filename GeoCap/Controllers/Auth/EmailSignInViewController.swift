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
    
    private var emailExists = false
    
    private func checkIfEmailIsValidAndExists(_ textField: UITextField) {
        Auth.auth().fetchSignInMethods(forEmail: textField.text!) { [weak self] signInMethods, error in
            if let error = error as NSError?, let errorCode = AuthErrorCode(rawValue: error.code) {
                if errorCode == .invalidEmail {
                    os_log("%{public}@", log: OSLog.Auth, type: .debug, error)
                    return
                }
            }
            
            if signInMethods != nil, signInMethods!.contains("password") {
                self?.emailExists = true
                self?.passwordTextField.returnKeyType = .done
            }
        
            self?.passwordTextField.becomeFirstResponder()
        }
    }
    
    private func emailTextFieldDidEndEditing() {
        emailTextField.isEnabled = false
        passwordTextField.isHidden = false
        if !emailExists {
            usernameTextField.isHidden = false
        }
    }
    
    // MARK: - Password
    
    @IBOutlet weak var passwordTextField: UITextField! {
        didSet {
            passwordTextField.delegate = self
        }
    }
    
    @IBOutlet weak var passwordLabel: UILabel!
    
    private func passwordTextFieldDidEndEditing(_ textField: UITextField) {
        if usernameTextField.isHidden {
            signIn(withEmail: emailTextField.text!, password: textField.text!)
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
    
    private func usernameTextFieldDidEndEditing(_ username: String) {
        if username.count < 2 || username.count > 24 {
            usernameLabel.isHidden = false
            usernameLabel.text = "Username must be between 2 to 24 characters"
            return
        }
        
        createUser(withEmail: emailTextField.text!, password: passwordTextField.text!, username: username)
    }
    
    // MARK: - Sign-in
    
    private func signIn(withEmail email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] user, error in
            if let error = error as NSError? {
                self?.handleSignInError(error)
                return
            }
            
            self?.passwordTextField.resignFirstResponder()
            self?.navigationController?.popToRootViewController(animated: true)
            
            let storyBoard = UIStoryboard(name: "Main", bundle: nil)
            let mapVC = storyBoard.instantiateViewController(withIdentifier: "Map") as! UITabBarController
            self?.view.window?.rootViewController? = mapVC
        }
    }
    
    private func handleSignInError(_ error: NSError) {
        if let errorCode = AuthErrorCode(rawValue: error.code) {
            switch errorCode {
            case .wrongPassword:
                passwordLabel.isHidden = false
                passwordLabel.text = "Wrong password"
            default:
                // TODO: Log
                break
            }
        }
    }
    
    private func createUser(withEmail email: String, password: String, username: String) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            if let error = error as NSError? {
                self?.handleCreateUserError(error)
                return
            }
            self?.usernameTextField.resignFirstResponder()
            
            let changeRequest = authResult?.user.createProfileChangeRequest()
            changeRequest?.displayName = username
            changeRequest?.commitChanges { (error) in
                print("Username set to \(username)")
              // TODO: Implement
                
                self?.performSegue(withIdentifier: "Show Map", sender: nil)
            }
        }
    }
    
    private func handleCreateUserError(_ error: NSError) {
        if let errorCode = AuthErrorCode(rawValue: error.code) {
            switch errorCode {
            case .weakPassword:
                passwordLabel.isHidden = false
                passwordLabel.text = "Password must be at least six characters"
            default:
                // TODO: Log
                break
            }
        }
    }
    
}

extension EmailSignInViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard textField.text != nil else { return false }
        
        switch textField {
        case emailTextField:
            checkIfEmailIsValidAndExists(emailTextField)
            return true
        case passwordTextField:
            passwordTextFieldDidEndEditing(passwordTextField)
            return true
        case usernameTextField:
            usernameTextFieldDidEndEditing(usernameTextField.text!)
            return true
        default:
            fatalError("Unexpected text field")
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let text = textField.text else { return }
        
        switch textField {
        case emailTextField:
            emailTextFieldDidEndEditing()
        case passwordTextField:
            break
        case usernameTextField:
            break
        default:
            fatalError("Unexpected text field")
        }
    }
    
}

// MARK: - Email Validation

private let __firstpart = "[A-Z0-9a-z]([A-Z0-9a-z._%+-]{0,30}[A-Z0-9a-z])?"
private let __serverpart = "([A-Z0-9a-z]([A-Z0-9a-z-]{0,30}[A-Z0-9a-z])?\\.){1,5}"
private let __emailRegex = __firstpart + "@" + __serverpart + "[A-Za-z]{2,8}"
private let __emailPredicate = NSPredicate(format: "SELF MATCHES %@", __emailRegex)

private extension String {
    func isEmail() -> Bool {
        return __emailPredicate.evaluate(with: self)
    }
}

private extension UITextField {
    func isEmail() -> Bool {
        guard let text = self.text else { return false }
        return text.isEmail()
    }
}
