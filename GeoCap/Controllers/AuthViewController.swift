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
    
    private var isStartup = true
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if Auth.auth().currentUser != nil {
            performSegue(withIdentifier: "Show Map", sender: nil)
        } else if isStartup {
            continueButton.isHidden = false
            isStartup = false
        }
    }
    
    private var bottomConstraintConstantInStoryboard: CGFloat?
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint! {
        didSet {
            if bottomConstraintConstantInStoryboard == nil {
                bottomConstraintConstantInStoryboard = bottomConstraint.constant
            }
        }
    }
    
    private var iconToTopConstraintConstantInStoryboard: CGFloat?
    @IBOutlet weak var iconToTopConstraint: NSLayoutConstraint! {
        didSet {
            if iconToTopConstraintConstantInStoryboard == nil {
                iconToTopConstraintConstantInStoryboard = iconToTopConstraint.constant
            }
        }
    }
    
    @IBOutlet weak var buttonToTextFieldConstraint: NSLayoutConstraint!
    
    @objc func keyboardDidChange(notification: Notification) {
        let userInfo = notification.userInfo! as [AnyHashable: Any]
        let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as! NSNumber
        let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as! NSNumber
        var hideEmailTextField = true
        var buttonTitle = "Continue with Your Email"
        
        // Prevents iPad undocked keyboard
        if endFrame.height != 0, view.frame.height == endFrame.height + endFrame.origin.y {
            hideEmailTextField = false
            buttonTitle = "Let's Go"
            bottomConstraint.constant = view.frame.height - endFrame.origin.y - view.safeAreaInsets.bottom + buttonToTextFieldConstraint.constant
            iconToTopConstraint.constant = (view.frame.height - endFrame.origin.y) / 6
        } else {
            infoLabel.isHidden = true
            hideEmailTextField = true
            buttonTitle = "Continue with Your Email"
            bottomConstraint.constant = bottomConstraintConstantInStoryboard!
            iconToTopConstraint.constant = iconToTopConstraintConstantInStoryboard!
        }
        
        UIView.setAnimationCurve(UIView.AnimationCurve(rawValue: animationCurve.intValue)!)
        UIView.animate(withDuration: animationDuration.doubleValue) {
            self.view.layoutIfNeeded()
            self.emailTextField.isHidden = hideEmailTextField
            self.continueButton.setTitle(buttonTitle, for: .normal)
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
        if emailTextField.isHidden {
            emailTextField.becomeFirstResponder()
        } else {
            let _ = emailTextFieldDidEndEditing()
        }
    }
        
    private func emailTextFieldDidEndEditing() -> Bool {
        guard emailTextField.text != nil, emailTextField.text != "" else { return false }
        emailTextField.text = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        emailTextField.resignFirstResponder()
        presentConfirmEmailAlert()
        return true
    }
    
    private func presentConfirmEmailAlert() {
        let title = "Confirm Email"
        let message = "Is this your email?\n\(emailTextField.text!)"
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let noAction = UIAlertAction(title: "No", style: .cancel, handler: nil)
        let yesAction = UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
            self?.checkIfEmailExists()
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
            self?.statusLabel.isHidden = true
            self?.spinner.stopAnimating()
            
            if let error = error as NSError? {
                // TODO: Show error to user
                os_log("%{public}@", log: OSLog.Auth, type: .debug, error)
                return
            }

            UserDefaults.standard.set(email, forKey: "Email")
            self?.performSegue(withIdentifier: "Show Pending Sign In", sender: nil)
        }
    }
    
    private func checkIfEmailExists() {
        statusLabel.isHidden = false
        statusLabel.text = "Thinking..."
        spinner.isHidden = false
        
        Auth.auth().fetchSignInMethods(forEmail: emailTextField.text!) { [weak self] signInMethods, error in
            if let error = error as NSError? {
                self?.handleError(error)
                return
            }
            self?.infoLabel.isHidden = true
            
            if signInMethods != nil, !signInMethods!.isEmpty {
                self?.sendSignInLink()
                return
            }
            
            self?.performSegue(withIdentifier: "Show Choose Username", sender: nil)
        }
    }
    
    @IBOutlet weak var infoLabel: UILabel!
    
    private func handleError(_ error: NSError) {
        statusLabel.isHidden = true
        spinner.stopAnimating()
        
        emailTextField.becomeFirstResponder()
        
        os_log("%{public}@", log: OSLog.Auth, type: .debug, error)
        Crashlytics.sharedInstance().recordError(error)
        
        guard let errorCode = AuthErrorCode(rawValue: error.code) else { return }
        switch errorCode {
        case .invalidEmail:
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                self.emailTextField.shake()
            }
            infoLabel.isHidden = false
            infoLabel.text = "Invalid email"
        default:
            break
        }
    }
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var statusLabel: UILabel!
    
    func prepareViewForSignIn() {
        emailTextField.isHidden = true
        continueButton.isHidden = true
        statusLabel.text = "Signing in..."
        statusLabel.isHidden = false
        spinner.isHidden = false
    }
    
    func signInWithLink(_ link: String) {
        guard let email = UserDefaults.standard.string(forKey: "Email") else { return }
        
        Auth.auth().signIn(withEmail: email, link: link) { [weak self] authResult, error in
            if let error = error as NSError? {
                // TODO: Handle error
                self?.emailTextField.isHidden = false
                self?.continueButton.isHidden = false
                os_log("%{public}@", log: OSLog.Auth, type: .debug, error)
                Crashlytics.sharedInstance().recordError(error)
                self?.spinner.stopAnimating()
                self?.statusLabel.isHidden = true
                return
            }
            
            if authResult?.additionalUserInfo?.isNewUser == true {
                self?.writeUserToDb(withUID: authResult!.user.uid)
                return
            }

            self?.spinner.stopAnimating()
            self?.statusLabel.isHidden = true
            self?.performSegue(withIdentifier: "Show Map", sender: nil)
        }
    }
    
    private func writeUserToDb(withUID uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).setData([
            "username": UserDefaults.standard.string(forKey: "Username")!,
            "capturedLocations": [],
            "capturedLocationsCount": 0
            ]) { [weak self] error in
                if let error = error as NSError? {
                    self?.emailTextField.isHidden = false
                    self?.continueButton.isHidden = false
                    os_log("%{public}@", log: OSLog.Auth, type: .debug, error)
                    Crashlytics.sharedInstance().recordError(error)
                    return
                }
                
                db.collection("users").document(uid).collection("private").document("data").setData([:]) { error in
                    if let error = error as NSError? {
                        self?.emailTextField.isHidden = false
                        self?.continueButton.isHidden = false
                        os_log("%{public}@", log: OSLog.Auth, type: .debug, error)
                        Crashlytics.sharedInstance().recordError(error)
                        return
                    }
                    
                    self?.spinner.stopAnimating()
                    self?.statusLabel.isHidden = true
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
