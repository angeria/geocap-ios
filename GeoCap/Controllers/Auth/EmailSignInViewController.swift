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
    
    @IBOutlet weak var emailTextField: UITextField! {
        didSet {
            emailTextField.delegate = self
            emailTextField.leftViewMode = .always
            let profileImage = UIImage(named: "tab-bar-profile")!
            emailTextField.leftView = UIImageView(image: profileImage)
        }
    }
    
    @IBOutlet weak var passwordTextField: UITextField! {
        didSet {
            passwordTextField.delegate = self
        }
    }
    
    @IBOutlet weak var usernameTextField: UITextField! {
        didSet {
            usernameTextField.delegate = self
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        emailTextField.becomeFirstResponder()
    }
    
    private func emailTextFieldDidEndEditing(_ textField: UITextField) {
        guard let email = textField.text else { return }
        
        Auth.auth().fetchSignInMethods(forEmail: email) { [weak self] signInMethods, error in
//            if let error = error as NSError? {
//                if let errCode = AuthErrorCode(rawValue: error.code) {
//                    if errCode == .invalidEmail {
//                        print("Invalid email format")
//                    }
//                }
//
//                os_log("%{public}@", log: OSLog.Auth, type: .debug, error)
//                return
//            }

            self?.passwordTextField.isHidden = false
            if signInMethods == nil {
                self?.usernameTextField.isHidden = false
            }
        }
    }
    
    private func passwordTextFieldDidEndEditing(_ textField: UITextField) {
        if usernameTextField.isHidden {
            signIn(withEmail: emailTextField.text!, password: textField.text!)
        }
    }
    
    private func usernameTextFieldDidEndEditing(_ textField: UITextField) {
        createUser(withEmail: emailTextField.text!, password: passwordTextField.text!, username: textField.text!)
    }
    
    private func signIn(withEmail email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] user, error in
            guard error == nil else { return }
            
            self?.performSegue(withIdentifier: "Show Map", sender: nil)
        }
    }
    
    private func createUser(withEmail email: String, password: String, username: String) {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            let changeRequest = authResult?.user.createProfileChangeRequest()
            changeRequest?.displayName = username
            changeRequest?.commitChanges { (error) in
                print("Username set to \(username)")
              // TODO: Implement
            }
        }
    }
    
}

extension EmailSignInViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        textField.text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch textField {
        case emailTextField:
            if textField.isEmail() {
                return true
            } else {
                textField.shake()
                return false
            }
        case passwordTextField:
            return true
        case usernameTextField:
            return true
        default:
            fatalError("Unexpected text field")
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        switch textField {
        case emailTextField:
            emailTextField.isEnabled = false
            emailTextFieldDidEndEditing(textField)
        case passwordTextField:
            passwordTextFieldDidEndEditing(textField)
        case usernameTextField:
            usernameTextFieldDidEndEditing(textField)
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
