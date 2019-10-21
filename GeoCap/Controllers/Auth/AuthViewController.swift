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
import FirebaseAuth

class AuthViewController: UIViewController {

    @IBOutlet weak var appIcon: UIImageView!
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Close keyboard when tapping outside of it
        view.addGestureRecognizer(UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:))))
        
        if UserDefaults.standard.object(forKey: "soundsAreEnabled") == nil {
           UserDefaults.standard.set(true, forKey: "soundsAreEnabled")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(AuthViewController.keyboardDidChange), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    private var isStartup = true
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if Auth.auth().currentUser != nil {
            performSegue(withIdentifier: "Show Map", sender: nil)
        } else if isStartup {
            setup()
            isStartup = false
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
     
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        
        // Listens for sign out in the background of the other views, after signing out
        if Auth.auth().currentUser != nil {
            setupAuthListener()
        }
    }
    
    private func setup() {
        continueButton.isHidden = false
    }
    
    private var authListener: AuthStateDidChangeListenerHandle?
    private func setupAuthListener() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            if Auth.auth().currentUser == nil {
                self?.setup()
                self?.dismiss(animated: true)
            }
        }
    }
    
    // MARK: - Keyboard
    
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
    
    @IBOutlet weak var iconHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var continueButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var buttonToTextFieldConstraint: NSLayoutConstraint!
    
    @objc private func keyboardDidChange(notification: Notification) {
        let userInfo = notification.userInfo! as [AnyHashable: Any]
        let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as! NSNumber
        let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as! NSNumber
        var hideEmailTextField = true
        var buttonTitle = ""
        
        // Prevents iPad undocked keyboard
        if endFrame.height != 0, view.frame.height == endFrame.height + endFrame.origin.y {
            hideEmailTextField = false
            buttonTitle = NSLocalizedString("auth-email-button-continue", comment: "Text on button below email text field to confirm input")
            bottomConstraint.constant = view.frame.height - endFrame.origin.y - view.safeAreaInsets.bottom + buttonToTextFieldConstraint.constant
            let topToEmailTextField = endFrame.origin.y - view.safeAreaInsets.bottom - buttonToTextFieldConstraint.constant - continueButtonHeightConstraint.constant - buttonToTextFieldConstraint.constant - emailTextField.frame.height
            iconToTopConstraint.constant = (topToEmailTextField - view.safeAreaInsets.top - iconHeightConstraint.constant) / 2
        } else {
            infoLabel.isHidden = true
            hideEmailTextField = true
            buttonTitle = NSLocalizedString("auth-email-button-continue-with-email", comment: "Text on button below email text field to continue and show the email text field")
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
    
    // MARK: - Auth
    
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
        let title = NSLocalizedString("auth-email-confirmation-title", comment: "Title of email confirmation alert")
        
        let message = NSLocalizedString("auth-email-confirmation-message", comment: "Message of email confirmation alert")
        let formatedMessage = String.localizedStringWithFormat(message, emailTextField.text!)
        
        let alert = UIAlertController(title: title, message: formatedMessage, preferredStyle: .alert)
        
        let noActionTitle = NSLocalizedString("alert-action-title-no", comment: "Title of alert action 'No'")
        let noAction = UIAlertAction(title: noActionTitle, style: .cancel, handler: nil)
        
        let yesActionTitle = NSLocalizedString("alert-action-title-yes", comment: "Title of alert action 'Yes'")
        let yesAction = UIAlertAction(title: yesActionTitle, style: .default) { [weak self] _ in
            self?.checkIfEmailExists()
        }
        alert.addAction(noAction)
        alert.addAction(yesAction)
        present(alert, animated: true)
    }

    private func checkIfEmailExists() {
        statusLabel.isHidden = false
        statusLabel.text = NSLocalizedString("auth-spinner-thinking", comment: "Text below spinner when loading")
        spinner.isHidden = false
        spinner.startAnimating()
        
        Auth.auth().fetchSignInMethods(forEmail: emailTextField.text!) { [weak self] signInMethods, error in
            guard let self = self else { return }
            
            if let error = error as NSError? {
                if let errorMessage = self.handleError(error) {
                    self.infoLabel.text = errorMessage
                    self.infoLabel.isHidden = false
                }
                return
            }
            self.infoLabel.isHidden = true
            
            UserDefaults.standard.set(self.emailTextField.text!, forKey: "Email")
            
            if signInMethods != nil, !signInMethods!.isEmpty {
                self.sendSignInLink()
                return
            }
            
            self.spinner.stopAnimating()
            self.statusLabel.isHidden = true
            self.performSegue(withIdentifier: "Choose Username", sender: nil)
        }
    }
    
    func sendSignInLink(completion: ((String?) -> Void)? = nil) {
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.url = URL(string: "https://geocap-backend.firebaseapp.com")
        actionCodeSettings.handleCodeInApp = true

        let email = emailTextField.text!
        Auth.auth().sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings) { [weak self] error in
            if let error = error as NSError? {
                if let errorMessage = self?.handleError(error) {
                    self?.infoLabel.text = errorMessage
                    self?.infoLabel.isHidden = false
                    completion?(errorMessage)
                }
                return
            }
            
            self?.statusLabel.isHidden = true
            self?.spinner.stopAnimating()
         
            if let completion = completion {
                completion(nil)
            } else {
                self?.performSegue(withIdentifier: "Show Pending Sign In", sender: nil)
            }
        }
    }
    
    @IBOutlet weak var infoLabel: UILabel!
    
    private func handleError(_ error: NSError) -> String? {
        statusLabel.isHidden = true
        spinner.stopAnimating()
        
        setup()
        emailTextField.becomeFirstResponder()
        
        os_log("%{public}@", log: OSLog.Auth, type: .debug, error)
        
        guard let errorCode = AuthErrorCode(rawValue: error.code) else { return nil }
        var errorMessage: String?
        
        switch errorCode {
        case .invalidEmail:
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in
                self.emailTextField.shake()
            }
            errorMessage = NSLocalizedString("auth-email-text-field-info-label-invalid-email", comment: "Text shown when the user inputs an invalid email")
        case .invalidActionCode:
            errorMessage = NSLocalizedString("auth-email-text-field-info-label-invalid-action-code", comment: "Error message when the user tries to use an old email sign in link")
        default:
            Crashlytics.sharedInstance().recordError(error)
            errorMessage = NSLocalizedString("auth-email-text-field-info-label-error", comment: "Text shown when something went wrong with using the inputed email")
        }
        
        return errorMessage
    }
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var statusLabel: UILabel!
    
    func prepareViewForSignIn() {
        emailTextField.resignFirstResponder()
        emailTextField.isHidden = true
        continueButton.isHidden = true
        statusLabel.text = NSLocalizedString("auth-spinner-signing-in", comment: "Text below spinner when signing in")
        statusLabel.isHidden = false
        spinner.isHidden = false
        spinner.startAnimating()
    }
    
    func signInWithLink(_ link: String) {
        guard let email = UserDefaults.standard.string(forKey: "Email") else { return }
        
        Auth.auth().signIn(withEmail: email, link: link) { [weak self] authResult, error in
            if let error = error as NSError? {
                if let errorMessage = self?.handleError(error) {
                    self?.infoLabel.text = errorMessage
                    self?.infoLabel.isHidden = false
                }
                return
            }
                
            Crashlytics.sharedInstance().setUserIdentifier(authResult!.user.uid)
            Crashlytics.sharedInstance().setUserName(UserDefaults.standard.string(forKey: "Username"))
            
            if authResult!.additionalUserInfo?.isNewUser == true {
                self?.writeUserToDb(authResult!.user)
                return
            }

            self?.spinner.stopAnimating()
            self?.statusLabel.isHidden = true
            self?.performSegue(withIdentifier: "Show Map", sender: nil)
        }
    }
    
    private func writeUserToDb(_ user: User) {
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).setData([
            "username": UserDefaults.standard.string(forKey: "Username")!,
            "capturedLocations": [],
            "capturedLocationsCount": 0
            ]) { [weak self] error in
                if let error = error as NSError? {
                    if let errorMessage = self?.handleError(error) {
                        self?.infoLabel.text = errorMessage
                        self?.infoLabel.isHidden = false
                    }
                    return
                }
                
                db.collection("users").document(user.uid).collection("private").document("data").setData([:]) { error in
                    if let error = error as NSError? {
                        if let errorMessage = self?.handleError(error) {
                            self?.infoLabel.text = errorMessage
                            self?.infoLabel.isHidden = false
                        }
                        return
                    }
                    
                    self?.setUsername(forUser: user)
                }
            }
    }
    
    private func setUsername(forUser user: User) {
        let profileChangeRequest = user.createProfileChangeRequest()
        profileChangeRequest.displayName = UserDefaults.standard.string(forKey: "Username")
        profileChangeRequest.commitChanges { [weak self] error in
            if let error = error as NSError? {
                if let errorMessage = self?.handleError(error) {
                    self?.infoLabel.text = errorMessage
                    self?.infoLabel.isHidden = false
                }
                return
            }
            
            self?.spinner.stopAnimating()
            self?.statusLabel.isHidden = true
            self?.performSegue(withIdentifier: "Show Map", sender: nil)
        }
        
    }
    
}

extension AuthViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return emailTextFieldDidEndEditing()
    }

}
