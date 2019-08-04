//
//  FUICustomPasswordSignUpViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-04.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import FirebaseUI

class CustomPasswordSignUpViewController: FUIPasswordSignUpViewController, UITextFieldDelegate {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var displayNameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var nextButton: UIBarButtonItem!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?, authUI: FUIAuth, email: String?, requireDisplayName: Bool) {
        super.init(nibName: nibNameOrNil,
                   bundle: nibBundleOrNil,
                   authUI: authUI,
                   email: email,
                   requireDisplayName: requireDisplayName)
        
        emailTextField.text = email
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //override action of default 'Next' button to use custom layout elements'
        self.navigationItem.rightBarButtonItem?.target = self
        self.navigationItem.rightBarButtonItem?.action = #selector(onNext(_:))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //update state of all UI elements (e g disable 'Next' buttons)
        self.updateTextFieldValue(nil)
    }
    
    @IBAction func onNext(_ sender: AnyObject?) {
        if let email = emailTextField.text,
            let password = passwordTextField.text,
            let username = displayNameTextField.text {
            self.signUp(withEmail: email, andPassword: password, andUsername: username)
        }
    }
    
    @IBAction func onCancel(_ sender: AnyObject) {
        self.cancelAuthorization()
    }
    
    @IBAction func onBack(_ sender: AnyObject) {
        self.onBack()
    }
    @IBAction func onViewSelected(_ sender: AnyObject) {
        emailTextField.resignFirstResponder()
        passwordTextField.resignFirstResponder()
        displayNameTextField.resignFirstResponder()
    }
    
    // MARK: - UITextFieldDelegate methods
    @IBAction func updateTextFieldValue(_ sender: AnyObject?) {
        if let email = emailTextField.text,
            let password = passwordTextField.text,
            let username = displayNameTextField.text {
            
            nextButton.isEnabled = !email.isEmpty && !password.isEmpty && !username.isEmpty
            self.didChangeEmail(email, orPassword: password, orUserName: username)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailTextField {
            displayNameTextField.becomeFirstResponder()
        } else if textField == displayNameTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            self.onNext(nil)
        }
        
        return false
    }
    
}
