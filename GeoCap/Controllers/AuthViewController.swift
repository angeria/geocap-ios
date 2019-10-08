//
//  AuthViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-10-03.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation
import UIKit
import os.log
import Firebase

class AuthViewController: UIViewController {
    
    @IBOutlet weak var appIcon: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Close keyboard when tapping outside of it
        view.addGestureRecognizer(UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:))))
        
        NotificationCenter.default.addObserver(self, selector: #selector(AuthViewController.keyboardDidChange), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

//        try? Auth.auth().signOut()
//        UserDefaults.standard.set(nil, forKey: "Link")
        
        if Auth.auth().currentUser != nil {
            performSegue(withIdentifier: "Show Map", sender: nil)
        }
        
    }
    
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    @objc func keyboardDidChange(notification: Notification) {
        let userInfo = notification.userInfo! as [AnyHashable: Any]
        let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as! NSNumber
        let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as! NSNumber
        
        // Prevents iPad undocked keyboard
        if endFrame.height != 0, view.frame.height == endFrame.height + endFrame.origin.y {
            bottomConstraint.constant = view.frame.height - endFrame.origin.y
        } else {
            bottomConstraint.constant = 20
        }
        
        UIView.setAnimationCurve(UIView.AnimationCurve(rawValue: animationCurve.intValue)!)
        UIView.animate(withDuration: animationDuration.doubleValue) {
            self.view.layoutIfNeeded()
            // Do additional tasks such as scrolling in a UICollectionView
        }
    }
    
    @IBOutlet weak var emailTextField: UITextField! {
        didSet {
            emailTextField.delegate = self
            
            if let email = UserDefaults.standard.string(forKey: "Email") {
                emailTextField.text = email
            }
        }
    }
    
    @IBOutlet weak var continueButton: UIButton! {
        didSet {
            continueButton.layer.cornerRadius = GeoCapConstants.defaultCornerRadius
        }
    }
    
    @IBAction func continueButtonPressed(_ sender: UIButton) {
        let _ = emailTextFieldDidEndEditing()
    }
        
    private func emailTextFieldDidEndEditing() -> Bool {
        guard emailTextField.text != nil else { return false }
        emailTextField.resignFirstResponder()
        emailTextField.text = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        presentConfirmEmailAlert()
        return true
    }
    
    private func presentConfirmEmailAlert() {
        let title = "Confirm Email"
        let message = "Is this your email?\n\(emailTextField.text!)"
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let noAction = UIAlertAction(title: "No", style: .cancel, handler: nil)
        let yesAction = UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
            self?.sendSignInLink()
        }
        alert.addAction(noAction)
        alert.addAction(yesAction)
        present(alert, animated: true)
    }

    private func sendSignInLink() {
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.url = URL(string: "https://geocap-backend.firebaseapp.com")
        actionCodeSettings.handleCodeInApp = true

        let email = emailTextField.text!
        Auth.auth().sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings) { [weak self] error in
            if let error = error as NSError? {
                // TODO: Show error to user
                os_log("%{public}@", log: OSLog.Auth, type: .debug, error)
                return
            }

            UserDefaults.standard.set(email, forKey: "Email")
            // TODO: check your email for link (show to user)
            self?.performSegue(withIdentifier: "Show Pending Sign In", sender: nil)
            print("Email sent")
        }
    }
    
    func signInWithLink(_ link: String) {
        if let email = UserDefaults.standard.string(forKey: "Email") {
            Auth.auth().signIn(withEmail: email, link: link) { [weak self] authResult, error in
                UserDefaults.standard.set(nil, forKey: "Link")
                self?.performSegue(withIdentifier: "Show Map", sender: nil)
            }
        }
    }
}

extension AuthViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return emailTextFieldDidEndEditing()
    }
    
}
